let test query json_str expected_error_part =
  let fn () =
    match Json.parse_string json_str with
    | Error err ->
        Alcotest.fail ("JSON parse error: " ^ err)
    | Ok json -> (
        match Core.run ~colorize:false query json with
        | Ok r ->
            Alcotest.failf "Expected an error, but got Ok: %s" r
        | Error err ->
            if not (Re.execp (Re.compile (Re.str expected_error_part)) err) then
              Alcotest.failf "Expected error containing '%s', but got:\n%s"
                expected_error_part err
      )
  in
  Alcotest.test_case query `Quick fn

let test_location name query json_str expected_parts =
  let fn () =
    match Json.parse_string json_str with
    | Error err ->
        Alcotest.fail ("JSON parse error: " ^ err)
    | Ok json -> (
        match Core.run ~colorize:false query json with
        | Ok r ->
            Alcotest.failf "Expected an error, but got Ok: %s" r
        | Error err ->
            List.iter
              (fun part ->
                if not (Re.execp (Re.compile (Re.str part)) err) then
                  Alcotest.failf "Expected error containing '%s', but got:\n%s"
                    part err
              )
              expected_parts
      )
  in
  Alcotest.test_case name `Quick fn

let tests =
  [
    test "split(1)" "\"a,b\"" "requires a string literal separator";
    test "split(\",\")" "123" "Cannot apply 'split' to a number";
    test "join(1)" "[\"a\", \"b\"]" "requires a string literal separator";
    test "join(\",\")" "123" "Cannot apply 'join' to a number";
    test "from_entries" "[1, 2]" "from_entries requires an array of objects";
    test "from_entries" "[{\"key\": 1}]"
      "from_entries requires objects with 'key' (string) and 'value' fields";
    test "transpose" "[1, [2]]" "transpose requires an array of arrays";
    test "has(true)" "{}" "expected string or number literal";
    test "to_entries" "[]" "to_entries requires an object";
    test "$undefined" "null" "undefined $undefined";
    test "break" "null" "break used outside of loop context";
    test "{(1): 2}" "null" "expected string key, found number";
    test "tojson" "null" "not implemented";
    test "fromjson" "null" "not implemented";
    test "modulemeta" "null" "not implemented";
    test "strftime" "null" "not implemented";
    test "parse_date" "null" "not implemented";
    test ".foo" "{}" "not found";
    test ".bar" "{\"baz\": 1}" "not found";
    test ".[5]" "[1,2,3]" "out of bounds";
    test ".[-10]" "[1,2]" "out of bounds";
    test ".foo" "123" "Cannot index";
    test ".[0]" "{\"a\": 1}" "object";
    test ". + null" "\"foo\"" "Cannot add string to null";
    test ".[0]" "null" "Cannot index null with [0]";
    test ".[1:2]" "null" "Cannot index null with [1:2]";
    test ".[1:2]" "1" "Cannot apply";
    test "foo?" "null" "undefined function: `foo`";
    test "try foo" "null" "undefined function: `foo`";
    test "[.[] | foo?]" "[1]" "undefined function: `foo`";
    test "get_path" "null" "requires path";
    test "set_path" "null" "requires path and value";
    test "delete_paths" "null" "requires paths";
    test "format(\"csv\")" "null" "not implemented";
    test "starts_with(123)" "\"hello\"" "expected string prefix, found number";
    test "ends_with(123)" "\"hello\"" "expected string suffix, found number";
    test "trim_start(123)" "\"hello\"" "expected string prefix, found number";
    test "trim_end(123)" "\"hello\"" "expected string suffix, found number";
    test "split(123)" "\"a,b\"" "requires a string literal separator";
    test "join(123)" "[\"a\", \"b\"]" "requires a string literal separator";
    test "to_number" "[]" "to_number";
    test "to_number" "{}" "to_number";
    test "starts_with(\"x\")" "123" "expected string, found number";
    test "ends_with(\"x\")" "123" "expected string, found number";
    test "pluck(.a)" "123" "pluck";
    test "pluck(.a)" "{\"a\":1}" "pluck";
    test "compact" "123" "compact";
    test "compact" "\"string\"" "compact";
    test "partition(. > 0)" "123" "partition";
    test "partition(. > 0)" "{\"a\":1}" "partition";
    test "is_empty" "123" "is_empty";
    test "is_empty" "true" "is_empty";
    test "is_blank" "123" "is_blank";
    test "is_blank" "true" "is_blank";
    test "assert(. > 10)" "5" "assertion failed";
    test "assert(. > 10; \"value must be > 10\")" "5" "value must be > 10";
    test "test(.pattern)" "{\"pattern\": \"hello\"}"
      "requires a string literal regex pattern";
    test "match(.pattern)" "{\"pattern\": \"hello\"}"
      "requires a string literal regex pattern";
    test "scan(.pattern)" "{\"pattern\": \"hello\"}"
      "requires a string literal regex pattern";
    test "capture(.pattern)" "{\"pattern\": \"hello\"}"
      "requires a string literal regex pattern";
    test {|error("something went wrong")|} "null" "something went wrong";
    test {|error|} {|"boom"|} "boom";
    test {|error("user error")?|} "null" "user error";
    test {|error?|} {|"boom"|} "boom";
    test "pow" "5" "requires x and y";
    test "first(empty)" "null" "empty expression result";
    test "nth(10; range(3))" "null" "out of bounds";
    test_location "single-line parse error location" "@@@" "null"
      [ "--> @@@"; "^" ];
    test_location "multiline: error on later line" "\n\n\n@@@" "null"
      [ "--> @@@"; "^" ];
    test_location "multiline: content before error" "fn a: .;\n\n\n@@@" "null"
      [ "--> @@@"; "^" ];
  ]
