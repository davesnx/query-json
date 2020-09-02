open Sedlexing.Utf8;

let alpha = [%sedlex.regexp? 'a' .. 'z'];
let dot = [%sedlex.regexp? '.'];
let digit = [%sedlex.regexp? '0' .. '9'];
let number = [%sedlex.regexp? (Plus(digit), Opt('.'), Opt(Plus(digit)))];
let whitespace = [%sedlex.regexp? Plus('\n' | '\t' | ' ')];
let identifier = [%sedlex.regexp? (alpha, Star(alpha | digit))];
let key = [%sedlex.regexp? (dot, identifier)];

[@deriving show]
type token =
  | NUMBER(float)
  | STRING(string)
  | BOOL(bool)
  | IDENTIFIER(string)
  | KEY(string)
  | FUNCTION(string)
  | CLOSE_PARENT
  | OPEN_LIST
  | CLOSE_LIST
  | OPEN_OBJ
  | CLOSE_OBJ
  | DOT
  | PIPE
  | ADD
  | SUB
  | DIV
  | MULT
  | EQUAL
  | NOT_EQUAL
  | GREATER
  | LOWER
  | GREATER_EQUAL
  | LOWER_EQUAL
  | WHITESPACE
  | EOF;

let string = buf => {
  let buffer = Buffer.create(10);
  let rec read_string = buf =>
    switch%sedlex (buf) {
    | {|\"|} =>
      Buffer.add_char(buffer, '"');
      read_string(buf);
    | '"' => STRING(Buffer.contents(buffer))
    | Star(Compl('"')) =>
      Buffer.add_string(buffer, lexeme(buf));
      read_string(buf);
    | _ => assert(false)
    };

  read_string(buf);
};

let tokenizeApply = buf => {
  let identifier = lexeme(buf);
  switch%sedlex (buf) {
  | '(' => Ok(FUNCTION(identifier))
  | _ => Ok(IDENTIFIER(identifier))
  };
};

let rec tokenize = buf => {
  switch%sedlex (buf) {
  | '<' => Ok(LOWER)
  | "<=" => Ok(LOWER_EQUAL)
  | '>' => Ok(GREATER)
  | ">=" => Ok(GREATER_EQUAL)
  | "==" => Ok(EQUAL)
  | "!=" => Ok(NOT_EQUAL)
  | "+" => Ok(ADD)
  | "-" => Ok(SUB)
  | "*" => Ok(MULT)
  | "/" => Ok(DIV)
  | "[" => Ok(OPEN_LIST)
  | '"' => Ok(string(buf))
  | '|' => Ok(PIPE)
  | "true" => Ok(BOOL(true))
  | "false" => Ok(BOOL(false))
  | identifier => tokenizeApply(buf)
  | ")" => Ok(CLOSE_PARENT)
  | dot => Ok(DOT)
  | key =>
    let tok = lexeme(buf);
    let key = String.sub(tok, 1, String.length(tok) - 1);
    Ok(KEY(key));
  | number =>
    let num = lexeme(buf) |> float_of_string;
    Ok(NUMBER(num));
  | whitespace => tokenize(buf)
  | eof => Ok(EOF)
  | _ =>
    let tok = lexeme(buf);
    Error(Printf.sprintf("Unexpected character %S", tok));
  };
};
