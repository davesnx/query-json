let decimal s : Json.t = `Decimal (Json.Decimal.of_lexeme_exn s)

let json_value : Json.t =
  `Assoc
    [
      ("null", `Null);
      ("bool", `Bool true);
      ("int", `Int 0);
      ("big_int", `Big_int (Z.of_string "10000000000000000000"));
      ("float", decimal "0.0");
      ("string", `String "string");
      ("list", `List [ `Int 0; `Int 1; `Int 2 ]);
      ("assoc", `Assoc [ ("value", `Int 42) ]);
    ]

let crlf = "\r\n"

let snippets =
  [
    "{";
    {|"null":null,|};
    {|"bool":true,|};
    {|"int":0,|};
    {|"big_int":10000000000000000000,|};
    {|"float":0.0,|};
    {|"string":"string",|};
    {|"list":[0,1,2],|};
    {|"assoc":{"value":42}|};
    "}";
  ]

let json_string = String.concat "" snippets
let json_string_crlf = String.concat crlf snippets
let unquoted_json = {|{foo: null}|}
let unquoted_value : Json.t = `Assoc [ ("foo", `Null) ]
let json_string_newline = json_string ^ "\n"
let null_json = "null"
let null_value : Json.t = `Null
let true_json = "true"
let true_value : Json.t = `Bool true
let false_json = "false"
let false_value : Json.t = `Bool false
let zero_json = "0"
let zero_value : Json.t = `Int 0
let positive_int_json = "42"
let positive_int_value : Json.t = `Int 42
let negative_int_json = "-123"
let negative_int_value : Json.t = `Int (-123)
let max_int_json = "9007199254740991"
let max_int_value : Json.t = `Int 9007199254740991
let big_int_json = "99999999999999999999999999999"

let big_int_value : Json.t =
  `Big_int (Z.of_string "99999999999999999999999999999")

let float_json = "3.14159"
let float_value : Json.t = decimal "3.14159"
let negative_float_json = "-2.718"
let negative_float_value : Json.t = decimal "-2.718"
let exp_float_json = "1.23e10"
let exp_float_value : Json.t = decimal "1.23e10"
let exp_negative_json = "1.5e-5"
let exp_negative_value : Json.t = decimal "1.5e-5"
let exp_positive_json = "2.5E+3"
let exp_positive_value : Json.t = decimal "2.5E+3"
let zero_point_json = "0.0"
let zero_point_value : Json.t = decimal "0.0"
let empty_string_json = {|""|}
let empty_string_value : Json.t = `String ""
let simple_string_json = {|"hello world"|}
let simple_string_value : Json.t = `String "hello world"
let escaped_quote_json = {|"say \"hello\""|}
let escaped_quote_value : Json.t = `String {|say "hello"|}
let escaped_backslash_json = {|"path\\to\\file"|}
let escaped_backslash_value : Json.t = `String {|path\to\file|}
let escaped_slash_json = {|"a\/b"|}
let escaped_slash_value : Json.t = `String "a/b"
let escaped_backspace_json = {|"a\bb"|}
let escaped_backspace_value : Json.t = `String "a\bb"
let escaped_formfeed_json = {|"a\fb"|}
let escaped_formfeed_value : Json.t = `String "a\012b"
let escaped_newline_json = {|"line1\nline2"|}
let escaped_newline_value : Json.t = `String "line1\nline2"
let escaped_carriage_json = {|"a\rb"|}
let escaped_carriage_value : Json.t = `String "a\rb"
let escaped_tab_json = {|"a\tb"|}
let escaped_tab_value : Json.t = `String "a\tb"
let unicode_basic_json = {|"\u0041"|}
let unicode_basic_value : Json.t = `String "A"
let unicode_euro_json = {|"\u20AC"|}
let unicode_euro_value : Json.t = `String "\226\130\172"
let unicode_snowman_json = {|"\u2603"|}
let unicode_snowman_value : Json.t = `String "\226\152\131"
let unicode_surrogate_json = {|"\uD83D\uDE00"|}
let unicode_surrogate_value : Json.t = `String "\240\159\152\128"
let utf8_direct_json = {|"日本語"|}
let utf8_direct_value : Json.t = `String "日本語"
let utf8_emoji_json = "\"🎉\""
let utf8_emoji_value : Json.t = `String "🎉"
let empty_array_json = "[]"
let empty_array_value : Json.t = `List []
let single_array_json = "[1]"
let single_array_value : Json.t = `List [ `Int 1 ]
let mixed_array_json = {|[1, "two", true, null, 3.14]|}

let mixed_array_value : Json.t =
  `List [ `Int 1; `String "two"; `Bool true; `Null; decimal "3.14" ]

let nested_array_json = "[[1, 2], [3, 4]]"

let nested_array_value : Json.t =
  `List [ `List [ `Int 1; `Int 2 ]; `List [ `Int 3; `Int 4 ] ]

let deeply_nested_json = "[[[1]]]"
let deeply_nested_value : Json.t = `List [ `List [ `List [ `Int 1 ] ] ]
let empty_object_json = "{}"
let empty_object_value : Json.t = `Assoc []
let single_object_json = {|{"key": "value"}|}
let single_object_value : Json.t = `Assoc [ ("key", `String "value") ]
let multi_object_json = {|{"a": 1, "b": 2, "c": 3}|}

let multi_object_value : Json.t =
  `Assoc [ ("a", `Int 1); ("b", `Int 2); ("c", `Int 3) ]

let nested_object_json = {|{"outer": {"inner": 42}}|}

let nested_object_value : Json.t =
  `Assoc [ ("outer", `Assoc [ ("inner", `Int 42) ]) ]

let object_with_array_json = {|{"items": [1, 2, 3]}|}

let object_with_array_value : Json.t =
  `Assoc [ ("items", `List [ `Int 1; `Int 2; `Int 3 ]) ]

let array_of_objects_json = {|[{"id": 1}, {"id": 2}]|}

let array_of_objects_value : Json.t =
  `List [ `Assoc [ ("id", `Int 1) ]; `Assoc [ ("id", `Int 2) ] ]

let key_with_space_json = {|{"key with space": 1}|}
let key_with_space_value : Json.t = `Assoc [ ("key with space", `Int 1) ]
let key_with_unicode_json = {|{"日本語キー": "value"}|}

let key_with_unicode_value : Json.t = `Assoc [ ("日本語キー", `String "value") ]

let empty_key_json = {|{"": "empty key"}|}
let empty_key_value : Json.t = `Assoc [ ("", `String "empty key") ]
let whitespace_json = "  {  \"a\"  :  1  ,  \"b\"  :  2  }  "
let whitespace_value : Json.t = `Assoc [ ("a", `Int 1); ("b", `Int 2) ]
let newlines_json = "{\n  \"a\": 1,\n  \"b\": 2\n}"
let newlines_value : Json.t = `Assoc [ ("a", `Int 1); ("b", `Int 2) ]
let tabs_json = "{\t\"a\":\t1}"
let tabs_value : Json.t = `Assoc [ ("a", `Int 1) ]
let duplicate_keys_json = {|{"a": 1, "a": 2}|}
let duplicate_keys_value : Json.t = `Assoc [ ("a", `Int 1); ("a", `Int 2) ]
let leading_zero_float_json = "0.123"
let leading_zero_float_value : Json.t = decimal "0.123"
