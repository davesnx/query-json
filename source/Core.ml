module Location = struct
  type t = { loc_start : Lexing.position; loc_end : Lexing.position }

  let none = { loc_start = Lexing.dummy_pos; loc_end = Lexing.dummy_pos }
end

let last_position = ref Location.none

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
  | exception Query_error.Parse_error (err, start, end_) ->
      last_position := { loc_start = start; loc_end = end_ };
      let err =
        Query_error.with_location ~input ~start_pos:start.pos_cnum
          ~end_pos:end_.pos_cnum err
      in
      Error (Query_error.format ~colorize err)
  | exception Failure msg ->
      let Location.{ loc_start; loc_end; _ } = !last_position in
      let err =
        Query_error.semantic_error ~message:msg ~input
          ~start_pos:loc_start.pos_cnum
          ~end_pos:loc_end.pos_cnum
      in
      Error (Query_error.format ~colorize err)
  | exception _exn ->
      let Location.{ loc_start; loc_end; _ } = !last_position in
      let err =
        Query_error.parse_error ~input ~start_pos:loc_start.pos_cnum
          ~end_pos:loc_end.pos_cnum
          ~message:
            (Printf.sprintf "problem parsing at %s"
               (position_to_string loc_start loc_end))
      in
      Error (Query_error.format ~colorize err)

let run ?(debug = false) ?(colorize = true) ?(verbose = false) ?(raw = false)
    ?(summarize = false) query json =
  match parse ~debug ~colorize query with
  | Ok runtime ->
      Interpreter.execute ~colorize ~verbose runtime json
      |> Result.map (fun results ->
          results
          |> List.map (Json.to_string_pretty ~colorize ~summarize ~raw)
          |> String.concat "\n")
  | Error err -> Error err
