open Ast;
open Sedlexing.Utf8;

let alpha = [%sedlex.regexp? 'a' .. 'z'];
let dot = [%sedlex.regexp? '.'];
let digit = [%sedlex.regexp? '0' .. '9'];
let number = [%sedlex.regexp? (Plus(digit), Opt('.'), Opt(Plus(digit)))];
let whitespace = [%sedlex.regexp? Plus('\n' | '\t' | ' ')];
let identifierRegex = [%sedlex.regexp? (alpha, Star(alpha | digit))];
let key = [%sedlex.regexp? (dot, identifierRegex)];
let callback = [%sedlex.regexp? ('(', Plus(any), ')')];
let apply = [%sedlex.regexp? (identifierRegex, callback)];
let comparation = [%sedlex.regexp? "<=" | "<" | "=" | ">" | ">="];
let operation = [%sedlex.regexp? "+" | "-" | "*" | "/"];

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
  | GREATER_THAN
  | LOWER_THAN
  | GREATER_OR_EQUAL_THAN
  | LOWER_OR_EQUAL_THAN
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
  | '<' => Ok(LOWER_THAN)
  | "<=" => Ok(LOWER_OR_EQUAL_THAN)
  | '>' => Ok(GREATER_THAN)
  | ">=" => Ok(GREATER_OR_EQUAL_THAN)
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
  | identifierRegex => tokenizeApply(buf)
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

let positionToString = (start, end_) =>
  Printf.sprintf(
    "[line: %d, char: %d-%d]",
    start.Lexing.pos_lnum,
    start.Lexing.pos_cnum - start.Lexing.pos_bol,
    end_.Lexing.pos_cnum - end_.Lexing.pos_bol,
  );

type location = {
  loc_start: Lexing.position,
  loc_end: Lexing.position,
  loc_ghost: bool,
};

type tokenWithLoc = {
  txt: result(token, string),
  loc: location,
};

let expressionParser =
  MenhirLib.Convert.Simplified.traditional2revised(Parser.expr);

let last_position= ref(Location.none);

let provider = (buf, ()) => {
  let (start, stop) = Sedlexing.lexing_positions(buf);
  let token = tokenize(buf);
  last_position := { Location.loc_start: start, loc_end: stop, loc_ghost: false };
  (token, start, stop);
};

let parse = (input: string): expression => {
  let (token, start, stop) = Sedlexing.Utf8.from_string(input)
  let fn = Sedlexing.Utf8.from_string(input) |> provider;

  expressionParser
};

/* failwith(
     "\n\n"
     ++ input
     ++ "\n"
     ++ String.make(loc_start.pos_cnum, ' ')
     ++ String.make(loc_end.pos_cnum - loc_start.pos_cnum, '^')
     ++ "\nProblem parsing at position "
     ++ positionToString(loc_start, loc_end)
     ++ "\n"
     ++ err,
   ) */
