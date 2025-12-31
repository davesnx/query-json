exception Parse_error of string * Lexing.position * Lexing.position

let raise_error msg start_pos end_pos =
  raise (Parse_error (msg, start_pos, end_pos))

