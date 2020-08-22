[@deriving show]
type identifier = string;

[@deriving show]
type literal =
  | Bool(bool) /* true */
  | String(string) /* "TEXT" */
  | Int(int) /* 123 */
  | Float(float); /* 12.3 */

[@deriving show]
type conditional =
  | GT /* Greater > */
  | LW /* Lower < */
  | GET /* Greater equal >= */
  | LWT; /* Lower equal <= */

[@deriving show]
type expression =
  | Literal(literal)
  | Identity /* . */
  | Key(identifier) /* .foo */
  | ObjIndex(string) /* ["foo"] */
  | Map(expression) /* .[] */ /* map(x) */
  | Filter(expression) /* .filter(x) */
  | MapValues(expression) /* .map_values(x) */
  | In /* in */
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
  | Compare(expression, conditional, expression); /* => */

let program =
  Pipe(
    Pipe(Pipe(Identity, Key("store")), Key("book")),
    Pipe(
      Map(Select(Compare(Key("price"), LW, Literal(Int(10))))),
      Map(Key("title")),
    ),
  );

[@deriving show]
let stdinMock = {|
  { "store": {
    "books": [
      { "category": "reference",
        "author": "Nigel Rees",
        "title": "Sayings of the Century",
        "price": 8.95
      },
      { "category": "fiction",
        "author": "Evelyn Waugh",
        "title": "Sword of Honour",
        "price": 12.99
      },
      { "category": "fiction",
        "author": "Herman Melville",
        "title": "Moby Dick",
        "isbn": "0-553-21311-3",
        "price": 8.99
      },
      { "category": "fiction",
        "author": "J. R. R. Tolkien",
        "title": "The Lord of the Rings",
        "isbn": "0-395-19395-8",
        "price": 22.99
      }
    ]
  }}
|};

open Yojson.Basic.Util;

exception WrongOperation(string);

let tryingToOperateInAWrongType = (op, memberKind, value: option(string)) => {
  switch (value) {
  | Some(v) =>
    raise(
      WrongOperation(
        "Trying to "
        ++ op
        ++ " on a '"
        ++ v
        ++ "' which is '"
        ++ memberKind
        ++ "'",
      ),
    )
  | None =>
    raise(WrongOperation("Trying to " ++ op ++ "on a " ++ memberKind))
  };
};

let operationInWrongType = (name, json) => {
  switch (json) {
  | `List(_list) => tryingToOperateInAWrongType(name, "list", None)
  | `Assoc(_a) => tryingToOperateInAWrongType(name, "object", Some("obj"))
  | `Bool(b) =>
    tryingToOperateInAWrongType(name, "bool", Some(string_of_bool(b)))
  | `Float(f) =>
    tryingToOperateInAWrongType(name, "float", Some(string_of_float(f)))
  | `Int(i) =>
    tryingToOperateInAWrongType(name, "int", Some(string_of_int(i)))
  | `Null => tryingToOperateInAWrongType(name, "null", None)
  | `String(identifier) =>
    tryingToOperateInAWrongType(name, "string", Some(identifier))
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

let keys = json => `List(keys(json) |> List.map(i => `String(i)));

/* .store.books[0].keys */
/* let transformedProgram = json => {
     json |> member("store") |> member("books") |> index(0) |> keys;
   };
    */

let length = json => `Int(json |> to_list |> List.length);

/* .store.books.length */
/* let transformedProgram = json => {
     json |> member("store") |> member("books") |> length;
   };
    */

let gt = (json: Yojson.Basic.t, value) => {
  switch (json) {
  | `Float(float) => `Bool(float > value)
  | `Int(int) => `Bool(int > int_of_float(value))
  | _ => operationInWrongType(">", json)
  };
};

let filter = (f: list(Yojson.Basic.t) => bool, json: Yojson.Basic.t) =>
  if (f(json)) {
    Some(json);
  } else {
    None;
  };

let id: 'a => 'a = i => i;

let keepSome: list(option('a)) => list('a) =
  list => List.filter_map(id, list);

let transformedProgram = json => {
  json |> member("store") |> member("books") |> filter(_ => true);
};

/* |> map(item => select(i => gt(member("price", i), 10.), item)); */

let main = () => {
  let json = Yojson.Basic.from_string(stdinMock);
  let output = transformedProgram(json);

  Yojson.Basic.pretty_to_string(output);
};

Console.log(main());
