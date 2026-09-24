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
      let plan = Execution.prepare runtime in
      match Execution.execute ~colorize ~verbose plan json with
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

let run_iter ?(debug = false) ?(colorize = true) ?(verbose = false)
    ?(raw = false) ?(summarize = false) ~emit query json =
  match parse ~debug ~colorize query with
  | Ok runtime -> (
      let plan = Execution.prepare runtime in
      match
        Execution.fold ~colorize ~verbose ~init:()
          ~f:(fun () value ->
            emit (Json.to_string_pretty ~colorize ~summarize ~raw value)
          )
          plan json
      with
      | Completed () ->
          Ok ()
      | Failed err ->
          Error err
      | Halted code ->
          exit code
    )
  | Error err ->
      Error err

type input = Json.Input.source =
  | String of string
  | File of string
  | Channel of in_channel
  | Value of Json.t

let load_input ~debug ~colorize query input =
  match parse ~debug:false ~colorize query with
  | Ok runtime -> (
      let plan = Execution.prepare runtime in
      match Execution.load plan input with
      | Ok loaded ->
          if debug then print_endline (Ast.show_expression runtime);
          Ok loaded
      | Error err ->
          Error err
    )
  | Error query_error -> (
      match Json.Input.read ~select:None input with
      | Ok _ ->
          Error query_error
      | Error err ->
          Error err
    )

let run_input ?(debug = false) ?(colorize = true) ?(verbose = false)
    ?(raw = false) ?(summarize = false) query input =
  match load_input ~debug ~colorize query input with
  | Ok loaded -> (
      match Execution.execute_loaded ~colorize ~verbose loaded with
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

let run_input_iter ?(debug = false) ?(colorize = true) ?(verbose = false)
    ?(raw = false) ?(summarize = false) ~emit query input =
  let f () value =
    emit (Json.to_string_pretty ~colorize ~summarize ~raw value)
  in
  let result =
    if debug then
      match load_input ~debug ~colorize query input with
      | Ok loaded ->
          Execution.fold_loaded ~colorize ~verbose ~init:() ~f loaded
      | Error error ->
          Execution.Failed error
    else
      match parse ~debug:false ~colorize query with
      | Ok runtime ->
          Execution.fold_source ~colorize ~verbose ~init:() ~f
            (Execution.prepare runtime)
            input
      | Error query_error -> (
          match Json.Input.read ~select:None input with
          | Ok _ ->
              Execution.Failed query_error
          | Error error ->
              Execution.Failed error
        )
  in
  match result with
  | Completed () ->
      Ok ()
  | Failed err ->
      Error err
  | Halted code ->
      exit code
