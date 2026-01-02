exception Parse_error of string * Lexing.position * Lexing.position
exception Rich_parse_error of Query_error.t * Lexing.position * Lexing.position

let raise_error msg start_pos end_pos =
  raise (Parse_error (msg, start_pos, end_pos))

let raise_rich_error err start_pos end_pos =
  raise (Rich_parse_error (err, start_pos, end_pos))
