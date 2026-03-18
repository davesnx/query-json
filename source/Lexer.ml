open Sedlexing.Utf8

let digit = [%sedlex.regexp? '0' .. '9']
let integer = [%sedlex.regexp? Plus digit]
let exponent = [%sedlex.regexp? ('e' | 'E'), Opt ('+' | '-'), Plus digit]

let decimal_number =
  [%sedlex.regexp?
    Plus digit, '.', Plus digit, Opt exponent | Plus digit, exponent]
let space = [%sedlex.regexp? Plus ('\n' | '\t' | ' ')]

let identifier =
  [%sedlex.regexp? (alphabetic | '_'), Star (alphabetic | digit | '_')]

let comment = [%sedlex.regexp? '#', Star (Compl '\n')]

type token =
  | INT of int (* small integers *)
  | INT64 of int64 (* large integers *)
  | BIG_INT of Z.t [@printer fun fmt z -> Z.pp_print fmt z] (* huge integers *)
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
[@@deriving show]

let humanize = function
  | INT n ->
      Printf.sprintf "%d" n
  | INT64 n ->
      Printf.sprintf "%Ld" n
  | BIG_INT n ->
      Z.to_string n
  | DECIMAL n ->
      n
  | STRING s ->
      Printf.sprintf "\"%s\"" s
  | BOOL b ->
      if b then
        "true"
      else
        "false"
  | IDENTIFIER s ->
      Printf.sprintf "'%s'" s
  | FUNCTION s ->
      Printf.sprintf "'%s('" s
  | VARIABLE s ->
      Printf.sprintf "$%s" s
  | OPEN_PARENT ->
      "'('"
  | CLOSE_PARENT ->
      "')'"
  | OPEN_BRACKET ->
      "'['"
  | CLOSE_BRACKET ->
      "']'"
  | OPEN_BRACE ->
      "'{'"
  | CLOSE_BRACE ->
      "'}'"
  | SEMICOLON ->
      "';'"
  | COLON ->
      "':'"
  | DOT ->
      "'.'"
  | PIPE ->
      "'|'"
  | UPDATE_ASSIGN ->
      "'|='"
  | PLUS_ASSIGN ->
      "'+='"
  | MINUS_ASSIGN ->
      "'-='"
  | MULT_ASSIGN ->
      "'*='"
  | DIV_ASSIGN ->
      "'/='"
  | ALT_ASSIGN ->
      "'??='"
  | ASSIGN ->
      "'='"
  | ALTERNATIVE ->
      "'??'"
  | QUESTION_MARK ->
      "'?'"
  | COMMA ->
      "','"
  | NULL ->
      "null"
  | ADD ->
      "'+'"
  | SUB ->
      "'-'"
  | DIV ->
      "'/'"
  | MULT ->
      "'*'"
  | MODULO ->
      "'%'"
  | AND ->
      "'and'"
  | OR ->
      "'or'"
  | EQUAL ->
      "'=='"
  | NOT_EQUAL ->
      "'!='"
  | GREATER ->
      "'>'"
  | LOWER ->
      "'<'"
  | GREATER_EQUAL ->
      "'>='"
  | LOWER_EQUAL ->
      "'<='"
  | RANGE ->
      "'range'"
  | FLATTEN ->
      "'flatten'"
  | REDUCE ->
      "'reduce'"
  | FOREACH ->
      "'foreach'"
  | IF ->
      "'if'"
  | THEN ->
      "'then'"
  | ELSE ->
      "'else'"
  | ELIF ->
      "'elif'"
  | END ->
      "'end'"
  | AS ->
      "'as'"
  | TRY ->
      "'try'"
  | CATCH ->
      "'catch'"
  | FINALLY ->
      "'finally'"
  | FN ->
      "'fn'"
  | INTERP _ ->
      "string interpolation"
  | TEMPLATE _ ->
      "template literal"
  | EOF ->
      "end of input"

type string_part = Interp of string | End of string

