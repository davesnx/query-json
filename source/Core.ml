let position_to_string start end_ =
  Printf.sprintf "[line: %d, char: %d-%d]" start.Lexing.pos_lnum
    (start.Lexing.pos_cnum - start.Lexing.pos_bol)
    (end_.Lexing.pos_cnum - end_.Lexing.pos_bol)

let parse ~debug ~colorize input =
  let buf = Sedlexing.Utf8.from_string input in
  match Parser.program buf with
  | ast ->
      if debug then print_endline (Ast.show_expression ast);
      Ok ast
  | exception Error.Parse_error (err, start, end_) ->
      let err =
        Error.with_location ~input ~start_pos:start.pos_cnum
          ~end_pos:end_.pos_cnum err
      in
      Error (Error.format ~colorize err)
  | exception Failure msg ->
      let start, end_ = Sedlexing.lexing_positions buf in
      let err =
        Error.semantic_error ~message:msg ~input ~start_pos:start.pos_cnum
          ~end_pos:end_.pos_cnum
      in
      Error (Error.format ~colorize err)
  | exception _exn ->
      let start, end_ = Sedlexing.lexing_positions buf in
      let err =
        Error.parse_error ~input ~start_pos:start.pos_cnum
          ~end_pos:end_.pos_cnum
          ~message:
            (Printf.sprintf "problem parsing at %s"
               (position_to_string start end_)
            )
      in
      Error (Error.format ~colorize err)

(* Render straight into one shared buffer instead of turning each result
   into its own string (via Json.to_string_pretty) and then copying all of
   those strings again with String.concat: for many results (or one huge
   one) that was two extra full-size copies for no reason. *)
let render_result_into buf ~colorize ~summarize ~raw (json : Json.t) =
  match (raw, json) with
  | true, `String s ->
      Buffer.add_string buf s
  | _ ->
      Json.Pretty.to_buffer_colored buf ~colorize ~summarize json

let run ?(debug = false) ?(colorize = true) ?(verbose = false) ?(raw = false)
    ?(summarize = false) ?(buf_size_hint = 4096) query json =
  match parse ~debug ~colorize query with
  | Ok runtime -> (
      match Interpreter.execute ~colorize ~verbose runtime json with
      | Ok results ->
          (* A caller that knows roughly how big the input was (e.g. the CLI,
             from the source file's byte size) can pass that as a hint: for
             a single huge result, starting the buffer near its final size
             avoids the repeated grow-and-copy of doubling up from 4096. *)
          let buf = Buffer.create (max 4096 buf_size_hint) in
          let rec write_all first = function
            | [] ->
                ()
            | x :: rest ->
                if not first then Buffer.add_char buf '\n';
                render_result_into buf ~colorize ~summarize ~raw x;
                write_all false rest
          in
          write_all true results;
          Ok (Buffer.contents buf)
      | Error err ->
          Error err
      | Halt code ->
          exit code
    )
  | Error err ->
      Error err
