let test input expected =
  let fn () =
    let result =
      match Core.parse ~debug:false ~colorize:false input with
      | Ok r -> r
      | Error err -> Alcotest.fail err
    in
    Alcotest.check Alcotest.string "should be equal"
      (Ast.show_expression expected)
      (Ast.show_expression result)
  in
  Alcotest.test_case input `Quick fn

let tests =
  [
    test ".[-1]" (Pipe (Identity, Index [ -1 ]));
    test ".[1]" (Pipe (Identity, Index [ 1 ]));
    test "[1]" (List (Some (Literal (Number 1.))));
    test ".store.books" (Pipe (Key "store", Key "books"));
    test ".books[1]" (Pipe (Key "books", Index [ 1 ]));
    test ".books[1].author"
      (Pipe (Pipe (Key "books", Index [ 1 ]), Key "author"));
    test ".store" (Key "store");
    test "." Identity;
    test ".store | .books" (Pipe (Key "store", Key "books"));
    test ". | map(.price + 1)"
      (Pipe (Identity, Map (Operation (Key "price", Add, Literal (Number 1.)))));
    test ".WAT" (Key "WAT");
    test "head" Head;
    test ".WAT?" (Optional (Key "WAT"));
    test "1, 2" (Comma (Literal (Number 1.), Literal (Number 2.)));
    test "empty" Empty;
    test "(1, 2) + 3"
      (Operation
         ( Comma (Literal (Number 1.), Literal (Number 2.)),
           Add,
           Literal (Number 3.) ));
    test "1 + 2 * 3"
      (Operation
         ( Literal (Number 1.),
           Add,
           Operation (Literal (Number 2.), Multiply, Literal (Number 3.)) ));
    test "[1, 2]"
      (List (Some (Comma (Literal (Number 1.), Literal (Number 2.)))));
    test "select(true)" (Select (Literal (Bool true)));
    test "[1][0]" (Pipe (List (Some (Literal (Number 1.))), Index [ 0 ]));
    test "[1].foo" (Pipe (List (Some (Literal (Number 1.))), Key "foo"));
    test "(empty).foo?" (Pipe (Empty, Optional (Key "foo")));
    test ".[1:3]" (Pipe (Identity, Slice (Some 1, Some 3)));
    test ".[1:]" (Pipe (Identity, Slice (Some 1, None)));
    test ".[:3]" (Pipe (Identity, Slice (None, Some 3)));
    test ".[-2:]" (Pipe (Identity, Slice (Some (-2), None)));
    test ".[]" (Pipe (Identity, Index []));
    test ".foo[]" (Pipe (Key "foo", Index []));
    test ".foo[]?" (Pipe (Key "foo", Optional (Index [])));
    test ".foo?[]" (Pipe (Optional (Key "foo"), Index []));
    test ".foo?[]?" (Pipe (Optional (Key "foo"), Optional (Index [])));
    test "{}" (Object []);
    test "{\"foo\": 42, bar: [\"hello world\", 42], user}"
      (Object
         [
           (Literal (String "foo"), Some (Literal (Number 42.)));
           ( Literal (String "bar"),
             Some
               (List
                  (Some
                     (Comma
                        (Literal (String "hello world"), Literal (Number 42.)))))
           );
           (Literal (String "user"), None);
         ]);
    test "range(1;2)"
      (Range (Literal (Number 1.), Some (Literal (Number 2.)), None));
    test "range(1;2;3)"
      (Range
         ( Literal (Number 1.),
           Some (Literal (Number 2.)),
           Some (Literal (Number 3.)) ));
    test "if true then \"Hello\" else \"Welcome\" end"
      (If_then_else
         ( Literal (Bool true),
           Literal (String "Hello"),
           Literal (String "Welcome") ));
    test "if true then \"Hello\" elif false then \"Welcome\" else \"Real\" end"
      (If_then_else
         ( Literal (Bool true),
           Literal (String "Hello"),
           If_then_else
             ( Literal (Bool false),
               Literal (String "Welcome"),
               Literal (String "Real") ) ));
    test "map(add)" (Map (Fun Add));
    test "[.[] | { name: .name, city: .address.city}]"
      (List
         (Some
            (Pipe
               ( Pipe (Identity, Index []),
                 Object
                   [
                     (Literal (String "name"), Some (Key "name"));
                     ( Literal (String "city"),
                       Some (Pipe (Key "address", Key "city")) );
                   ] ))));
  ]
