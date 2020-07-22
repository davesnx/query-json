[@deriving show]
type identifier = string;

[@deriving show]
type literal =
  | Bool(bool) /* true */
  | String(string) /* "awasdf" */
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
  | OptionalKey(identifier) /* .foo? */
  | ObjIndex(string) /* ["foo"] */
  | Map(expression) /* .[] */ /* map(x) */
  | Select(expression) /* .select(x) */
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
  | List /* [] */
  | Object /* {} */
  | Apply(expression)
  | Compare(expression, conditional, expression); /* => */

/* .store.book | map(select(.price < 10)) | map(.title) */

let program =
  Pipe(
    Pipe(Pipe(Identity, Key("store")), Key("book")),
    Pipe(
      Map(Select(Compare(Key("price"), LW, Literal(Int(10))))),
      Map(Key("title")),
    ),
  );

[@deriving show]
let stdinMock1 = {|
  { "store": {
    "book": [
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

[@deriving show]
let stdinMock2 = {|
  {
    "id": "398eb027",
    "name": "John Doe",
    "pages": [
        {
          "id": 1,
          "title": "The Art of Flipping Coins",
          "url": "http://example.com/398eb027/1"
        },
        { "id": 2, "deleted": true },
        {
          "id": 3,
          "title": "Artichoke Salad",
          "url": "http://example.com/398eb027/3"
        },
        {
          "id": 4,
          "title": "Flying Bananas",
          "url": "http://example.com/398eb027/4"
        }
      ]
    }
|};

/* .store.book | map(select(.price < 10)) | map(.title) */

/* let program =
    Pipe(
      Pipe(Pipe(Identity, Key("store")), Key("book")),
      Pipe(
        Map(Select(Compare(Key("price"), LW, Literal(Int(10))))),
        Map(Key("title")),
      ),
    );
   */

/* |> filter_map(book => {
     let int = to_number_option(member("price", book));
     switch (int) {
     | Some(i) => Some(i < 10.)
     | None => None
     };
   }); */

/* type json = [
    | `Assoc of (string * json) list
    | `Bool of bool
    | `Float of float
    | `Int of int
    | `List of json list
    | `Null
    | `String of string
   ]
    */

open Yojson.Basic.Util;

exception WrongOperation(string);

module QueryJson = {
  module ErrorWrapper = {
    type t = {
      message: string,
      error: exn,
    };

    let stack = [];
  };

  let safe = (msg, f) =>
    try(f()) {
    | error =>
      let wrappedError: ErrorWrapper.t = {message: msg, error};
      List.append(ErrorWrapper.stack, [wrappedError]);
    };

  module Lib = {
    let tryingToOperateInAWrongType = (op, memberKind, value: option(string)) => {
      switch (value) {
      | Some(v) =>
        raise(
          WrongOperation(
            "Trying to " ++ op ++ "on a " ++ v ++ "which is" ++ memberKind,
          ),
        )
      | None =>
        raise(WrongOperation("Trying to " ++ op ++ "on a " ++ memberKind))
      };
    };

    let operationInWrongType = (name, json) => {
      switch (json) {
      | `List(list) => tryingToOperateInAWrongType(name, "list", None)
      | `Assoc(a) => tryingToOperateInAWrongType(name, "object", Some("obj"))
      | `Bool(b) =>
        tryingToOperateInAWrongType(name, "bool", Some(string_of_bool(b)))
      | `Float(f) =>
        tryingToOperateInAWrongType(name, "float", Some(string_of_float(f)))
      | `Int(i) =>
        tryingToOperateInAWrongType(
          name,
          "int: %d\n",
          Some(string_of_int(i)),
        )
      | `Null => tryingToOperateInAWrongType(name, "null", None)
      | `String(s) => tryingToOperateInAWrongType(name, "string", Some(s))
      };
    };

    let key = id => filter_member(id);

    let mapper = (f, json: Yojson.Basic.t) => {
      switch (json) {
      | `List(list) => List.map(f, list)
      | _ => operationInWrongType("map", json)
      };
    };

    let truncate = (f, json: Yojson.Basic.t) => {
      switch (json) {
      | `Float(f) => f +. 1.
      | _ => operationInWrongType("truncate", json)
      };
    };
  };
};

open QueryJson;
open QueryJson.Lib;

let transformedProgram = json => {
  [json]
  |> key("store")
  |> key("book")
  |> flatten
  |> key("price")
  |> mapper(truncate);
};

/* .pages | map(.title) */

let main = () => {
  let json = Yojson.Basic.from_string(stdinMock1);
  let stdout = transformedProgram(json);
  Console.log(stdout);
};

main();
