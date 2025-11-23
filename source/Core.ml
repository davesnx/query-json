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
  let module Chalk = Chalk.Make (struct
    let disable = not colorize
  end) in
  let pointer_range = String.make (end_.pos_cnum - start.pos_cnum) '^' in
  Chalk.red (Chalk.bold "Parse error: ")
  ^ "Problem parsing at position "
  ^ position_to_string start end_
  ^ Formatting.enter 2 ^ "Input:" ^ Formatting.indent 1
  ^ Chalk.green (Chalk.bold input)
  ^ Formatting.enter 1 ^ Formatting.indent 4
  ^ String.make start.pos_cnum ' '
  ^ Chalk.gray pointer_range

let parse ?(debug = false) ?(colorize = true) ?(verbose : _) input :
    (Ast.expression, string) result =
  let _ = ignore verbose in
  (* verbose will be used for parser warnings in the future *)
  let buf = Sedlexing.Utf8.from_string input in
  let next_token () = provider ~debug buf in
  match menhir next_token with
  | ast ->
      if debug then print_endline (Ast.show_expression ast);
      Ok ast
  | exception Lexer_error msg ->
      (* TODO: Do we want to show the lexing error differently than the parser error? *)
      if debug then (
        print_endline "Lexer error";
        print_endline msg);
      let Location.{ loc_start; loc_end; _ } = !last_position in
      Error (pretty_print_error ~colorize ~input ~start:loc_start ~end_:loc_end)
  | exception _exn ->
      let Location.{ loc_start; loc_end; _ } = !last_position in
      Error (pretty_print_error ~colorize ~input ~start:loc_start ~end_:loc_end)

let run query json =
  match parse ~debug:false ~colorize:false ~verbose:false query with
  | Ok runtime ->
      let ( let* ) = Result.bind in
      let* results =
        Interpreter.execute ~colorize:false ~verbose:false runtime json
      in
      Ok
        (results
        |> List.map (Json.to_string ~colorize:false ~summarize:false ~raw:false)
        |> String.concat "\n")
  | Error err -> Error err
