open Ast;

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
  | GREATER_THAN
  | LOWER_THAN
  | GREATER_OR_EQUAL_THAN
  | LOWER_OR_EQUAL_THAN
  | WHITESPACE
  | EOF
  | BAD_STRING(string);

open Sedlexing.Utf8;

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
  | number =>
    let num = lexeme(buf) |> float_of_string;
    Ok(NUMBER(num));
  | dot => Ok(DOT)
  | '<' => Ok(LOWER_THAN)
  | "<=" => Ok(LOWER_OR_EQUAL_THAN)
  | '>' => Ok(GREATER_THAN)
  | ">=" => Ok(GREATER_OR_EQUAL_THAN)
  | "+" => Ok(ADD)
  | "-" => Ok(SUB)
  | "*" => Ok(MULT)
  | "/" => Ok(DIV)
  | "[" => Ok(OPEN_LIST)
  | identifierRegex => tokenizeApply(buf)
  | ")" => Ok(CLOSE_PARENT)
  | key =>
    let tok = lexeme(buf);
    let key = String.sub(tok, 1, String.length(tok) - 1);
    Ok(KEY(key));
  | '"' => Ok(string(buf))
  | '|' => Ok(PIPE)
  | "true" => Ok(BOOL(true))
  | "false" => Ok(BOOL(false))
  | whitespace => tokenize(buf)
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
  txt: result(token, identifier),
  loc: location,
};

let parse = (input: string): expression => {
  let buf = Sedlexing.Utf8.from_string(input);
  let rec read = acc => {
    let (loc_start, _) = Sedlexing.lexing_positions(buf);
    let value = tokenize(buf);
    let (_, loc_end) = Sedlexing.lexing_positions(buf);

    let token_with_loc = {
      txt: value,
      loc: {
        loc_start,
        loc_end,
        loc_ghost: false,
      },
    };

    let acc = [token_with_loc, ...acc];

    switch (value) {
    | Ok(EOF) => Ok(acc)
    | Error(err) =>
      failwith(
        "\n\n"
        ++ input
        ++ "\n"
        ++ String.make(loc_start.pos_cnum, ' ')
        ++ String.make(loc_end.pos_cnum - loc_start.pos_cnum, '^')
        ++ "\nProblem parsing at position "
        ++ positionToString(loc_start, loc_end)
        ++ "\n"
        ++ err,
      )
    | _ => read(acc)
    };
  };

  let tokens =
    read([])
    |> Result.map(tokenList =>
         List.map(
           resultToken => Result.map(show_token, resultToken.txt),
           tokenList,
         )
         |> List.rev
       );

  Console.log(tokens);

  Key("store");
};
