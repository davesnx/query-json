[@deriving show]
type identifier = string;

[@deriving show]
type literal =
  | Bool(bool) /* true */
  | String(string) /* "TEXT" */
  | Int(float) /* 123 */
  | Float(float); /* 12.3 */

[@deriving show]
type expression =
  | Main(expression)
  | Literal(literal)
  | Identity /* . */
  | Key(identifier) /* .foo */
  | Map(expression) /* .[] */ /* map(x) */
  | Filter(conditional) /* .filter(x) */
  | Select(expression) /* .select(x) - Not implemented */
  | Pipe(expression, expression) /* | */
  | Addition(expression, expression) /* + */
  | Subtraction(expression, expression) /* - */
  | Division(expression, expression) /* / */
  | Multiply(expression, expression) /* * */
  | Keys /* keys */
  | Index(int) /* [1] */
  | Length /* length */
  | List /* [] - Not implemented */
  | Object /* {} - Not implemented */
  | Apply(expression) /* Not implemented */
  | MapValues(expression) /* .map_values(x) - Not implemented */
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

let tryingToOperateInAWrongType = (op, memberKind, value: Yojson.Basic.t) => {
  raise(
    WrongOperation(
      "\n ERROR: Trying to "
      ++ op
      ++ " on a "
      ++ memberKind
      ++ "."
      ++ "\n\n The value recived by "
      ++ op
      ++ " is: "
      ++ Yojson.Basic.pretty_to_string(value),
    ),
  );
};

let operationInWrongType = (name, json) => {
  switch (json) {
  | `List(_list) => tryingToOperateInAWrongType(name, "list", json)
  | `Assoc(_a) => tryingToOperateInAWrongType(name, "object", json)
  | `Bool(_b) => tryingToOperateInAWrongType(name, "bool", json)
  | `Float(_f) => tryingToOperateInAWrongType(name, "float", json)
  | `Int(_i) => tryingToOperateInAWrongType(name, "int", json)
  | `Null => tryingToOperateInAWrongType(name, "null", json)
  | `String(_identifier) => tryingToOperateInAWrongType(name, "string", json)
  };
};

let sum = (amount: int, json): Yojson.Basic.t => {
  switch (json) {
  | `Float(float) => `Float(float_of_int(amount) +. float)
  | `Int(int) => `Float(float_of_int(amount + int))
  | _ => operationInWrongType("+", json)
  };
};

/* .store.books | map(.price + 10) */
/* let transformedProgram = json => {
     json
     |> member("store")
     |> member("books")
     |> map(item => sum(10, member("price", item)));
   }; */

let keys = json => `List(Json.keys(json) |> List.map(i => `String(i)));

/* .store.books[0].keys */
/* let transformedProgram = json => {
     json |> member("store") |> member("books") |> index(0) |> keys;
   };
    */

let length = json => `Int(json |> Json.to_list |> List.length);

/* .store.books.length */
/* let transformedProgram = json => {
     json |> member("store") |> member("books") |> length;
   };
    */

let compare =
    (
      str: string,
      f: (float, float) => bool,
      left: Yojson.Basic.t,
      right: Yojson.Basic.t,
    ) => {
  switch (left, right) {
  | (`Float(l), `Float(r)) => f(l, r)
  | (`Int(l), `Float(r)) => f(float_of_int(l), r)
  | (`Float(l), `Int(r)) => f(l, float_of_int(r))
  | (`Int(l), `Int(r)) => f(float_of_int(l), float_of_int(r))
  | _ => operationInWrongType(str, right)
  };
};

let gt = compare(">", (l, r) => l > r);
let gte = compare(">=", (l, r) => l >= r);
let lt = compare("<", (l, r) => l < r);
let lte = compare("<=", (l, r) => l <= r);
let eq = compare("==", (l, r) => l == r);
let notEq = compare("!=", (l, r) => l != r);

let filter = (fn: Yojson.Basic.t => bool, json: Yojson.Basic.t) => {
  switch (json) {
  | `List(list) => `List(List.filter(fn, list))
  | _ => operationInWrongType("filter", json)
  };
};

let id: Yojson.Basic.t => Yojson.Basic.t = i => i;

/* .store.books | filter(.price > 10) */
/* let transformedProgram = json => {
     json
     |> member("store")
     |> member("books")
     |> filter(item => gt(member("price", item), 10.));
   };
    */

let program =
  Pipe(
    Pipe(Key("store"), Key("books")),
    Filter(EQ(Key("price"), Literal(Int(8.)))),
  );

exception CompilationError(string);

let fromAstToYojson = (literal: literal): Yojson.Basic.t =>
  switch (literal) {
  | Bool(b) => `Bool(b)
  | Int(int) => `Int(int_of_float(int))
  | Float(float) => `Float(float)
  | String(string) => `String(string)
  };

let rec compile = (expression: expression, json: Yojson.Basic.t) => {
  switch (expression) {
  | Identity => id(json)
  | Key(key) => member(key, json)
  | Map(expr) => map(compile(expr), json)
  | Literal(literal) => fromAstToYojson(literal)
  | Filter(conditional) =>
    filter(
      item => {
        switch (conditional) {
        | GT(exprA, exprB) =>
          gt(compile(exprA, item), compile(exprB, item))
        | GTE(exprA, exprB) =>
          gte(compile(exprA, item), compile(exprB, item))
        | LT(exprA, exprB) =>
          lt(compile(exprA, item), compile(exprB, item))
        | LTE(exprA, exprB) =>
          lte(compile(exprA, item), compile(exprB, item))
        | EQ(exprA, exprB) =>
          eq(compile(exprA, item), compile(exprB, item))
        | NOT_EQ(exprA, exprB) =>
          notEq(compile(exprA, item), compile(exprB, item))
        }
      },
      json,
    )
  | Pipe(exprA, exprB) => compile(exprB, compile(exprA, json))
  | _ => raise(CompilationError("Not implemented"))
  };
};

/* json
   |> member("store")
   |> member("book")
   |> filter(item => gt(member("price", item), 10.))
   |> member("title"); */

let main = () => {
  let json = Yojson.Basic.from_string(stdinMock);
  let output = compile(program, json);

  Yojson.Basic.pretty_to_string(output);
};

Console.log(main());
