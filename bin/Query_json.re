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
  | Tail /* head */
  | Length /* length */
  | List /* [] */
  | Object /* {} */
/* Missing on the AST */
/* ToEntries, FromEntries */
/* Has(identifier) */
/* Range(int, int) */
/* ToString, ToNumber */
/* Type */
/* Sort */
/* GroupBy(expression) */
/* Unique */
/* Reverse */
/* StartsWith, EndsWith */
/* Split */
/* Join */

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
  include Yojson.Basic.Util;
};

open Json;

exception WrongOperation(string);

type noun =
  | StartsWithVocal(string)
  | StartsWithConsonant(string);

let wrongTypeOperation = (op, memberKind, value: Yojson.Basic.t) => {
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
      ++ Yojson.Basic.to_string(value),
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
    (
      str: string,
      fn: (float, float) => float,
      left: Yojson.Basic.t,
      right: Yojson.Basic.t,
    ) => {
  switch (left, right) {
  | (`Float(l), `Float(r)) => `Float(fn(l, r))
  | (`Int(l), `Float(r)) => `Float(fn(float_of_int(l), r))
  | (`Float(l), `Int(r)) => `Float(fn(l, float_of_int(r)))
  | (`Int(l), `Int(r)) => `Float(fn(float_of_int(l), float_of_int(r)))
  | _ => raiseOperationInWrongType(str, left)
  };
};

let compare =
    (
      str: string,
      fn: (float, float) => bool,
      left: Yojson.Basic.t,
      right: Yojson.Basic.t,
    ) => {
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

let filter = (fn: Yojson.Basic.t => bool, json: Yojson.Basic.t) => {
  switch (json) {
  | `List(list) => `List(List.filter(fn, list))
  | _ => raiseOperationInWrongType("filter", json)
  };
};

let id: Yojson.Basic.t => Yojson.Basic.t = i => i;

exception WrongIndexAccess(string);

let head = (json: Yojson.Basic.t) => {
  switch (json) {
  | `List(list) =>
    /* TODO: Making sure list have a at least one item
       let item =
          try(List.nth(list, 0)) {
          | _ => raise(WrongIndexAccess("def"))
          }; */

    index(0, `List(list))
  | _ => raiseOperationInWrongType("head", json)
  };
};

let tail = (json: Yojson.Basic.t) => {
  switch (json) {
  | `List(list) =>
    /* TODO: Making sure list have at least one item
       let item =
          try(List.nth(list, 0)) {
          | _ => raise(WrongIndexAccess("def"))
          }; */
    let lastIndex = List.length(list) - 1;
    index(lastIndex, `List(list));
  | _ => raiseOperationInWrongType("head", json)
  };
};

let program =
  Pipe(
    Pipe(
      Pipe(Key("store"), Key("books")),
      Filter(GT(Key("price"), Literal(Number(0.)))),
    ),
    Map(Addition(Key("price"), Literal(Number(10.)))),
  );

exception CompilationError(string);

let rec compile = (expression: expression, json: Yojson.Basic.t) => {
  switch (expression) {
  | Identity => id(json)
  | Key(key) => member(key, json)
  | Keys => keys(json)
  | Index(idx) => index(idx, json)
  | Head => head(json)
  | Tail => tail(json)
  | Length => length(json)
  | Map(expr) => map(compile(expr), json)
  | Flatten => raise(CompilationError("Flatten is not implemenet"))
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
  | Select(_expr) =>
    raise(
      CompilationError("select() is not implemented, maybe use filter()?"),
    )
  | List =>
    raise(
      CompilationError("Creation of arrays with '[]' is not implemented"),
    )
  | Object =>
    raise(
      CompilationError("Creation of objeects with '{}' is not implemented"),
    )
  };
};

let main = () => {
  let json = Yojson.Basic.from_string(stdinMock);
  let output = compile(program, json);

  Yojson.Basic.pretty_to_string(output);
};

Console.log(main());
