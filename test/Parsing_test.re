open QueryJsonCore.Main;

let assert_string = (left, right) =>
  Alcotest.check(Alcotest.string, "should be equal", right, left);

let debug = false;

let case = (input, expected) => {
  let fn = () => {
    let result =
      switch (parse(~debug, input)) {
      | Ok(r) => r
      | Error(err) => Alcotest.fail(err)
      };
    let expected = show_expression(expected);
    let result = show_expression(result);
    assert_string(result, expected);
  };
  Alcotest.test_case(input, `Quick, fn);
};

let tests = [
  case(".[1]", Pipe(Identity, Index(1))),
  case("[1]", List(Literal(Number(1.)))),
  case(".store.books", Pipe(Key("store", false), Key("books", false))),
  case(".books[1]", Pipe(Key("books", false), Index(1))),
  case(
    ".books[1].author",
    Pipe(Pipe(Key("books", false), Index(1)), Key("author", false)),
  ),
  case(".store", Key("store", false)),
  case(".", Identity),
  case(".store | .books", Pipe(Key("store", false), Key("books", false))),
  case(
    ". | map(.price + 1)",
    Pipe(
      Identity,
      Map(Addition(Key("price", false), Literal(Number(1.)))),
    ),
  ),
  case(".WAT", Key("WAT", false)),
  case("head", Head),
  case(".WAT?", Key("WAT", true)),
  case("1, 2", Comma(Literal(Number(1.)), Literal(Number(2.)))),
  case("empty", Empty),
  case(
    "(1, 2) + 3",
    Addition(
      Comma(Literal(Number(1.)), Literal(Number(2.))),
      Literal(Number(3.)),
    ),
  ),
  case("[1, 2]", List(Comma(Literal(Number(1.)), Literal(Number(2.))))),
  case("select(true)", Select(Literal(Bool(true)))),
  case("[1][0]", Pipe(List(Literal(Number(1.))), Index(0))),
  case("[1].foo", Pipe(List(Literal(Number(1.))), Key("foo", false))),
  case("(empty).foo?", Pipe(Empty, Key("foo", true))),
];
