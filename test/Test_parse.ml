let assert_string left right =
  Alcotest.check Alcotest.string "should be equal" right left

let case input expected =
  let fn () =
    let result =
      match Core.parse ~debug:false input with
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
    case ". | map(.price + 1)"
      (Pipe (Identity, Map (Operation (Key "price", Add, Literal (Number 1.)))));
    case ".WAT" (Key "WAT");
    case "head" Head;
    case ".WAT?" (Optional (Key "WAT"));
    case "1, 2" (Comma (Literal (Number 1.), Literal (Number 2.)));
    case "empty" Empty;
    case "(1, 2) + 3"
      (Operation
         ( Comma (Literal (Number 1.), Literal (Number 2.)),
           Add,
           Literal (Number 3.) ));
    case "1 + 2 * 3"
      (Operation
         ( Literal (Number 1.),
           Add,
           Operation (Literal (Number 2.), Multiply, Literal (Number 3.)) ));
    case "[1, 2]" (List [ Literal (Number 1.); Literal (Number 2.) ]);
    case "select(true)" (Select (Literal (Bool true)));
    case "[1][0]" (Pipe (List [ Literal (Number 1.) ], Index 0));
    case "[1].foo" (Pipe (List [ Literal (Number 1.) ], Key "foo"));
    case "(empty).foo?" (Pipe (Empty, Optional (Key "foo")));
    case ".[1:3]" (Pipe (Identity, Slice (Some 1, Some 3)));
    case ".[1:]" (Pipe (Identity, Slice (Some 1, None)));
    case ".[:3]" (Pipe (Identity, Slice (None, Some 3)));
    case ".[-2:]" (Pipe (Identity, Slice (Some (-2), None)));
    case ".[]" (Pipe (Identity, Iterator));
    case ".foo[]" (Pipe (Key "foo", Iterator));
    case ".foo[]?" (Pipe (Key "foo", Optional Iterator));
    case ".foo?[]" (Pipe (Optional (Key "foo"), Iterator));
    case ".foo?[]?" (Pipe (Optional (Key "foo"), Optional Iterator));
    case "{}" (Object []);
    case "{\"foo\": 42, bar: [\"hello world\", 42], user}"
      (Object
         [
           (Literal (String "foo"), Some (Literal (Number 42.)));
           ( Literal (String "bar"),
             Some
               (List [ Literal (String "hello world"); Literal (Number 42.) ])
           );
           (Literal (String "user"), None);
         ]);
    case "range(1;2)" (Range (1, Some 2, None));
    case "range(1;2;3)" (Range (1, Some 2, Some 3));
    case "if true then \"Hello\" else \"Welcome\" end"
      (If_then_else
         ( Literal (Bool true),
           Literal (String "Hello"),
           Literal (String "Welcome") ));
    case "if true then \"Hello\" elif false then \"Welcome\" else \"Real\" end"
      (If_then_else
         ( Literal (Bool true),
           Literal (String "Hello"),
           If_then_else
             ( Literal (Bool false),
               Literal (String "Welcome"),
               Literal (String "Real") ) ));
    case "map(add)" (Map (Fun Add));
  ]
