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
  (".store", Key("store")),
  (".store.books", Pipe(Key("store"), Key("books"))),
  (".store | .books", Pipe(Key("store"), Key("books"))),
  (
    ". | map(.price + 1)",
    Pipe(Identity, Map(Addition(Key("price"), Literal(Number(1.))))),
  ),
];

describe("correctly parse value", ({test, _}) => {
  let runTest = (index, (result, expected)) =>
    test(
      "parse: " ++ string_of_int(index),
      payload => {
        let result = parse(result);
        compare(expected, result, payload);
      },
    );

  List.iteri(runTest, tests);
});
