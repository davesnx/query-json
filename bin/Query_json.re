[@deriving show]
type identifier = string;

[@deriving show]
type literal =
  | Bool(bool) /* true */
  | String(string) /* "TEXT" */
  | Number(float); /* 123 or 123.0 */

[@deriving show]
type expression =
  | Literal(literal)
  | Identity /* . */
  | Key(identifier) /* .foo */
  | Map(expression) /* .[] */ /* map(x) */
  | Filter(conditional) /* .filter(x) */
  | Select(expression) /* .select(x) */
  | Index(int) /* [1] */
  | Addition(expression, expression) /* + */
  | Subtraction(expression, expression) /* - */
  | Division(expression, expression) /* / */
  | Multiply(expression, expression) /* * */
  | Pipe(expression, expression) /* | */
  | Keys /* keys */
  | Flatten /* flatten */
  | Head /* head */
  | Tail /* tail */
  | Length /* length */
  /* Not implemented */
  | List /* [] */
  | Object /* {} */
  | ToEntries /* to_entries */
  | FromEntries /* from_entries */
  | Has(identifier) /* has(x) */
  | Range(int, int) /* range(1, 10) */
  | ToString /* to_string */
  | ToNumber /* to_num */
  | Type /* type */
  | Sort /* sort */
  | SortBy(expression) /* sort_by(x) */
  | GroupBy(expression) /* group_by(x) */
  | Unique /* uniq */
  | Reverse /* reverse */
  | StartsWith /* starts_with */
  | EndsWith /* ends_with */
  | Split /* split */
  | Join /* join */
and conditional =
  | GT(expression, expression) /* Greater > */
  | LT(expression, expression) /* Lower < */
  | GTE(expression, expression) /* Greater equal >= */
  | LTE(expression, expression) /* Lower equal <= */
  | EQ(expression, expression) /* equal == */
  | NOT_EQ(expression, expression); /* not equal != */

[@deriving show]
let stdinMock = {|
  { "store": {
    "books": [
      { "category": "reference",
        "author": "Nigel Rees",
        "title": "Sayings of the Century",
        "price": 8
      },
      { "category": "fiction",
        "author": "Evelyn Waugh",
        "title": "Sword of Honour",
        "price": 12
      },
      { "category": "fiction",
        "author": "Herman Melville",
        "title": "Moby Dick",
        "isbn": "0-553-21311-3",
        "price": 8
      },
      { "category": "fiction",
        "author": "J. R. R. Tolkien",
        "title": "The Lord of the Rings",
        "isbn": "0-395-19395-8",
        "price": 22
      }
    ]
  }}
|};

module Json = {
  type t = Yojson.Basic.t;
  include Yojson.Basic.Util;
};

exception WrongOperation(string);

type noun =
  | StartsWithVocal(string)
  | StartsWithConsonant(string);

let wrongTypeOperation = (op, memberKind, value: Json.t) => {
  raise(
    WrongOperation(
      "\nERROR: Trying to "
      ++ op
      ++ " on "
      ++ (
        switch (memberKind) {
        | StartsWithVocal(m) => "an " ++ m
        | StartsWithConsonant(m) => "a " ++ m
        }
      )
      ++ "."
      ++ "\n\nThe value recived is:\n"
      ++ Json.to_string(value),
    ),
  );
};

