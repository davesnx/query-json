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
  | RECURSE
  | PIPE
  | UPDATE_ASSIGN
  | PLUS_ASSIGN
  | MINUS_ASSIGN
  | MULT_ASSIGN
  | DIV_ASSIGN
  | ALT_ASSIGN
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
  | DEF
  | INTERP_START
  | INTERP_TEXT of string
  | INTERP_EXPR_START
  | INTERP_END
  | EOF
[@@deriving show]

(* Token buffer for returning multiple tokens from a single lexer call *)
let token_buffer : token Queue.t = Queue.create ()
let interp_paren_depth = ref (-1)
let inside_interp () = !interp_paren_depth >= 0

let read_string_part buf =
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
        (* store what we have and signal interpolation *)
        `Interp (Buffer.contents buffer)
    | '"' ->
        (* end of string *)
        `End (Buffer.contents buffer)
    | Compl ('"' | '\\') ->
        Buffer.add_string buffer (lexeme buf);
        loop buf
    | _ -> `Error "unmatched string"
  in
  loop buf

let tokenize_string buf =
  (* peek ahead to see if this string has any interpolation *)
  match read_string_part buf with
  | `End s -> Ok (STRING s)
  | `Interp s ->
      interp_paren_depth := 0;
      if String.length s > 0 then Queue.add (INTERP_TEXT s) token_buffer;
      Queue.add INTERP_EXPR_START token_buffer;
      Ok INTERP_START
  | `Error e -> Error e

let tokenize_apply buf =
  let identifier = lexeme buf in
  match%sedlex buf with
  | '(' -> Ok (FUNCTION identifier)
  | _ -> Ok (IDENTIFIER identifier)

let tokenize_variable buf =
  match%sedlex buf with
  | identifier ->
      let var_name = lexeme buf in
      Ok (VARIABLE var_name)
  | _ -> Error "Expected variable name after $"

let continue_interp_string buf =
  match read_string_part buf with
  | `End s -> (
      interp_paren_depth := -1;
      if String.length s > 0 then Queue.add (INTERP_TEXT s) token_buffer;
      Queue.add INTERP_END token_buffer;
      (* Return the first queued token *)
      match Queue.take_opt token_buffer with
      | Some tok -> Ok tok
      | None -> Ok INTERP_END)
  | `Interp s -> (
      interp_paren_depth := 0;
      if String.length s > 0 then Queue.add (INTERP_TEXT s) token_buffer;
      Queue.add INTERP_EXPR_START token_buffer;
      match Queue.take_opt token_buffer with
      | Some tok -> Ok tok
      | None -> Ok INTERP_EXPR_START)
  | `Error e -> Error e

let rec tokenize buf =
  (* First, check if we have buffered tokens *)
  match Queue.take_opt token_buffer with
  | Some tok -> Ok tok
  | None -> tokenize_impl buf

and tokenize_impl buf =
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
  | "%" -> Ok MODULO
  | "[" -> Ok OPEN_BRACKET
  | "]" -> Ok CLOSE_BRACKET
  | "{" -> Ok OPEN_BRACE
  | "}" -> Ok CLOSE_BRACE
  | "|=" -> Ok UPDATE_ASSIGN
  | "+=" -> Ok PLUS_ASSIGN
  | "-=" -> Ok MINUS_ASSIGN
  | "*=" -> Ok MULT_ASSIGN
  | "/=" -> Ok DIV_ASSIGN
  | "//=" -> Ok ALT_ASSIGN
  | "//" -> Ok ALTERNATIVE
  | "|" -> Ok PIPE
  | ";" -> Ok SEMICOLON
  | ":" -> Ok COLON
  | "," -> Ok COMMA
  | "?" -> Ok QUESTION_MARK
  | "null" -> Ok NULL
  | "true" -> Ok (BOOL true)
  | "false" -> Ok (BOOL false)
  | "(" ->
      if inside_interp () then incr interp_paren_depth;
      Ok OPEN_PARENT
  | ")" ->
      if inside_interp () then begin
        let end_of_interpolation = !interp_paren_depth = 0 in
        if end_of_interpolation then continue_interp_string buf
        else begin
          decr interp_paren_depth;
          Ok CLOSE_PARENT
        end
      end
      else Ok CLOSE_PARENT
  | "range" -> Ok RANGE
  | "flatten" -> Ok FLATTEN
  | "reduce" -> Ok REDUCE
  | "foreach" -> Ok FOREACH
  | "if" -> Ok IF
  | "then" -> Ok THEN
  | "else" -> Ok ELSE
  | "elif" -> Ok ELIF
  | "end" -> Ok END
  | "as" -> Ok AS
  | "def" -> Ok DEF
  | "try" -> (
      (* distinguish try(expr) from try expr.
         Otherwise, the grammar has reduce/reduce conflicts because
         TRY OPEN_PARENT could start either form. *)
      match%sedlex
        buf
      with
      | '(' -> Ok (FUNCTION "try")
      | _ -> Ok TRY)
  | "catch" -> Ok CATCH
  | "." -> Ok DOT
  | ".." -> Ok RECURSE
  | '$' -> tokenize_variable buf
  | '"' -> tokenize_string buf
  | identifier -> tokenize_apply buf
  | number ->
      let num = lexeme buf in
      Ok (NUMBER (Float.of_string num))
  | space -> tokenize buf
  | any -> Error ("Unexpected character '" ^ lexeme buf ^ "'")
  | _ -> Error "Unexpected character"
