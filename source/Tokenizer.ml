open Sedlexing.Utf8

let digit = [%sedlex.regexp? '0' .. '9']
let number = [%sedlex.regexp? Plus digit, Opt '.', Opt (Plus digit)]
let space = [%sedlex.regexp? Plus ('\n' | '\t' | ' ')]

let identifier =
  [%sedlex.regexp? (alphabetic | '_'), Star (alphabetic | digit | '_')]

let not_double_quotes = [%sedlex.regexp? Compl '"']

type token =
  | NUMBER of float
  | STRING of string
  | BOOL of bool
  | IDENTIFIER of string
  | FUNCTION of string
  | OPEN_PARENT
  | CLOSE_PARENT
  | OPEN_BRACKET
  | CLOSE_BRACKET
  | OPEN_BRACE
  | CLOSE_BRACE
  | SEMICOLON
  | COLON
  | DOT
  | RECURSE
  | PIPE
  | QUESTION_MARK
  | COMMA
  | NULL
  | ADD
  | SUB
  | DIV
  | MULT
  | AND
  | OR
  | EQUAL
  | NOT_EQUAL
  | GREATER
  | LOWER
  | GREATER_EQUAL
  | LOWER_EQUAL
  | RANGE
  | IF
  | THEN
  | ELSE
  | ELIF
  | END
  | EOF
[@@deriving show]

let tokenize_string buf =
  let buffer = Buffer.create 10 in
  let rec read_string buf =
    [%sedlex
      match buf with
      | {|\"|} ->
          Buffer.add_char buffer '"';
          read_string buf
      | '"' -> Ok (STRING (Buffer.contents buffer))
      | not_double_quotes ->
          Buffer.add_string buffer (lexeme buf);
          read_string buf
      | _ -> Error "unmatched string"]
  in
  read_string buf

let tokenize_apply buf =
  let identifier = lexeme buf in
  match%sedlex buf with
  | '(' -> Ok (FUNCTION identifier)
  | _ -> Ok (IDENTIFIER identifier)

let rec tokenize buf =
  match%sedlex buf with
  | eof -> Ok EOF
  | '<' -> Ok LOWER
  | "<=" -> Ok LOWER_EQUAL
  | '>' -> Ok GREATER
  | ">=" -> Ok GREATER_EQUAL
  | "==" -> Ok EQUAL
  | "!=" -> Ok NOT_EQUAL
  | "+" -> Ok ADD
  | "and" -> Ok AND
  | "or" -> Ok OR
  | "-" -> Ok SUB
  | "*" -> Ok MULT
  | "/" -> Ok DIV
  | "[" -> Ok OPEN_BRACKET
  | "]" -> Ok CLOSE_BRACKET
  | "{" -> Ok OPEN_BRACE
  | "}" -> Ok CLOSE_BRACE
  | "|" -> Ok PIPE
  | ";" -> Ok SEMICOLON
  | ":" -> Ok COLON
  | "," -> Ok COMMA
  | "?" -> Ok QUESTION_MARK
  | "null" -> Ok NULL
  | "true" -> Ok (BOOL true)
  | "false" -> Ok (BOOL false)
  | "(" -> Ok OPEN_PARENT
  | ")" -> Ok CLOSE_PARENT
  | "range" -> Ok RANGE
  | "if" -> Ok IF
  | "then" -> Ok THEN
  | "else" -> Ok ELSE
  | "elif" -> Ok ELIF
  | "end" -> Ok END
  | "." -> Ok DOT
  | ".." -> Ok RECURSE
  | '"' -> tokenize_string buf
  | identifier -> tokenize_apply buf
  | number ->
      let num = lexeme buf in
      Ok (NUMBER (Float.of_string num))
  | space -> tokenize buf
  | any -> Error ("Unexpected character '" ^ lexeme buf ^ "'")
  | _ -> Error "Unexpected character"
