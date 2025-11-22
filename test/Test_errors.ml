let test_error query json_str expected_error_part =
  let fn () =
    match Json.parse_string json_str with
    | Error err -> Alcotest.fail ("JSON parse error: " ^ err)
    | Ok json -> (
        match Core.run query json with
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
    test_error "split(1)" "\"a,b\"" "Invalid argument for 'split'";
    (* split input type mismatch *)
    test_error "split(\",\")" "123" "Trying to 'split' on an int";
    (* join argument type mismatch *)
    test_error "join(1)" "[\"a\", \"b\"]" "Invalid argument for 'join'";
    (* join input type mismatch *)
    test_error "join(\",\")" "123" "Trying to 'join' on";
    (* from_entries invalid structure *)
    test_error "from_entries" "[1, 2]" "Invalid structure for 'from_entries'";
    test_error "from_entries" "[{\"key\": 1}]"
      "Invalid structure for 'from_entries'";
    (* transpose invalid structure *)
    test_error "transpose" "[1, [2]]" "Invalid structure for 'transpose'";
    (* has invalid argument types *)
    test_error "has(true)" "{}" "is not allowed";
    (* Ast validation *)

    (* to_entries input type mismatch *)
    test_error "to_entries" "[]" "Invalid structure for 'to_entries'";
    (* Undefined variables *)
    test_error "$undefined" "null" "Error: Undefined variable: $undefined";
    (* Unsupported break *)
    test_error "break" "null" "Error: break used outside of loop context";
    (* Object shorthand validation *)
    test_error "{(1): 2}" "null" "Error: object key must be string";
  ]
