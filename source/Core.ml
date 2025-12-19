module Location = struct
  type t = { loc_start : Lexing.position; loc_end : Lexing.position }

  let none = { loc_start = Lexing.dummy_pos; loc_end = Lexing.dummy_pos }
end

let last_position = ref Location.none

exception Lexer_error of string

let provider ~debug buf =
  let start, stop = Sedlexing.lexing_positions buf in
  let token =
    match Lexer.tokenize buf with Ok t -> t | Error e -> raise (Lexer_error e)
  in
  last_position := { loc_start = start; loc_end = stop };
  if debug then print_endline (Lexer.show_token token);
  (token, start, stop)

let menhir = MenhirLib.Convert.Simplified.traditional2revised Parser.program

let position_to_string start end_ =
  Printf.sprintf "[line: %d, char: %d-%d]" start.Lexing.pos_lnum
    (start.Lexing.pos_cnum - start.Lexing.pos_bol)
    (end_.Lexing.pos_cnum - end_.Lexing.pos_bol)

let pretty_print_error ~colorize ~input ~(start : Lexing.position)
    ~(end_ : Lexing.position) =
  let module Color = Ansi.To_string (struct
    let colorize = colorize
  end) in
  let pointer_range = String.make (end_.pos_cnum - start.pos_cnum) '^' in
  Color.red (Color.bold "Parse error: ")
  ^ "Problem parsing at position "
  ^ position_to_string start end_
  ^ Formatting.enter 2 ^ "Input:" ^ Formatting.indent 1
  ^ Color.green (Color.bold input)
  ^ Formatting.enter 1 ^ Formatting.indent 4
  ^ String.make start.pos_cnum ' '
  ^ Color.gray pointer_range

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
      Error (pretty_print_error ~colorize ~input ~start:loc_start ~end_:loc_end)
  | exception _exn ->
      let Location.{ loc_start; loc_end; _ } = !last_position in
      Error (pretty_print_error ~colorize ~input ~start:loc_start ~end_:loc_end)

let run ?(debug = false) ?(colorize = true) ?(verbose = false) ?(raw = false)
    ?(summarize = false) query json =
  match parse ~debug ~colorize query with
  | Ok runtime ->
      Interpreter.execute ~colorize ~verbose runtime json
      |> Result.map (fun results ->
          results
          |> List.map (Json.to_string ~colorize ~summarize ~raw)
          |> String.concat "\n")
  | Error err -> Error err
