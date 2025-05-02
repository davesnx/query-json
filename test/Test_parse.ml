let assert_string left right =
  Alcotest.check Alcotest.string "should be equal" right left

let debug = false

let case input expected =
  let fn () =
    let result =
      match Core.parse ~debug input with
      | Ok r -> r
      | Error err -> Alcotest.fail err
    in
    (* TODO: Add Ast.compare or Ast.diff via ppx_deriving and use it here *)
    let expected = Ast.show_expression expected in
    let result = Ast.show_expression result in
    assert_string result expected
  in
  Alcotest.test_case input `Quick fn

let tests =
  [
    case ".[-1]" (Pipe (Identity, Index (-1)));
    case ".[1]" (Pipe (Identity, Index 1));
    case "[1]" (List [ Literal (Number 1.) ]);
    case ".store.books" (Pipe (Key "store", Key "books"));
    case ".books[1]" (Pipe (Key "books", Index 1));
    case ".books[1].author" (Pipe (Pipe (Key "books", Index 1), Key "author"));
    case ".store" (Key "store");
    case "." Identity;
    case ".store | .books" (Pipe (Key "store", Key "books"));
    case ".store | .books" (Pipe (Key "store", Key "books"));
      (Pipe (Identity, Map (Addition (Key "price", Literal (Number 1.)))));
    case ".WAT" (Key "WAT");
         (Identity, Map (Addition (Key ("price", false), Literal (Number 1.)))));
    case ".WAT" (Key ("WAT", false));
      (Pipe (Identity, Map (Addition (Key "price", Literal (Number 1.)))));
    case ".WAT" (Key "WAT");
    case ".WAT?" (Optional (Key "WAT"));
    case ".WAT?" (Optional (Key "WAT"));
    case "empty" Empty;
    case "(1, 2) + 3"
      (Addition
         (Comma (Literal (Number 1.), Literal (Number 2.)), Literal (Number 3.)));
    case "[1, 2]" (List [ Literal (Number 1.); Literal (Number 2.) ]);
    case "select(true)" (Select (Literal (Bool true)));
    case "[1].foo" (Pipe (List [ Literal (Number 1.) ], Key "foo"));
    case "(empty).foo?" (Pipe (Empty, Optional (Key "foo")));
    case "[1].foo" (Pipe (List [ Literal (Number 1.) ], Key ("foo", false)));
    case "[1].foo" (Pipe (List [ Literal (Number 1.) ], Key "foo"));
    case "(empty).foo?" (Pipe (Empty, Optional (Key "foo")));
    case ".[1:3]" (Pipe (Identity, Slice (Some 1, Some 3)));
    case ".[1:]" (Pipe (Identity, Slice (Some 1, None)));
    case ".[:3]" (Pipe (Identity, Slice (None, Some 3)));
    case ".[-2:]" (Pipe (Identity, Slice (Some (-2), None)));
    case ".[]" (Pipe (Identity, Iterator));
    case ".foo[]" (Pipe (Key ("foo", false), Iterator));
  ]
