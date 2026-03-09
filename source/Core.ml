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

let run ?(debug = false) ?(colorize = true) ?(verbose = false) ?(raw = false)
    ?(summarize = false) query json =
  match parse ~debug ~colorize query with
  | Ok runtime -> (
      match Interpreter.execute ~colorize ~verbose runtime json with
      | Ok results ->
          Ok
            (results
            |> List.map (Json.to_string_pretty ~colorize ~summarize ~raw)
            |> String.concat "\n"
            )
      | Error err ->
          Error err
      | Halt code ->
          exit code
    )
  | Error err ->
      Error err
