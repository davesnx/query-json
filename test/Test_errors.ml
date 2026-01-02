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
    (* split argument type mismatch - now a parse-time error *)
    test "split(1)" "\"a,b\"" "requires a string literal separator";
    (* split input type mismatch *)
    test "split(\",\")" "123" "Trying to 'split' on a number";
    (* join argument type mismatch - now a parse-time error *)
    test "join(1)" "[\"a\", \"b\"]" "requires a string literal separator";
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
    test "$undefined" "null" "Undefined variable";
    (* Unsupported break *)
    test "break" "null" "break used outside of loop context";
    (* Object shorthand validation *)
    test "{(1): 2}" "null" "object key must be string";
    (* Helpful error messages for deprecated/unimplemented jq functions *)
    test "tojson" "null" "not implemented";
    test "fromjson" "null" "not implemented";
    test "input" "null" "not implemented";
    test "inputs" "null" "not implemented";
    test "modulemeta" "null" "not implemented";
    test "strftime" "null" "not implemented";
    test "strptime" "null" "not implemented";
    (* Strict member access errors *)
    test ".foo" "{}" "not found";
    test ".bar" "{\"baz\": 1}" "not found";
    test ".[5]" "[1,2,3]" "out of bounds";
    test ".[-10]" "[1,2]" "out of bounds";
    (* Type mismatch errors *)
    test ".foo" "123" "Cannot index";
    test ".[0]" "{\"a\": 1}" "object";
    test ". + null" "\"foo\"" "Cannot add string to null";
    (* get_path/set_path/delete_paths without arguments *)
    test "get_path" "null" "requires an argument";
    test "set_path" "null" "requires arguments";
    test "delete_paths" "null" "requires arguments";
    (* Unimplemented jq functions that should provide helpful errors *)
    test "format(\"csv\")" "null" "not implemented";
    (* Type errors for snake_case functions *)
    test "starts_with(123)" "\"hello\""
      "starts_with requires string prefix, got number";
    test "ends_with(123)" "\"hello\""
      "ends_with requires string suffix, got number";
    test "trim_start(123)" "\"hello\""
      "trim_start requires string prefix, got number";
    test "trim_end(123)" "\"hello\""
      "trim_end requires string suffix, got number";
    test "split(123)" "\"a,b\"" "requires a string literal separator";
    test "join(123)" "[\"a\", \"b\"]" "requires a string literal separator";
    (* Type errors for input type mismatches *)
    test "to_number" "[]" "to_number";
    test "to_number" "{}" "to_number";
    test "starts_with(\"x\")" "123" "cannot apply starts_with to a number";
    test "ends_with(\"x\")" "123" "cannot apply ends_with to a number";
    (* Function calls with empty parens default to identity, so they run
       and may produce runtime errors depending on input type *)
    test "pluck(.a)" "123" "pluck";
    test "pluck(.a)" "{\"a\":1}" "pluck";
    (* compact on non-array *)
    test "compact" "123" "compact";
    test "compact" "\"string\"" "compact";
    (* partition on non-array *)
    test "partition(. > 0)" "123" "partition";
    test "partition(. > 0)" "{\"a\":1}" "partition";
    (* is_empty on wrong type *)
    test "is_empty" "123" "is_empty";
    test "is_empty" "true" "is_empty";
    (* is_blank on wrong type *)
    test "is_blank" "123" "is_blank";
    test "is_blank" "true" "is_blank";
    (* assert failure *)
    test "assert(. > 10)" "5" "assertion failed";
    test "assert(. > 10; \"value must be > 10\")" "5" "value must be > 10";
    (* Regex functions require string literal patterns (compiled at parse time) *)
    test "test(.pattern)" "{\"pattern\": \"hello\"}"
      "requires a string literal regex pattern";
    test "match(.pattern)" "{\"pattern\": \"hello\"}"
      "requires a string literal regex pattern";
    test "scan(.pattern)" "{\"pattern\": \"hello\"}"
      "requires a string literal regex pattern";
    test "capture(.pattern)" "{\"pattern\": \"hello\"}"
      "requires a string literal regex pattern";
  ]
