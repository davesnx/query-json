let test query json_str expected_error_part =
  let fn () =
    match Json.parse_string json_str with
    | Error err -> Alcotest.fail ("JSON parse error: " ^ err)
    | Ok json -> (
        match Core.run ~colorize:false query json with
        | Ok r -> Alcotest.failf "Expected an error, but got Ok: %s" r
        | Error err -> (
            let re = Str.regexp_string expected_error_part in
            try ignore (Str.search_forward re err 0)
            with Not_found ->
              Alcotest.failf "Expected error containing '%s', but got:\n%s"
                expected_error_part err))
  in
  Alcotest.test_case query `Quick fn

let tests =
  [
    (* split argument type mismatch *)
    test "split(1)" "\"a,b\"" "Invalid argument for 'split'";
    (* split input type mismatch *)
    test "split(\",\")" "123" "Trying to 'split' on a number";
    (* join argument type mismatch *)
    test "join(1)" "[\"a\", \"b\"]" "Invalid argument for 'join'";
    (* join input type mismatch *)
    test "join(\",\")" "123" "Trying to 'join' on";
    (* from_entries invalid structure *)
    test "from_entries" "[1, 2]" "Invalid structure for 'from_entries'";
    test "from_entries" "[{\"key\": 1}]" "Invalid structure for 'from_entries'";
    (* transpose invalid structure *)
    test "transpose" "[1, [2]]" "Invalid structure for 'transpose'";
    (* has invalid argument types *)
    test "has(true)" "{}" "is not allowed";
    (* Ast validation *)

    (* to_entries input type mismatch *)
    test "to_entries" "[]" "Invalid structure for 'to_entries'";
    (* Undefined variables *)
    test "$undefined" "null" "Error: Undefined variable: $undefined";
    (* Unsupported break *)
    test "break" "null" "Error: break used outside of loop context";
    (* Object shorthand validation *)
    test "{(1): 2}" "null" "Error: object key must be string";
  ]
