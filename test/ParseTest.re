open Framework;
open Source.Ast;
open Source.Main;

let compare = (expected, result, {expect, _}) => {
  let expected = show_expression(expected);
  let result = show_expression(result);
  expect.string(result).toEqual(expected);
};

let tests: list((string, expression)) = [
  (".", Identity),
  (".store", Key("store", false)),
  (".store.books", Pipe(Key("store", false), Key("books", false))),
  (".store | .books", Pipe(Key("store", false), Key("books", false))),
  (
    ". | map(.price + 1)",
    Pipe(
      Identity,
      Map(Addition(Key("price", false), Literal(Number(1.)))),
    ),
  ),
  (".[1]", Pipe(Identity, Index(1))),
  (".books[1]", Pipe(Key("books", false), Index(1))),
  (".WAT", Key("WAT", false)),
  /* (".WAT?", Key("WAT", true)), */
  ("head", Head),
];

describe("correctly parse value", ({test, _}) => {
  let runTest = (index, (result, expected)) =>
    test(
      "parse: " ++ string_of_int(index),
      payload => {
        let result = parse(~debug=false, result) |> Result.get_ok;
        compare(expected, result, payload);
      },
    );

  List.iteri(runTest, tests);
});
