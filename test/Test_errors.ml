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
    test "{(1): 2}" "null" "object key must be string";
    (* Helpful error messages for deprecated/unimplemented jq functions *)
    test "tojson" "null" "tojson/fromjson not implemented";
    test "fromjson" "null" "tojson/fromjson not implemented";
    test "input" "null" "input/inputs not implemented";
    test "inputs" "null" "input/inputs not implemented";
    test "modulemeta" "null" "modulemeta not implemented";
    test "strftime" "null" "time formatting not implemented";
    test "strptime" "null" "time formatting not implemented";
    (* Strict member access errors *)
    test ".foo" "{}" "key 'foo' not found";
    test ".bar" "{\"baz\": 1}" "key 'bar' not found";
    test ".[5]" "[1,2,3]" "out of bounds";
    test ".[-10]" "[1,2]" "out of bounds";
    (* Type mismatch errors *)
    test ".foo" "123" "cannot access .foo on number";
    test ".[0]" "{\"a\": 1}" "cannot apply";
    test ". + null" "\"foo\"" "Cannot add string to null";
    (* getpath/setpath without arguments *)
    test "getpath" "null" "getpath requires an argument";
    test "setpath" "null" "setpath requires arguments";
    test "delpaths" "null" "delpaths requires arguments";
    (* snake_case aliases also work and produce same error messages *)
    test "get_path" "null" "getpath requires an argument";
    test "set_path" "null" "requires arguments";
    test "delete_paths" "null" "requires arguments";
    (* Unimplemented jq functions that should provide helpful errors *)
    test "first()" "null" "contain a body";
    test "last()" "null" "contain a body";
    test "format(\"csv\")" "null" "format not implemented";
    (* Type errors for snake_case functions *)
    test "starts_with(123)" "\"hello\""
      "starts_with requires string prefix, got number";
    test "ends_with(123)" "\"hello\""
      "ends_with requires string suffix, got number";
    test "trim_start(123)" "\"hello\""
      "trim_start requires string prefix, got number";
    test "trim_end(123)" "\"hello\""
      "trim_end requires string suffix, got number";
    test "split(123)" "\"a,b\"" "split() requires a string literal separator";
    test "join(123)" "[\"a\", \"b\"]"
      "join() requires a string literal separator";
    (* Type errors for input type mismatches *)
    test "to_number" "[]" "cannot apply to_number to an array";
    test "to_number" "{}" "cannot apply to_number to an object";
    test "starts_with(\"x\")" "123" "cannot apply starts_with to a number";
    test "ends_with(\"x\")" "123" "cannot apply ends_with to a number";
    (* Function calls without required arguments *)
    test "map()" "null" "contain a body";
    test "select()" "null" "contain a body";
    test "sort_by()" "null" "contain a body";
    test "group_by()" "null" "contain a body";
    test "unique_by()" "null" "contain a body";
    test "pluck(.a)" "123" "cannot apply pluck to a number";
    test "pluck(.a)" "{\"a\":1}" "cannot apply pluck to an object";
    (* compact on non-array *)
    test "compact" "123" "cannot apply compact to a number";
    test "compact" "\"string\"" "cannot apply compact to a string";
    (* partition on non-array *)
    test "partition(. > 0)" "123" "cannot apply partition to a number";
    test "partition(. > 0)" "{\"a\":1}" "cannot apply partition to an object";
    (* is_empty on wrong type *)
    test "is_empty" "123" "cannot apply is_empty to a number";
    test "is_empty" "true" "cannot apply is_empty to a boolean";
    (* is_blank on wrong type *)
    test "is_blank" "123" "cannot apply is_blank to a number";
    test "is_blank" "true" "cannot apply is_blank to a boolean";
    (* assert failure *)
    test "assert(. > 10)" "5" "assertion failed";
    test "assert(. > 10; \"value must be > 10\")" "5" "value must be > 10";
    test "find_all()" "null" "contain a body";
    test "find_first()" "null" "contain a body";
    test "paths_to()" "null" "contain a body";
  ]
