let parse s () = s |> Json.from_string |> ignore

let check_parse name json_str expected () =
  Alcotest.(check Testable.jotason) name expected (Json.from_string json_str)

let from_string () =
  Alcotest.(check Testable.jotason)
    __LOC__ Fixtures.json_value
    (Json.from_string Fixtures.json_string)

let from_crlf_string () =
  Alcotest.(check Testable.jotason)
    __LOC__ Fixtures.json_value
    (Json.from_string Fixtures.json_string_crlf)

let from_string_fail_simple () =
  Alcotest.check_raises "Location of parsing failure is correct"
    (Json.Json_error "Line 1, bytes 0-5:\nInvalid token 'hello'")
    (parse "hello")

let from_string_fail_lines () =
  Alcotest.check_raises "Location of parsing failure has right line"
    (Json.Json_error "Line 3, bytes 0-1:\nExpected ':' but found '}'")
    (parse {|{
      hello
}|})

let from_string_fail_bytes () =
  Alcotest.check_raises "Location has right line and bytes"
    (Json.Json_error
       "Line 2, bytes 6-9:\nExpected string or identifier but found '3\n}'")
    (parse {|{
      3
}|})

let from_string_fail_unterminated () =
  Alcotest.check_raises "Runaway string in toplevel"
    (Json.Json_error "Line 1, bytes 12-13:\nUnexpected end of input")
    (parse {|"unterminated|})

let from_string_fail_nested_unterminated () =
  Alcotest.check_raises "Runaway string in structure"
    (Json.Json_error "Line 2, bytes 5-6:\nUnexpected end of input")
    (parse {|[1,
    "]|})

let from_string_fail_unterminated_structure () =
  Alcotest.check_raises "Array never closed"
    (Json.Json_error "Line 1, bytes 0-1:\nUnexpected end of input") (parse "[")

let from_string_fail_unstarted_structure () =
  Alcotest.check_raises "Array never opened"
    (Json.Json_error "Line 1, bytes 0-1:\nInvalid token ']'") (parse "]")

let from_string_fail_unstarted_object () =
  Alcotest.check_raises "Object never opened"
    (Json.Json_error "Line 1, bytes 0-1:\nInvalid token '}'") (parse "}")

let from_string_fail_escaped_char () =
  Alcotest.check_raises "Invalid escape sequence"
    (Json.Json_error "Line 1, bytes 2-4:\nInvalid escape sequence 'a\"'")
    (parse {|"\a"|})

let from_file () =
  let input_file = Filename.temp_file "test_jotason_from_file" ".json" in
  let oc = open_out input_file in
  output_string oc Fixtures.json_string;
  close_out oc;
  Alcotest.(check Testable.jotason)
    __LOC__ Fixtures.json_value
    (Json.from_file input_file);
  Sys.remove input_file

let unquoted_from_string () =
  Alcotest.(check Testable.jotason)
    __LOC__ Fixtures.unquoted_value
    (Json.from_string Fixtures.unquoted_json)

let parse_null () = check_parse "null" Fixtures.null_json Fixtures.null_value ()
let parse_true () = check_parse "true" Fixtures.true_json Fixtures.true_value ()

let parse_false () =
  check_parse "false" Fixtures.false_json Fixtures.false_value ()

let parse_zero () = check_parse "zero" Fixtures.zero_json Fixtures.zero_value ()

let parse_positive_int () =
  check_parse "positive int" Fixtures.positive_int_json
    Fixtures.positive_int_value ()

let parse_negative_int () =
  check_parse "negative int" Fixtures.negative_int_json
    Fixtures.negative_int_value ()

let parse_max_int () =
  check_parse "max safe int" Fixtures.max_int_json Fixtures.max_int_value ()

let parse_big_int () =
  check_parse "big int as intlit" Fixtures.big_int_json Fixtures.big_int_value
    ()

let parse_float () =
  check_parse "float" Fixtures.float_json Fixtures.float_value ()

let parse_negative_float () =
  check_parse "negative float" Fixtures.negative_float_json
    Fixtures.negative_float_value ()

let parse_exp_float () =
  check_parse "exponential float" Fixtures.exp_float_json
    Fixtures.exp_float_value ()

let parse_exp_negative () =
  check_parse "negative exponent" Fixtures.exp_negative_json
    Fixtures.exp_negative_value ()

let parse_exp_positive () =
  check_parse "positive exponent" Fixtures.exp_positive_json
    Fixtures.exp_positive_value ()

let parse_zero_point () =
  check_parse "0.0" Fixtures.zero_point_json Fixtures.zero_point_value ()

let parse_leading_zero_float () =
  check_parse "0.123" Fixtures.leading_zero_float_json
    Fixtures.leading_zero_float_value ()

let parse_empty_string () =
  check_parse "empty string" Fixtures.empty_string_json
    Fixtures.empty_string_value ()

let parse_simple_string () =
  check_parse "simple string" Fixtures.simple_string_json
    Fixtures.simple_string_value ()

let parse_escaped_quote () =
  check_parse "escaped quote" Fixtures.escaped_quote_json
    Fixtures.escaped_quote_value ()

let parse_escaped_backslash () =
  check_parse "escaped backslash" Fixtures.escaped_backslash_json
    Fixtures.escaped_backslash_value ()

let parse_escaped_slash () =
  check_parse "escaped slash" Fixtures.escaped_slash_json
    Fixtures.escaped_slash_value ()

let parse_escaped_backspace () =
  check_parse "escaped backspace" Fixtures.escaped_backspace_json
    Fixtures.escaped_backspace_value ()

let parse_escaped_formfeed () =
  check_parse "escaped formfeed" Fixtures.escaped_formfeed_json
    Fixtures.escaped_formfeed_value ()

let parse_escaped_newline () =
  check_parse "escaped newline" Fixtures.escaped_newline_json
    Fixtures.escaped_newline_value ()

let parse_escaped_carriage () =
  check_parse "escaped carriage return" Fixtures.escaped_carriage_json
    Fixtures.escaped_carriage_value ()

let parse_escaped_tab () =
  check_parse "escaped tab" Fixtures.escaped_tab_json Fixtures.escaped_tab_value
    ()

(* === Unicode tests === *)

let parse_unicode_basic () =
  check_parse "unicode basic" Fixtures.unicode_basic_json
    Fixtures.unicode_basic_value ()

let parse_unicode_euro () =
  check_parse "unicode euro" Fixtures.unicode_euro_json
    Fixtures.unicode_euro_value ()

let parse_unicode_snowman () =
  check_parse "unicode snowman" Fixtures.unicode_snowman_json
    Fixtures.unicode_snowman_value ()

let parse_unicode_surrogate () =
  check_parse "unicode surrogate pair" Fixtures.unicode_surrogate_json
    Fixtures.unicode_surrogate_value ()

let parse_utf8_direct () =
  check_parse "direct utf8" Fixtures.utf8_direct_json Fixtures.utf8_direct_value
    ()

let parse_utf8_emoji () =
  check_parse "direct utf8 emoji" Fixtures.utf8_emoji_json
    Fixtures.utf8_emoji_value ()

let parse_empty_array () =
  check_parse "empty array" Fixtures.empty_array_json Fixtures.empty_array_value
    ()

let parse_single_array () =
  check_parse "single element array" Fixtures.single_array_json
    Fixtures.single_array_value ()

let parse_mixed_array () =
  check_parse "mixed array" Fixtures.mixed_array_json Fixtures.mixed_array_value
    ()

let parse_nested_array () =
  check_parse "nested array" Fixtures.nested_array_json
    Fixtures.nested_array_value ()

let parse_deeply_nested () =
  check_parse "deeply nested" Fixtures.deeply_nested_json
    Fixtures.deeply_nested_value ()

(* === Object tests === *)

let parse_empty_object () =
  check_parse "empty object" Fixtures.empty_object_json
    Fixtures.empty_object_value ()

let parse_single_object () =
  check_parse "single key object" Fixtures.single_object_json
    Fixtures.single_object_value ()

let parse_multi_object () =
  check_parse "multi key object" Fixtures.multi_object_json
    Fixtures.multi_object_value ()

let parse_nested_object () =
  check_parse "nested object" Fixtures.nested_object_json
    Fixtures.nested_object_value ()

let parse_object_with_array () =
  check_parse "object with array" Fixtures.object_with_array_json
    Fixtures.object_with_array_value ()

let parse_array_of_objects () =
  check_parse "array of objects" Fixtures.array_of_objects_json
    Fixtures.array_of_objects_value ()

let parse_key_with_space () =
  check_parse "key with space" Fixtures.key_with_space_json
    Fixtures.key_with_space_value ()

let parse_key_with_unicode () =
  check_parse "key with unicode" Fixtures.key_with_unicode_json
    Fixtures.key_with_unicode_value ()

let parse_empty_key () =
  check_parse "empty key" Fixtures.empty_key_json Fixtures.empty_key_value ()

let parse_duplicate_keys () =
  check_parse "duplicate keys" Fixtures.duplicate_keys_json
    Fixtures.duplicate_keys_value ()

(* === Whitespace tests === *)

let parse_whitespace () =
  check_parse "extra whitespace" Fixtures.whitespace_json
    Fixtures.whitespace_value ()

let parse_newlines () =
  check_parse "newlines" Fixtures.newlines_json Fixtures.newlines_value ()

let parse_tabs () = check_parse "tabs" Fixtures.tabs_json Fixtures.tabs_value ()

let fail_trailing_comma_array () =
  Alcotest.check_raises "trailing comma in array"
    (Json.Json_error "Line 1, bytes 5-6:\nInvalid token ']'") (parse "[1,2,]")

let fail_trailing_comma_object () =
  Alcotest.check_raises "trailing comma in object"
    (Json.Json_error
       "Line 1, bytes 7-8:\nExpected string or identifier but found '}'")
    (parse {|{"a":1,}|})

let fail_leading_zeros () =
  Alcotest.check_raises "leading zeros"
    (Json.Json_error "Line 1, bytes 1-2:\nJunk after end of JSON value: '1'")
    (parse "01")

let fail_plus_sign () =
  Alcotest.check_raises "plus sign on number"
    (Json.Json_error "Line 1, bytes 0-2:\nInvalid token '+1'") (parse "+1")

let fail_single_quote_string () =
  Alcotest.check_raises "single quote string"
    (Json.Json_error "Line 1, bytes 0-7:\nInvalid token ''hello''")
    (parse "'hello'")

let fail_unquoted_string () =
  Alcotest.check_raises "unquoted string value"
    (Json.Json_error "Line 1, bytes 0-5:\nInvalid token 'hello'")
    (parse "hello")

let fail_missing_colon () =
  Alcotest.check_raises "missing colon"
    (Json.Json_error "Line 1, bytes 5-9:\nExpected ':' but found '\"b\"}'")
    (parse {|{"a" "b"}|})

let fail_missing_comma_array () =
  Alcotest.check_raises "missing comma in array"
    (Json.Json_error "Line 1, bytes 3-5:\nExpected ',' or ']' but found '2]'")
    (parse "[1 2]")

let fail_missing_comma_object () =
  Alcotest.check_raises "missing comma in object"
    (Json.Json_error
       "Line 1, bytes 7-13:\nExpected ',' or '}' but found '\"b\":2}'")
    (parse {|{"a":1 "b":2}|})

(* === Test list === *)

let single_json =
  [
    (* Original tests *)
    ("from_string", `Quick, from_string);
    ("from_crlf_string", `Quick, from_crlf_string);
    ("from_string_fail_simple", `Quick, from_string_fail_simple);
    ("from_string_fail_lines", `Quick, from_string_fail_lines);
    ("from_string_fail_bytes", `Quick, from_string_fail_bytes);
    ("from_string_fail_unterminated", `Quick, from_string_fail_unterminated);
    ( "from_string_fail_nested_unterminated",
      `Quick,
      from_string_fail_nested_unterminated );
    ( "from_string_fail_unterminated_structure",
      `Quick,
      from_string_fail_unterminated_structure );
    ( "from_string_fail_unstarted_structure",
      `Quick,
      from_string_fail_unstarted_structure );
    ( "from_string_fail_unstarted_object",
      `Quick,
      from_string_fail_unstarted_object );
    ("from_string_fail_escaped_char", `Quick, from_string_fail_escaped_char);
    ("from_file", `Quick, from_file);
    ("unquoted_from_string", `Quick, unquoted_from_string);
    (* Primitives *)
    ("parse_null", `Quick, parse_null);
    ("parse_true", `Quick, parse_true);
    ("parse_false", `Quick, parse_false);
    ("parse_zero", `Quick, parse_zero);
    ("parse_positive_int", `Quick, parse_positive_int);
    ("parse_negative_int", `Quick, parse_negative_int);
    ("parse_max_int", `Quick, parse_max_int);
    ("parse_big_int", `Quick, parse_big_int);
    ("parse_float", `Quick, parse_float);
    ("parse_negative_float", `Quick, parse_negative_float);
    ("parse_exp_float", `Quick, parse_exp_float);
    ("parse_exp_negative", `Quick, parse_exp_negative);
    ("parse_exp_positive", `Quick, parse_exp_positive);
    ("parse_zero_point", `Quick, parse_zero_point);
    ("parse_leading_zero_float", `Quick, parse_leading_zero_float);
    (* Strings *)
    ("parse_empty_string", `Quick, parse_empty_string);
    ("parse_simple_string", `Quick, parse_simple_string);
    ("parse_escaped_quote", `Quick, parse_escaped_quote);
    ("parse_escaped_backslash", `Quick, parse_escaped_backslash);
    ("parse_escaped_slash", `Quick, parse_escaped_slash);
    ("parse_escaped_backspace", `Quick, parse_escaped_backspace);
    ("parse_escaped_formfeed", `Quick, parse_escaped_formfeed);
    ("parse_escaped_newline", `Quick, parse_escaped_newline);
    ("parse_escaped_carriage", `Quick, parse_escaped_carriage);
    ("parse_escaped_tab", `Quick, parse_escaped_tab);
    (* Unicode *)
    ("parse_unicode_basic", `Quick, parse_unicode_basic);
    ("parse_unicode_euro", `Quick, parse_unicode_euro);
    ("parse_unicode_snowman", `Quick, parse_unicode_snowman);
    ("parse_unicode_surrogate", `Quick, parse_unicode_surrogate);
    ("parse_utf8_direct", `Quick, parse_utf8_direct);
    ("parse_utf8_emoji", `Quick, parse_utf8_emoji);
    (* Arrays *)
    ("parse_empty_array", `Quick, parse_empty_array);
    ("parse_single_array", `Quick, parse_single_array);
    ("parse_mixed_array", `Quick, parse_mixed_array);
    ("parse_nested_array", `Quick, parse_nested_array);
    ("parse_deeply_nested", `Quick, parse_deeply_nested);
    (* Objects *)
    ("parse_empty_object", `Quick, parse_empty_object);
    ("parse_single_object", `Quick, parse_single_object);
    ("parse_multi_object", `Quick, parse_multi_object);
    ("parse_nested_object", `Quick, parse_nested_object);
    ("parse_object_with_array", `Quick, parse_object_with_array);
    ("parse_array_of_objects", `Quick, parse_array_of_objects);
    ("parse_key_with_space", `Quick, parse_key_with_space);
    ("parse_key_with_unicode", `Quick, parse_key_with_unicode);
    ("parse_empty_key", `Quick, parse_empty_key);
    ("parse_duplicate_keys", `Quick, parse_duplicate_keys);
    (* Whitespace *)
    ("parse_whitespace", `Quick, parse_whitespace);
    ("parse_newlines", `Quick, parse_newlines);
    ("parse_tabs", `Quick, parse_tabs);
    (* Error cases *)
    ("fail_trailing_comma_array", `Quick, fail_trailing_comma_array);
    ("fail_trailing_comma_object", `Quick, fail_trailing_comma_object);
    ("fail_leading_zeros", `Quick, fail_leading_zeros);
    ("fail_plus_sign", `Quick, fail_plus_sign);
    ("fail_single_quote_string", `Quick, fail_single_quote_string);
    ("fail_unquoted_string", `Quick, fail_unquoted_string);
    ("fail_missing_colon", `Quick, fail_missing_colon);
    ("fail_missing_comma_array", `Quick, fail_missing_comma_array);
    ("fail_missing_comma_object", `Quick, fail_missing_comma_object);
  ]
