module Location = struct
  type t = { loc_start : Lexing.position; loc_end : Lexing.position }

  let none = { loc_start = Lexing.dummy_pos; loc_end = Lexing.dummy_pos }
end

let last_position = ref Location.none

exception Lexer_error of string

let provider ~debug buf =
  let start, stop = Sedlexing.lexing_positions buf in
  last_position := { loc_start = start; loc_end = stop };
  let token =
    match Lexer.tokenize buf with Ok t -> t | Error e -> raise (Lexer_error e)
  in
  if debug then print_endline (Lexer.show_token token);
  (token, start, stop)

let menhir = MenhirLib.Convert.Simplified.traditional2revised Parser.program

let position_to_string start end_ =
  Printf.sprintf "[line: %d, char: %d-%d]" start.Lexing.pos_lnum
    (start.Lexing.pos_cnum - start.Lexing.pos_bol)
    (end_.Lexing.pos_cnum - end_.Lexing.pos_bol)

let pretty_print_error ~colorize ~input ~(start : Lexing.position)
    ~(end_ : Lexing.position) =
  let err =
    Query_error.parse_error
      ~message:("problem parsing at " ^ position_to_string start end_)
      ~input ~start_pos:start.pos_cnum ~end_pos:end_.pos_cnum
  in
  Query_error.format ~colorize err

let parse ~debug ~colorize input =
  let buf = Sedlexing.Utf8.from_string input in
  let next_token () = provider ~debug buf in
  match menhir next_token with
  | ast ->
      if debug then print_endline (Ast.show_expression ast);
      Ok ast
  | exception Lexer_error msg ->
      if debug then (
        print_endline "Lexer error";
        print_endline msg);
      let Location.{ loc_start; loc_end; _ } = !last_position in
      let err =
        Query_error.lexer_error ~message:msg ~input
          ~start_pos:loc_start.pos_cnum ~end_pos:loc_end.pos_cnum
      in
      Error (Query_error.format ~colorize err)
  | exception Failure msg ->
      let err =
        Query_error.semantic_error ~message:msg ~input
          ~start_pos:!last_position.loc_start.pos_cnum
          ~end_pos:!last_position.loc_end.pos_cnum
      in
      Error (Query_error.format ~colorize err)
  | exception _exn ->
      let Location.{ loc_start; loc_end; _ } = !last_position in
      Error (pretty_print_error ~colorize ~input ~start:loc_start ~end_:loc_end)

let run ?(debug = false) ?(colorize = true) ?(raw = false) ?(summarize = false)
    query json =
  match parse ~debug ~colorize query with
  | Ok runtime ->
      Interpreter.execute ~colorize runtime json
      |> Result.map (fun results ->
          results
          |> List.map (Json.to_string_pretty ~colorize ~summarize ~raw)
          |> String.concat "\n")
  | Error err -> Error err
