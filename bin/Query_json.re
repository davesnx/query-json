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

/* .store.book | filter(.price < 10)) | map(.title) */

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

exception WTF(string);

let sum = (amount, json): Yojson.Basic.t => {
  switch (json) {
  | `Float(float) => `Float(float_of_int(amount) +. float)
  | `Int(int) => `Float(float_of_int(amount + int))
  | `List(_list) => raise(WTF("List"))
  | `Assoc(_list) => raise(WTF("Assoc"))
  | `Bool(_bool) => raise(WTF("Bool"))
  | `Null => raise(WTF("Null"))
  | `String(_identifier) => raise(WTF("String"))
  };
};

let transformedProgram = json => {
  [json]
  |> filter_member("store")
  |> filter_member("books")
  |> filter_map((json: Yojson.Basic.t) => {
       switch (json) {
       | `List(list) =>
         Some(
           `List(
             List.map(item => sum(10, item), filter_member("price", list)),
           ),
         )
       | `Assoc(_list) => raise(WTF("Assoc"))
       | `Bool(_bool) => raise(WTF("Bool"))
       | `Float(_float) => raise(WTF("Float"))
       | `Int(_int) => raise(WTF("Int"))
       | `Null => raise(WTF("Null"))
       | `String(_identifier) => raise(WTF("String"))
       }
     })
  |> List.hd;
};

/* .pages | map(.price + 1) */

let main = () => {
  let json = Yojson.Basic.from_string(stdinMock1);
  let output = transformedProgram(json);

  Console.log(output);
  Yojson.Basic.pretty_to_string(output);
};

Console.log(main());

/* module Json = {
    let string_of_yojson: (string, Yojson.Safe.t) => result(string, string) =
      (memberName, json) => {
        switch (Yojson.Safe.Util.member(memberName, json)) {
        | `String(v) => Ok(v)
        | _ => Error("Missing expected property: " ++ memberName)
        };
      };

    let bool_of_yojson: Yojson.Safe.t => bool =
      json => {
        switch (json) {
        | `Bool(v) => v
        | _ => false
        };
      };

    module Decode = {
      open Oni_Core;
      open Json.Decode;

      let capture = {
        let captureSimplified = string;
        let captureNested =
          obj(({field, _}) => {field.required("name", string)});

        one_of([
          ("simplified", captureSimplified),
          ("nested", captureNested),
        ]);
      };
    };

    let captures_of_yojson: Yojson.Safe.t => list(Capture.t) =
      json => {
        open Yojson.Safe.Util;
        let f = keyValuePair => {
          let (key, json) = keyValuePair;
          let captureGroup = int_of_string_opt(key);
          let captureName =
            json |> Oni_Core.Json.Decode.decode_value(Decode.capture);

          switch (captureGroup, captureName) {
          | (Some(n), Ok(name)) => Ok((n, name))
          | _ => Error("Invalid capture group")
          };
        };

        let fold = (prev, curr) => {
          switch (f(curr)) {
          | Ok(v) => [v, ...prev]
          | _ => prev
          };
        };

        switch (json) {
        | `Assoc(list) => List.fold_left(fold, [], list) |> List.rev
        | _ => []
        };
      };

    let regex_of_yojson = (~allowBackReferences=true, json) => {
      switch (json) {
      | `String(v) => Ok(RegExpFactory.create(~allowBackReferences, v))
      | _ => Error("Regular expression not specified")
      };
    };
   */
