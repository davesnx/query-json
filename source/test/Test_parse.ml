let test input expected =
  let fn () =
    let result =
      match Core.parse ~debug:false ~colorize:false input with
      | Ok r ->
          r
      | Error err ->
          Alcotest.fail err
    in
    Alcotest.check Alcotest.string "should be equal"
      (Ast.show_expression expected)
      (Ast.show_expression result)
  in
  Alcotest.test_case input `Quick fn

open Ast

let int_num n = Literal (Number (Integer (Int.to_string n)))
let integer_num s = Literal (Number (Integer s))
let decimal_num s = Literal (Number (Decimal s))

let tests =
  [
    test ".[-1]" (Pipe (Identity, Index [ -1 ]));
    test ".[1]" (Pipe (Identity, Index [ 1 ]));
    test "[1]" (List (Some (int_num 1)));
    test ".store.books" (Pipe (Key "store", Key "books"));
    test ".books[1]" (Pipe (Key "books", Index [ 1 ]));
    test ".books[1].author"
      (Pipe (Pipe (Key "books", Index [ 1 ]), Key "author"));
    test ".store" (Key "store");
    test "." Identity;
    test ".store | .books" (Pipe (Key "store", Key "books"));
    test ". | map(.price + 1)"
      (Pipe
         ( Identity,
           Fn1 (With_expr (Map, Operation (Key "price", Add, int_num 1)))
         )
      );
    test ".WAT" (Key "WAT");
    test "head" (Fn0 First);
    test ".WAT?" (Optional (Key "WAT"));
    test "1, 2" (Comma (int_num 1, int_num 2));
    test "empty" (Fn0 Empty);
    test "(1, 2) + 3" (Operation (Comma (int_num 1, int_num 2), Add, int_num 3));
    test "1 + 2 * 3"
      (Operation (int_num 1, Add, Operation (int_num 2, Multiply, int_num 3)));
    test "[1, 2]" (List (Some (Comma (int_num 1, int_num 2))));
    test "select(true)" (Fn1 (With_expr (Select, Literal (Bool true))));
    test "[1][0]" (Pipe (List (Some (int_num 1)), Index [ 0 ]));
    test "[1].foo" (Pipe (List (Some (int_num 1)), Key "foo"));
    test "(empty).foo?" (Pipe (Fn0 Empty, Optional (Key "foo")));
    (* Optional access on nullary functions *)
    test "first?" (Optional (Fn0 First));
    test "last?" (Optional (Fn0 Last));
    test "empty?" (Optional (Fn0 Empty));
    test "keys?" (Optional (Fn0 Keys));
    (* Optional access on function calls with arguments *)
    test "first(.)?" (Optional (Fn1 (With_expr (First_expr, Identity))));
    test "last(.)?" (Optional (Fn1 (With_expr (Last_expr, Identity))));
    test "map(.x)?" (Optional (Fn1 (With_expr (Map, Key "x"))));
    (* Optional function call syntax: fn?(args) is equivalent to fn(args)? *)
    test "first?(range(3))"
      (Optional (Fn1 (With_expr (First_expr, Range (int_num 3, None, None)))));
    test "last?(empty)" (Optional (Fn1 (With_expr (Last_expr, Fn0 Empty))));
    (* Optional access on parenthesized expressions *)
    test "(first)?" (Optional (Fn0 First));
    test "(.foo)?" (Optional (Key "foo"));
    test ".foo?" (Optional (Key "foo"));
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
           (Literal (String "foo"), Some (int_num 42));
           ( Literal (String "bar"),
             Some
               (List (Some (Comma (Literal (String "hello world"), int_num 42))))
           );
           (Literal (String "user"), None);
         ]
      );
    test "range(1;2)" (Range (int_num 1, Some (int_num 2), None));
    test "range(1;2;3)" (Range (int_num 1, Some (int_num 2), Some (int_num 3)));
    test "if true then \"Hello\" else \"Welcome\" end"
      (If_then_else
         ( Literal (Bool true),
           Literal (String "Hello"),
           Literal (String "Welcome")
         )
      );
    test "if true then \"Hello\" elif false then \"Welcome\" else \"Real\" end"
      (If_then_else
         ( Literal (Bool true),
           Literal (String "Hello"),
           If_then_else
             ( Literal (Bool false),
               Literal (String "Welcome"),
               Literal (String "Real")
             )
         )
      );
    test "map(add)" (Fn1 (With_expr (Map, Fn0 Add)));
    test "[.[] | { name: .name, city: .address.city}]"
      (List
         (Some
            (Pipe
               ( Pipe (Identity, Index []),
                 Object
                   [
                     (Literal (String "name"), Some (Key "name"));
                     ( Literal (String "city"),
                       Some (Pipe (Key "address", Key "city"))
                     );
                   ]
               )
            )
         )
      );
    test "99999999999999999999999999999"
      (integer_num "99999999999999999999999999999");
    test "9223372036854775808" (integer_num "9223372036854775808");
    test "-99999999999999999999999999999"
      (integer_num "-99999999999999999999999999999");
    test "99999999999999999999999999999 + 1"
      (Operation (integer_num "99999999999999999999999999999", Add, int_num 1));
    test "0.1" (decimal_num "0.1");
    test "1.23456e+14" (decimal_num "1.23456e+14");
    test "-1.5e-2" (decimal_num "-1.5e-2");
    test "has(2)" (Fn1 (With_expr (Has, int_num 2)));
    test "has(1e0)" (Fn1 (With_expr (Has, decimal_num "1e0")));
    test "fn double: . * 2;"
      (Pipe
         (Fn ("double", [], Operation (Identity, Multiply, int_num 2)), Identity)
      );
    test "fn double: . * 2; double"
      (Pipe
         ( Fn ("double", [], Operation (Identity, Multiply, int_num 2)),
           Apply ("double", [])
         )
      );
  ]
