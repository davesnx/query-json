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
let stdinMock = {|
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
    ],
    "bicycle": {
      "color": "red",
      "price": 19.95
    }
  }
}
|};

type errorWrapper = {
  message: string,
  error: exn,
};
let errorStack = [];

let safe = (msg, f) =>
  try(f()) {
  | error => List.append(errorStack, [{message: msg, error}])
  };

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

open Yojson.Basic.Util;

let transformedProgram = json => {
  json
  |> member("store")
  |> member("book")
  |> to_list
  |> filter_map(book => {
       let int = to_number_option(member("price", book));
       switch (int) {
       | Some(i) => Some(i < 10.)
       | None => None
       };
     })
  |> map(a => a + 1);
};

let main = () => {
  let json = Yojson.Basic.from_string(stdinMock);
  let stdout = transformedProgram(json);
  Console.log(stdout);
};

main();
