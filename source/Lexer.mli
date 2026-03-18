type token =
  | INT of int
  | INT64 of int64
  | BIG_INT of Z.t
  | DECIMAL of string
  | STRING of string
  | BOOL of bool
  | IDENTIFIER of string
  | FUNCTION of string
  | VARIABLE of string
  | OPEN_PARENT
  | CLOSE_PARENT
  | OPEN_BRACKET
  | CLOSE_BRACKET
  | OPEN_BRACE
  | CLOSE_BRACE
  | SEMICOLON
  | COLON
  | DOT
  | PIPE
  | UPDATE_ASSIGN
  | PLUS_ASSIGN
  | MINUS_ASSIGN
  | MULT_ASSIGN
  | DIV_ASSIGN
  | ALT_ASSIGN
  | ASSIGN
  | ALTERNATIVE
  | QUESTION_MARK
  | COMMA
  | NULL
  | ADD
  | SUB
  | DIV
  | MULT
  | MODULO
  | AND
  | OR
  | EQUAL
  | NOT_EQUAL
  | GREATER
  | LOWER
  | GREATER_EQUAL
  | LOWER_EQUAL
  | RANGE
  | FLATTEN
  | REDUCE
  | FOREACH
  | IF
  | THEN
  | ELSE
  | ELIF
  | END
  | AS
  | TRY
  | CATCH
  | FINALLY
  | FN
  | INTERP of string
  | TEMPLATE of string
  | EOF

val humanize : token -> string

type string_part = Interp of string | End of string

val tokenize_string : Sedlexing.lexbuf -> (string_part, string) result
val tokenize_template : Sedlexing.lexbuf -> (string_part, string) result
val tokenize : Sedlexing.lexbuf -> (token, string) result
