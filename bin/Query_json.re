[@deriving show]
type identifier = string;

[@deriving show]
type literal =
  | Bool(bool) /* true */
  | String(string) /* "TEXT" */
  | Int(int) /* 123 */
  | Float(float); /* 12.3 */

[@deriving show]
type expression =
  | Main(expression)
  | Literal(literal)
  | Identity /* . */
  | Key(identifier) /* .foo */
  | Map(expression) /* .[] */ /* map(x) */
  | Filter(expression) /* .filter(x) */
  | Select(expression) /* .select(x) - Not implemented */
  | Pipe(expression, expression) /* | */
  | Addition(expression, expression) /* + */
  | Subtraction(expression, expression) /* - */
  | Division(expression, expression) /* / */
  | Multiply(expression, expression) /* * */
  | GT(expression, expression) /* Greater > */
  | LW(expression, expression) /* Lower < */
  | GET(expression, expression) /* Greater equal >= */
  | LWT(expression, expression) /* Lower equal <= */
  | Keys /* keys */
  | Index(int) /* [1] */
  | Length /* length */
  | List /* [] - Not implemented */
  | Object /* {} - Not implemented */
  | Apply(expression) /* Not implemented */
  | MapValues(expression); /* .map_values(x) - Not implemented */

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

let gt = (json: Yojson.Basic.t, value: float): bool => {
  switch (json) {
  | `Float(float) => float > value
  | `Int(int) => int > int_of_float(value)
  | _ => operationInWrongType(">", json)
  };
};

let gte = (json: Yojson.Basic.t, value: float): bool => {
  switch (json) {
  | `Float(float) => float >= value
  | `Int(int) => int >= int_of_float(value)
  | _ => operationInWrongType(">=", json)
  };
};

let lt = (json: Yojson.Basic.t, value: float): bool => {
  switch (json) {
  | `Float(float) => float < value
  | `Int(int) => int < int_of_float(value)
  | _ => operationInWrongType("<", json)
  };
};

let lte = (json: Yojson.Basic.t, value: float): bool => {
  switch (json) {
  | `Float(float) => float <= value
  | `Int(int) => int <= int_of_float(value)
  | _ => operationInWrongType("<=", json)
  };
};

let filter = (fn: Yojson.Basic.t => bool, json: Yojson.Basic.t) => {
  switch (json) {
  | `List(list) => `List(List.filter(fn, list))
  | _ => operationInWrongType("filter", json)
  };
};

let id: 'a => 'a = i => i;

/* .store.books | filter(.price > 10) */
/* let transformedProgram = json => {
     json
     |> member("store")
     |> member("books")
     |> filter(item => gt(member("price", item), 10.));
   };
    */

let program = Main(Identity);
/* Pipe(
     Pipe(Pipe(Identity, Key("store")), Key("book")),
     Pipe(
       Filter(LW(Key("price"), Literal(Float(10.)))),
       Map(Key("title")),
     ),
   ), */

exception CompilationError(string);

let compile = (expression: expression, _json): Yojson.Basic.t => {
  switch (expression) {
  | Main(expr) =>
    switch (expr) {
    | Main(_) => raise(CompilationError("Main() can't be nested"))
    | _ => raise(CompilationError("Not implemented"))
    }
  | _ => raise(CompilationError("Program should contain a Main() as a root"))
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