let raiseOperationInWrongType = (name, json) => {
  switch (json) {
  | `List(_list) =>
    wrongTypeOperation(name, StartsWithConsonant("list"), json)
  | `Assoc(_a) => wrongTypeOperation(name, StartsWithVocal("object"), json)
  | `Bool(_b) => wrongTypeOperation(name, StartsWithConsonant("bool"), json)
  | `Float(_f) =>
    wrongTypeOperation(name, StartsWithConsonant("float"), json)
  | `Int(_i) => wrongTypeOperation(name, StartsWithVocal("int"), json)
  | `Null => wrongTypeOperation(name, StartsWithConsonant("null"), json)
  | `String(_identifier) =>
    wrongTypeOperation(name, StartsWithConsonant("string"), json)
  };
};
let keys = json => `List(Json.keys(json) |> List.map(i => `String(i)));
let length = json => `Int(json |> Json.to_list |> List.length);
let apply =
    (str: string, fn: (float, float) => float, left: Json.t, right: Json.t) => {
  switch (left, right) {
  | (`Float(l), `Float(r)) => `Float(fn(l, r))
  | (`Int(l), `Float(r)) => `Float(fn(float_of_int(l), r))
  | (`Float(l), `Int(r)) => `Float(fn(l, float_of_int(r)))
  | (`Int(l), `Int(r)) => `Float(fn(float_of_int(l), float_of_int(r)))
  | _ => raiseOperationInWrongType(str, left)
  };
};

let compare =
    (str: string, fn: (float, float) => bool, left: Json.t, right: Json.t) => {
  switch (left, right) {
  | (`Float(l), `Float(r)) => fn(l, r)
  | (`Int(l), `Float(r)) => fn(float_of_int(l), r)
  | (`Float(l), `Int(r)) => fn(l, float_of_int(r))
  | (`Int(l), `Int(r)) => fn(float_of_int(l), float_of_int(r))
  | _ => raiseOperationInWrongType(str, right)
  };
};

let gt = compare(">", (l, r) => l > r);
let gte = compare(">=", (l, r) => l >= r);
let lt = compare("<", (l, r) => l < r);
let lte = compare("<=", (l, r) => l <= r);
let eq = compare("==", (l, r) => l == r);
let notEq = compare("!=", (l, r) => l != r);

let add = apply("+", (l, r) => l +. r);
let sub = apply("-", (l, r) => l -. r);
let mult = apply("-", (l, r) => l *. r);
let div = apply("-", (l, r) => l /. r);

let filter = (fn: Json.t => bool, json: Json.t) => {
  switch (json) {
  | `List(list) => `List(List.filter(fn, list))
  | _ => raiseOperationInWrongType("filter", json)
  };
};

let id: Json.t => Json.t = i => i;

exception WrongIndexAccess(string);

let head = (json: Json.t) => {
  switch (json) {
  | `List(list) =>
    /* TODO: Making sure list have a at least one item
       let item =
          try(List.nth(list, 0)) {
          | _ => raise(WrongIndexAccess("def"))
          }; */

    Json.index(0, `List(list))
  | _ => raiseOperationInWrongType("head", json)
  };
};

let tail = (json: Json.t) => {
  switch (json) {
  | `List(list) =>
    /* TODO: Making sure list have at least one item
       let item =
          try(List.nth(list, 0)) {
          | _ => raise(WrongIndexAccess("def"))
          }; */
    let lastIndex = List.length(list) - 1;
    Json.index(lastIndex, `List(list));
  | _ => raiseOperationInWrongType("head", json)
  };
};

exception CompilationError(string);

let rec compile = (expression: expression, json: Json.t) => {
  switch (expression) {
  | Identity => id(json)
  | Key(key) => Json.member(key, json)
  | Keys => keys(json)
  | Index(idx) => Json.index(idx, json)
  | Head => head(json)
  | Tail => tail(json)
  | Length => length(json)
  | Map(expr) => Json.map(compile(expr), json)
  | Addition(left, right) => add(compile(left, json), compile(right, json))
  | Subtraction(left, right) =>
    sub(compile(left, json), compile(right, json))
  | Multiply(left, right) =>
    mult(compile(left, json), compile(right, json))
  | Division(left, right) => div(compile(left, json), compile(right, json))
  | Literal(literal) =>
    switch (literal) {
    | Bool(b) => `Bool(b)
    | Number(float) => `Float(float)
    | String(string) => `String(string)
    }
  | Filter(conditional) =>
    filter(
      item => {
        switch (conditional) {
        | GT(left, right) => gt(compile(left, item), compile(right, item))
        | GTE(left, right) =>
          gte(compile(left, item), compile(right, item))
        | LT(left, right) => lt(compile(left, item), compile(right, item))
        | LTE(left, right) =>
          lte(compile(left, item), compile(right, item))
        | EQ(left, right) => eq(compile(left, item), compile(right, item))
        | NOT_EQ(left, right) =>
          notEq(compile(left, item), compile(right, item))
        }
      },
      json,
    )
  | Pipe(left, right) => compile(right, compile(left, json))
  | _ =>
    raise(
      CompilationError(show_expression(expression) ++ " is not implemented"),
    )
  };
};

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

let main = () => {
  let json = Yojson.Basic.from_string(stdinMock);
  let inputMock = {|.lola + 3|};
  let program = parse(inputMock);
  let output = compile(program, json);

  Yojson.Basic.pretty_to_string(output);
};

/* Console.log(main()); */
main();
