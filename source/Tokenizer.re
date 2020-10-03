open Sedlexing.Utf8;

let dot = [%sedlex.regexp? '.'];
let digit = [%sedlex.regexp? '0' .. '9'];
let number = [%sedlex.regexp? (Plus(digit), Opt('.'), Opt(Plus(digit)))];
let space = [%sedlex.regexp? Plus('\n' | '\t' | ' ')];
let identifier = [%sedlex.regexp? (alphabetic, Star(alphabetic | digit))];

[@deriving show]
type token =
  | NUMBER(float)
  | STRING(string)
  | BOOL(bool)
  | IDENTIFIER(string)
  | FUNCTION(string)
  | OPEN_PARENT
  | CLOSE_PARENT
  | OPEN_BRACKET
  | CLOSE_BRACKET
  | OPEN_BRACE
  | SEMICOLON
  | CLOSE_BRACE
  | DOT
  | DOUBLE_DOT
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
  | eof => Ok(EOF)
  | '<' => Ok(LOWER)
  | "<=" => Ok(LOWER_EQUAL)
  | '>' => Ok(GREATER)
  | ">=" => Ok(GREATER_EQUAL)
  | "==" => Ok(EQUAL)
  | "!=" => Ok(NOT_EQUAL)
  | "+" => Ok(ADD)
  | "and" => Ok(AND)
  | "or" => Ok(OR)
  | "-" => Ok(SUB)
  | "*" => Ok(MULT)
  | "/" => Ok(DIV)
  | "[" => Ok(OPEN_BRACKET)
  | "]" => Ok(CLOSE_BRACKET)
  | "{" => Ok(OPEN_BRACE)
  | "}" => Ok(CLOSE_BRACE)
  | "|" => Ok(PIPE)
  | ";" => Ok(SEMICOLON)
  | "," => Ok(COMMA)
  | "?" => Ok(QUESTION_MARK)
  | "null" => Ok(NULL)
  | "true" => Ok(BOOL(true))
  | "false" => Ok(BOOL(false))
  | "(" => Ok(OPEN_PARENT)
  | ")" => Ok(CLOSE_PARENT)
  | dot => Ok(DOT)
  | ':' => Ok(DOUBLE_DOT)
  | ".." => Ok(RECURSE)
  | '"' => Ok(string(buf))
  | identifier => tokenizeApply(buf)
  | number =>
    let num = lexeme(buf) |> float_of_string;
    Ok(NUMBER(num));
  | space => tokenize(buf)
  | any => Error("Unexpected character '" ++ lexeme(buf) ++ "'")
  | _ => Error("Unexpected character")
  };
};
