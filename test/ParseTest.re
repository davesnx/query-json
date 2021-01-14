open Framework;
open Source.Ast;
open Source.Main;

let compare = (expected, result, {expect, _}) => {
  let expected = show_expression(expected);
  let result = show_expression(result);
  expect.string(result).toEqual(expected);
};

let tests: list((string, expression)) = [
  (".[1]", Pipe(Identity, Index(1))),
  ("[1]", List(Literal(Number(1.)))),
  (".store.books", Pipe(Key("store", false), Key("books", false))),
  (".books[1]", Pipe(Key("books", false), Index(1))),
  (
    ".books[1].author",
    Pipe(Pipe(Key("books", false), Index(1)), Key("author", false)),
  ),
  (".store", Key("store", false)),
  (".", Identity),
  (".store | .books", Pipe(Key("store", false), Key("books", false))),
  (
    ". | map(.price + 1)",
    Pipe(
      Identity,
      Map(Addition(Key("price", false), Literal(Number(1.)))),
    ),
  ),
  (".WAT", Key("WAT", false)),
  ("head", Head),
  (".WAT?", Key("WAT", true)),
  ("1, 2", Comma(Literal(Number(1.)), Literal(Number(2.)))),
  ("empty", Empty),
  (
    "(1, 2) + 3",
    Addition(
      Comma(Literal(Number(1.)), Literal(Number(2.))),
      Literal(Number(3.)),
    ),
  ),
  ("[1, 2]", List(Comma(Literal(Number(1.)), Literal(Number(2.))))),
  ("select(true)", Select(Literal(Bool(true)))),
  ("[1][0]", Pipe(List(Literal(Number(1.))), Index(0))),
  ("[1].foo", Pipe(List(Literal(Number(1.))), Key("foo", false))),
  ("(empty).foo?", Pipe(Empty, Key("foo", true))),
];

describe("correctly parse value", ({test, _}) => {
  let runTest = (index, (result, expected)) =>
    test(
      "parse: " ++ string_of_int(index),
      payload => {
        let result =
          switch (parse(~debug=false, result)) {
          | Ok(r) => r
          | Error(err) => failwith(err)
          };
        compare(expected, result, payload);
      },
    );

  List.iteri(runTest, tests);
});