let tokenize_string buf =
  let buffer = Buffer.create 10 in
  let rec loop buf =
    match%sedlex buf with
    | {|\"|} ->
        Buffer.add_char buffer '"';
        loop buf
    | {|\\|} ->
        Buffer.add_char buffer '\\';
        loop buf
    | {|\n|} ->
        Buffer.add_char buffer '\n';
        loop buf
    | {|\r|} ->
        Buffer.add_char buffer '\r';
        loop buf
    | {|\t|} ->
        Buffer.add_char buffer '\t';
        loop buf
    | {|\(|} ->
        Ok (Interp (Buffer.contents buffer))
    | '"' ->
        Ok (End (Buffer.contents buffer))
    | Compl ('"' | '\\') ->
        Buffer.add_string buffer (lexeme buf);
        loop buf
    | _ ->
        Error "unmatched string"
  in
  loop buf

let tokenize_template buf =
  let buffer = Buffer.create 10 in
  let rec loop buf =
    match%sedlex buf with
    | {|\\|} ->
        Buffer.add_char buffer '\\';
        loop buf
    | {|\`|} ->
        Buffer.add_char buffer '`';
        loop buf
    | {|\$|} ->
        Buffer.add_char buffer '$';
        loop buf
    | {|\n|} ->
        Buffer.add_char buffer '\n';
        loop buf
    | {|\r|} ->
        Buffer.add_char buffer '\r';
        loop buf
    | {|\t|} ->
        Buffer.add_char buffer '\t';
        loop buf
    | "${" ->
        Ok (Interp (Buffer.contents buffer))
    | '`' ->
        Ok (End (Buffer.contents buffer))
    | Compl ('`' | '\\' | '$') ->
        Buffer.add_string buffer (lexeme buf);
        loop buf
    | '$' ->
        Buffer.add_char buffer '$';
        loop buf
    | _ ->
        Error "unmatched template literal"
  in
  loop buf

let rec tokenize buf =
  match%sedlex buf with
  | eof ->
      Ok EOF
  | '<' ->
      Ok LOWER
  | "<=" ->
      Ok LOWER_EQUAL
  | '>' ->
      Ok GREATER
  | ">=" ->
      Ok GREATER_EQUAL
  | "==" ->
      Ok EQUAL
  | "!=" ->
      Ok NOT_EQUAL
  | "=" ->
      Ok ASSIGN
  | "+" ->
      Ok ADD
  | "and" ->
      Ok AND
  | "or" ->
      Ok OR
  | "-" ->
      Ok SUB
  | "*" ->
      Ok MULT
  | "/" ->
      Ok DIV
  | "%" ->
      Ok MODULO
  | "[" ->
      Ok OPEN_BRACKET
  | "]" ->
      Ok CLOSE_BRACKET
  | "{" ->
      Ok OPEN_BRACE
  | "}" ->
      Ok CLOSE_BRACE
  | "|=" ->
      Ok UPDATE_ASSIGN
  | "+=" ->
      Ok PLUS_ASSIGN
  | "-=" ->
      Ok MINUS_ASSIGN
  | "*=" ->
      Ok MULT_ASSIGN
  | "/=" ->
      Ok DIV_ASSIGN
  | "??=" ->
      Ok ALT_ASSIGN
  | "??" ->
      Ok ALTERNATIVE
  | "|" ->
      Ok PIPE
  | ";" ->
      Ok SEMICOLON
  | ":" ->
      Ok COLON
  | "," ->
      Ok COMMA
  | "?" ->
      Ok QUESTION_MARK
  | "null" ->
      Ok NULL
  | "true" ->
      Ok (BOOL true)
  | "false" ->
      Ok (BOOL false)
  | "(" ->
      Ok OPEN_PARENT
  | ")" ->
      Ok CLOSE_PARENT
  | "range" ->
      Ok RANGE
  | "flatten" ->
      Ok FLATTEN
  | "reduce" ->
      Ok REDUCE
  | "foreach" ->
      Ok FOREACH
  | "if" ->
      Ok IF
  | "then" ->
      Ok THEN
  | "else" ->
      Ok ELSE
  | "elif" ->
      Ok ELIF
  | "end" ->
      Ok END
  | "as" ->
      Ok AS
  | "fn" ->
      Ok FN
  | "def" ->
      Error "'def' is deprecated, use 'fn' instead"
  | "try" ->
      let token = match%sedlex buf with '(' -> FUNCTION "try" | _ -> TRY in
      Ok token
  | "catch" ->
      Ok CATCH
  | "finally" ->
      Ok FINALLY
  | "." ->
      Ok DOT
  | ".." ->
      Error "'..' is deprecated, use 'descend' instead"
  | '$' -> (
      match%sedlex buf with
      | identifier ->
          let var_name = lexeme buf in
          Ok (VARIABLE var_name)
      | _ ->
          Error "Expected variable name after $"
    )
  | '"' -> (
      match tokenize_string buf with
      | Ok (End s) ->
          Ok (STRING s)
      | Ok (Interp s) ->
          Ok (INTERP s)
      | Error e ->
          Error e
    )
  | '`' -> (
      match tokenize_template buf with
      | Ok (End s) ->
          Ok (STRING s)
      | Ok (Interp s) ->
          Ok (TEMPLATE s)
      | Error e ->
          Error e
    )
  | identifier -> (
      let ident = lexeme buf in
      match%sedlex buf with
      | '(' ->
          Ok (FUNCTION ident)
      | _ ->
          Ok (IDENTIFIER ident)
    )
  | decimal_number ->
      Ok (DECIMAL (lexeme buf))
  | integer -> (
      let num = lexeme buf in
      (* Parse into smallest fitting type: int -> int64 -> Big_int *)
      match int_of_string_opt num with
      | Some i ->
          Ok (INT i)
      | None -> (
          match Int64.of_string_opt num with
          | Some i ->
              Ok (INT64 i)
          | None ->
              Ok (BIG_INT (Z.of_string num))
        )
    )
  | space ->
      tokenize buf
  | comment ->
      tokenize buf (* Skip comments *)
  | any ->
      Error ("Unexpected character '" ^ lexeme buf ^ "'")
  | _ ->
      Error "Unexpected character"
