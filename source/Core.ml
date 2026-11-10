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

let execute ~colorize ~verbose ~raw ~summarize runtime json =
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

let run ?(debug = false) ?(colorize = true) ?(verbose = false) ?(raw = false)
    ?(summarize = false) query json =
  match parse ~debug ~colorize query with
  | Ok runtime ->
      execute ~colorize ~verbose ~raw ~summarize runtime json
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
        Json.add_pretty out ~colorize ~summarize ~raw json;
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
      match Demand.stream runtime with
      | None -> (
          match read whole None with
          | Ok (Some json) ->
              run_all json
          | Ok None ->
              assert false
          | Error err ->
              Error err
        )
      | Some f -> (
          let stopped = ref (Interpreter.Ok []) in
          let each json =
            match Interpreter.execute ~colorize ~verbose f json with
            | Ok results ->
                add results;
                if stream then (
                  write ();
                  flush stdout
                );
                true
            | stop ->
                stopped := stop;
                if stream then raise Json.Stop;
                false
          in
          match read whole (Some (Demand.of_expression f, each)) with
          | Ok (Some json) ->
              run_all json
          | Ok None ->
              finish !stopped
          | Error err ->
              Error err
        )
    )
