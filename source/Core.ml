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

let execute ~colorize ~verbose ~raw ~summarize ?(buf_size_hint = 4096) runtime
    json =
  match Interpreter.execute ~colorize ~verbose runtime json with
  | Ok results ->
      (* A caller that knows roughly how big the input was can pass that as a
         hint: for a single huge result, starting the buffer near its final
         size avoids the repeated grow-and-copy of doubling up from 4096. *)
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

let run ?(debug = false) ?(colorize = true) ?(verbose = false) ?(raw = false)
    ?(summarize = false) ?(buf_size_hint = 4096) query json =
  match parse ~debug ~colorize query with
  | Ok runtime ->
      execute ~colorize ~verbose ~raw ~summarize ~buf_size_hint runtime json
  | Error err ->
      Error err

let run_input ?(debug = false) ?(colorize = true) ?(verbose = false)
    ?(raw = false) ?(summarize = false) query read =
  match parse ~debug:false ~colorize query with
  | Ok runtime -> (
      match read (Demand.of_expression runtime) with
      | Ok json ->
          if debug then print_endline (Ast.show_expression runtime);
          execute ~colorize ~verbose ~raw ~summarize runtime json
      | Error err ->
          Error err
    )
  | Error err -> (
      match read Json.All with
      | Ok _ ->
          Error err
      | Error json_err ->
          Error json_err
    )

let run_output ?(debug = false) ?(colorize = true) ?(verbose = false)
    ?(raw = false) ?(summarize = false) ~stream query read =
  let out = Buffer.create 65536 in
  let count = ref 0 in
  let ast = ref None in
  let write () =
    Option.iter (fun a -> print_endline (Ast.show_expression a)) !ast;
    ast := None;
    Buffer.output_buffer stdout out;
    Buffer.clear out
  in
  let add results =
    List.iter
      (fun json ->
        render_result_into out ~colorize ~summarize ~raw json;
        Buffer.add_char out '\n';
        incr count
      )
      results
  in
  let finish result =
    match result with
    | Interpreter.Ok results ->
        add results;
        if !count = 0 then Buffer.add_char out '\n';
        write ();
        Ok ()
    | Error err ->
        Buffer.clear out;
        write ();
        Error err
    | Halt code ->
        Buffer.clear out;
        write ();
        exit code
  in
  match parse ~debug:false ~colorize query with
  | Error err -> (
      match read Json.All None with
      | Ok _ ->
          Error err
      | Error json_err ->
          Error json_err
    )
  | Ok runtime -> (
      if debug then ast := Some runtime;
      let whole = Demand.of_expression runtime in
      let run_all json =
        write ();
        finish (Interpreter.execute ~colorize ~verbose runtime json)
      in
      let mode =
        match Demand.stream runtime with
        | Some f ->
            Some (f, false)
        | None when summarize ->
            None
        | None ->
            Option.map (fun f -> (f, true)) (Demand.collect runtime)
      in
      match mode with
      | None -> (
          match read whole None with
          | Ok (Some json) ->
              run_all json
          | Ok None ->
              assert false
          | Error err ->
              Error err
        )
      | Some (f, collect) -> (
          let stopped = ref (Interpreter.Ok []) in
          let pending = ref [] in
          let expanded = ref false in
          let item json =
            if !expanded then (
              Buffer.add_string out ",\n";
              Json.Pretty.item_to_buffer out ~colorize json
            ) else (
              pending := json :: !pending;
              let items = List.rev !pending in
              if not (Json.Pretty.should_compact (`List items)) then (
                expanded := true;
                pending := [];
                Buffer.add_string out "[\n";
                List.iteri
                  (fun i json ->
                    if i > 0 then Buffer.add_string out ",\n";
                    Json.Pretty.item_to_buffer out ~colorize json
                  )
                  items
              )
            )
          in
          let each json =
            match Interpreter.execute ~colorize ~verbose f json with
            | Ok results ->
                if collect then
                  List.iter item results
                else (
                  add results;
                  if stream then (
                    write ();
                    flush stdout
                  )
                );
                true
            | stop ->
                stopped := stop;
                if stream && not collect then raise Json.Stop;
                false
          in
          match read whole (Some (Demand.of_expression f, each)) with
          | Ok (Some json) ->
              run_all json
          | Ok None -> (
              match !stopped with
              | Ok [] when !expanded ->
                  Buffer.add_string out "\n]\n";
                  incr count;
                  finish (Ok [])
              | Ok [] when collect ->
                  finish (Ok [ `List (List.rev !pending) ])
              | stopped ->
                  finish stopped
            )
          | Error err ->
              Error err
        )
    )
