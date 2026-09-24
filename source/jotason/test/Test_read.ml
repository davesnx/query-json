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
    (Json.Json_error "Line 1, bytes 0-5:\nInvalid token 'hello'") (parse "hello")

let from_string_fail_lines () =
  Alcotest.check_raises "Location of parsing failure has right line"
    (Json.Json_error "Line 3, bytes 0-1:\nExpected ':' but found '}'")
    (parse {|{
      hello
}|})

let from_string_fail_bytes () =
  Alcotest.check_raises "Location has right line and bytes"
    (Json.Json_error
       "Line 2, bytes 6-9:\nExpected string or identifier but found '3\n}'"
    )
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
       "Line 1, bytes 7-8:\nExpected string or identifier but found '}'"
    )
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
    (Json.Json_error "Line 1, bytes 0-5:\nInvalid token 'hello'") (parse "hello")

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
       "Line 1, bytes 7-13:\nExpected ',' or '}' but found '\"b\":2}'"
    )
    (parse {|{"a":1 "b":2}|})

let selection_testable =
  let pp fmt = function
    | Json.Input.Whole value ->
        Format.fprintf fmt "Whole (%a)" Json.pp value
    | Json.Input.Selected value ->
        Format.fprintf fmt "Selected (%a)" Json.pp value
  in
  Alcotest.testable pp (fun a b -> Stdlib.compare a b = 0)

let check_input name expected actual =
  Alcotest.(check (result selection_testable string)) name expected actual

let select_full select value =
  match (select, value) with
  | Some key, `Assoc fields -> (
      match List.assoc_opt key fields with
      | Some value ->
          Json.Input.Selected value
      | None ->
          Json.Input.Whole value
    )
  | _ ->
      Json.Input.Whole value

let selection_cases =
  [
    ("first", "wanted", {|{wanted:{z:[1,{x:2,x:3}],a:0},after:[4,5]}|});
    ("middle", "wanted", {|{before:[1,2],wanted:[{x:3},4],after:{y:5}}|});
    ("last", "wanted", {|{before:{a:1},other:[2],wanted:"last"}|});
    ("missing", "wanted", {|{z:1,a:{b:2,b:3},z:[4],a:5}|});
    ("empty object", "wanted", "{}");
    ("duplicate", "wanted", {|{wanted:1,other:2,wanted:[3,4]}|});
    ("null first duplicate", "wanted", {|{wanted:null,wanted:false}|});
    ("nested member only", "wanted", {|{other:{wanted:1}}|});
    ("escaped key", "wanted", {|{"wa\u006eted":true,wanted:false}|});
    ("empty key", "", {|{before:1,"":[],after:2}|});
    ("wrong root array", "wanted", {|[{wanted:1},{a:2,a:3}]|});
    ("wrong root string", "wanted", {|"wanted"|});
    ("wrong root integer", "wanted", "123");
    ("wrong root decimal", "wanted", "-1.20e-3");
    ("wrong root null", "wanted", "null");
    ("wrong root bool", "wanted", "false");
    ("wrong root NaN", "wanted", "NaN");
    ("wrong root infinity", "wanted", "Infinity");
    ("raw string whitespace", "wanted", "{wanted:1,after:\"line\n\ttwo\"}");
    ( "comments",
      "wanted",
      "// start\n/* root */ {before:1, /* member */ wanted:[2], // tail\n"
      ^ "after:{a:/* value */3}} /* end */ // eof"
    );
    ( "discarded scalars",
      "wanted",
      {|{wanted:1,after:[true,false,null,NaN,Infinity,-Infinity,0,-0,|}
      ^ {|4611686018427387904,-4611686018427387905,|}
      ^ {|9223372036854775808,-9223372036854775809,1.230e+4,-1.20e-3,|}
      ^ {|"\"\\\/\b\f\n\r\t\u20AC\uD834\uDD1E","\uDC00"]}|}
    );
  ]

let input_selection () =
  List.iter
    (fun (name, key, text) ->
      let value = Json.from_string text in
      List.iter
        (fun select ->
          check_input name
            (Ok (select_full select value))
            (Json.Input.read ~select (Json.Input.String text))
        )
        [ None; Some key ]
    )
    selection_cases

let input_value () =
  let value = `Assoc [ ("wanted", `Int 1); ("wanted", `Int 2) ] in
  List.iter
    (fun select ->
      match Json.Input.read ~select (Json.Input.Value value) with
      | Ok (Json.Input.Whole actual) ->
          Alcotest.(check bool)
            "same value without parsing" true (actual == value)
      | actual ->
          check_input "Value returns Whole" (Ok (Json.Input.Whole value)) actual
    )
    [ None; Some "wanted"; Some "missing" ]

let discarded_errors =
  List.map
    (fun (name, tail) ->
      (name, {|{before:[1],wanted:{x:[true,null]},after:|} ^ tail)
    )
    [
      ("invalid escape", {|"\q"}|});
      ("invalid unicode digits", {|"\u00xz"}|});
      ("unterminated string", {|"unterminated|});
      ("unterminated escape", {|"escape\|});
      ("missing low surrogate", {|"\uD800"}|});
      ("invalid low surrogate", {|"\uD800\u0041"}|});
      ("high low surrogate", {|"\uD800\uD800"}|});
      ("truncated surrogate", {|"\uD800|});
      ("invalid nested key escape", {|{"\q":1}}|});
      ("invalid nested key surrogate", {|{"\uD800":1}}|});
      ("invalid later root key", {|1,"\q":2}|});
      ("invalid later root key surrogate", {|1,"\uD800":2}|});
      ("exponent overflow", "1e999999999999999999999999999999}");
      ("negative exponent overflow", "1e-999999999999999999999999999999}");
      ("leading zero", "01}");
      ("missing exponent", "1e+}");
      ("missing fractional digits", "1.}");
      ("plus sign", "+1}");
      ("invalid token", "undefined}");
      ("missing nested array comma", "[1 2]}");
      ("missing nested object comma", "{a:1 b:2}}");
      ("missing nested colon", "{a 1}}");
      ("array trailing comma", "[1,]}");
      ("object trailing comma", "{a:1,}}");
      ("root trailing comma", "1,}");
      ("truncated array", "[1");
      ("truncated object", "{a:1");
      ("truncated root", "1");
      ("unterminated comment", "/* unfinished");
      ("nested comment", "[1,/* unfinished");
      ("line comment hides closing braces", "1 // } ");
    ]
  @ [
      ("trailing junk", "{wanted:1} garbage");
      ("second document", "{wanted:1} {wanted:2}");
      ("trailing unterminated comment", "{wanted:1} /* unfinished");
      ("leading unterminated comment", "/* unfinished");
      ("empty input", "");
      ("blank", " \n\t");
      ("comments only", "/* comment */ // eof");
      ("bad preceding field", {|{before:"\q",wanted:1}|});
      ("bad selected value", {|{wanted:["\uD800"]}|});
      ("bad duplicate match", {|{wanted:1,wanted:"\q"}|});
      ("bad missing member", {|{other:"\q"}|});
      ("bad wrong root", {|[{wanted:1},"\q"]|});
    ]

let check_input_error name full actual =
  match full with
  | Error message ->
      check_input name (Error message) actual
  | Ok _ ->
      Alcotest.failf "%s: full parser unexpectedly accepted malformed input"
        name

let input_selection_errors () =
  List.iter
    (fun (name, text) ->
      List.iter
        (fun select ->
          check_input_error name (Json.parse_string text)
            (Json.Input.read ~select (Json.Input.String text))
        )
        [ None; Some "wanted"; Some "missing" ]
    )
    discarded_errors

let with_input_file text f =
  let file = Filename.temp_file "jotason_input" ".json" in
  Fun.protect
    ~finally:(fun () -> Sys.remove file)
    (fun () ->
      let channel = open_out_bin file in
      Fun.protect
        ~finally:(fun () -> close_out_noerr channel)
        (fun () -> output_string channel text);
      f file
    )

let with_input_channel file f =
  let channel = open_in_bin file in
  Fun.protect ~finally:(fun () -> close_in_noerr channel) (fun () -> f channel)

let input_sources () =
  List.iter
    (fun (name, key, text) ->
      with_input_file text (fun file ->
          List.iter
            (fun select ->
              check_input (name ^ " file")
                (Result.map (select_full select) (Json.parse_file file))
                (Json.Input.read ~select (Json.Input.File file));
              with_input_channel file (fun channel ->
                  let expected =
                    Result.map (select_full select) (Json.parse_channel channel)
                  in
                  seek_in channel 0;
                  check_input (name ^ " channel") expected
                    (Json.Input.read ~select (Json.Input.Channel channel));
                  seek_in channel 0;
                  Alcotest.(check char)
                    "borrowed channel remains readable" text.[0]
                    (input_char channel)
              )
            )
            [ None; Some key ]
      )
    )
    selection_cases;
  List.iter
    (fun (name, text) ->
      with_input_file text (fun file ->
          List.iter
            (fun select ->
              check_input_error (name ^ " file") (Json.parse_file file)
                (Json.Input.read ~select (Json.Input.File file));
              with_input_channel file (fun channel ->
                  let full = Json.parse_channel channel in
                  seek_in channel 0;
                  check_input_error (name ^ " channel") full
                    (Json.Input.read ~select (Json.Input.Channel channel));
                  seek_in channel 0;
                  if text <> "" then
                    Alcotest.(check char)
                      "channel remains readable after error" text.[0]
                      (input_char channel)
              )
            )
            [ None; Some "wanted" ]
      )
    )
    discarded_errors;
  with_input_file "{wanted:1}" (fun file ->
      with_input_channel file (fun channel ->
          close_in channel;
          List.iter
            (fun select ->
              check_input_error "closed channel wrapper"
                (Json.parse_channel channel)
                (Json.Input.read ~select (Json.Input.Channel channel))
            )
            [ None; Some "wanted" ]
      )
  )

let input_channel_refill () =
  let padding = String.make 65537 'x' in
  let text =
    {|{before:["|} ^ padding ^ {|"],wanted:{x:"|} ^ padding
    ^ {|\uD834\uDD1E",x:2},after:[{"|} ^ padding ^ {|":[]},"|} ^ padding
    ^ {|"]}|}
  in
  with_input_file text (fun file ->
      List.iter
        (fun select ->
          with_input_channel file (fun channel ->
              let expected =
                Result.map (select_full select) (Json.parse_channel channel)
              in
              seek_in channel 0;
              check_input "refilled channel" expected
                (Json.Input.read ~select (Json.Input.Channel channel));
              Alcotest.(check int)
                "validated through EOF" (String.length text) (pos_in channel);
              seek_in channel 0
          )
        )
        [ None; Some "wanted"; Some "missing" ]
  );
  List.iter
    (fun (name, tail) ->
      let text = {|{wanted:1,after:["|} ^ padding ^ tail in
      with_input_file text (fun file ->
          with_input_channel file (fun channel ->
              let full = Json.parse_channel channel in
              seek_in channel 0;
              check_input_error name full
                (Json.Input.read ~select:(Some "wanted")
                   (Json.Input.Channel channel)
                )
          )
      )
    )
    [
      ("refilled escape", {|\q"]}|});
      ("refilled surrogate", {|\uD800\u0041"]}|});
      ("refilled number", {|",1e999999999999999999999999999999]}|});
      ("refilled trailing junk", {|"]} junk|});
    ]

let input_file_closure () =
  List.iter
    (fun text ->
      with_input_file text (fun file ->
          let descriptors () =
            if Sys.file_exists "/proc/self/fd" then
              Some (Array.length (Sys.readdir "/proc/self/fd"))
            else
              None
          in
          let before = descriptors () in
          for _ = 1 to 32 do
            List.iter
              (fun select ->
                check_input "repeated file read"
                  (Result.map (select_full select) (Json.parse_file file))
                  (Json.Input.read ~select (Json.Input.File file))
              )
              [ None; Some "wanted"; Some "missing" ]
          done;
          Alcotest.(check (option int))
            "no leaked file descriptors" before (descriptors ())
      )
    )
    [
      "{wanted:1,after:[2,3]}";
      {|{wanted:1,after:"\q"}|};
      "{wanted:1,after:1e999999999999999999999999999999}";
    ];
  with_input_file "" (fun file ->
      let missing = file ^ ".missing" in
      List.iter
        (fun select ->
          check_input_error "missing file wrapper" (Json.parse_file missing)
            (Json.Input.read ~select (Json.Input.File missing))
        )
        [ None; Some "wanted" ]
  )

let input_discarded_containers () =
  let text =
    "{wanted:null,after:["
    ^ String.concat "," (List.init 10000 (fun _ -> "[[],{}]"))
    ^ "]}"
  in
  let allocated select =
    let before = Gc.allocated_bytes () in
    let result = Json.Input.read ~select (Json.Input.String text) in
    let bytes = Gc.allocated_bytes () -. before in
    (result, bytes)
  in
  let full, full_bytes = allocated None in
  let selected, selected_bytes = allocated (Some "wanted") in
  check_input "complete selected value" (Ok (Json.Input.Selected `Null))
    selected;
  check_input "complete full value"
    (Result.map (fun value -> Json.Input.Whole value) (Json.parse_string text))
    full;
  Alcotest.(check bool)
    "discarding containers uses less than half the full parser allocation" true
    (selected_bytes < full_bytes /. 2.)

let items_testable =
  let pp fmt = function
    | Json.Input.Folded values ->
        Format.fprintf fmt "Folded (%a)" Json.pp (`List values)
    | Json.Input.Materialized selection ->
        (Alcotest.pp selection_testable) fmt selection
  in
  Alcotest.testable pp (fun a b -> Stdlib.compare a b = 0)

let check_items name expected actual =
  Alcotest.(check (result items_testable string)) name expected actual

let item_testable = Alcotest.testable Json.pp (fun a b -> Stdlib.compare a b = 0)

let items_init = [ `String "initial state" ]

let expected_items at value =
  let open Json.Input in
  let selection =
    select_full (match at with Root -> None | Member key -> Some key) value
  in
  match (at, selection) with
  | Root, Whole (`List values) | Member _, Selected (`List values) ->
      Folded (List.rev_append values items_init)
  | Root, Whole (`Assoc fields) | Member _, Selected (`Assoc fields) ->
      Folded (List.rev_append (List.map snd fields) items_init)
  | _ ->
      Materialized selection

let items_cases =
  let open Json.Input in
  List.concat_map
    (fun (name, key, text) ->
      [ (name ^ " root", Root, text); (name ^ " member", Member key, text) ]
    )
    selection_cases
  @ [
      ("root array", Root, {|[1,{a:[2],a:3},[4],null]|});
      ("root empty array", Root, "[]");
      ("root empty object", Root, "{}");
      ("root duplicate values", Root, "{a:1,a:2,b:[3],a:4}");
      ("member first array", Member "x", "{x:[1,{a:2}],after:3}");
      ("member middle object", Member "x", "{a:0,x:{k:1,k:2},b:3}");
      ("member last array", Member "x", "{a:0,x:[1,2]}");
      ("member last object", Member "x", "{a:0,x:{k:1,k:2}}");
      ("member empty array", Member "x", "{a:0,x:[],b:3}");
      ("member empty object", Member "x", "{a:0,x:{},b:3}");
      ("member duplicate array", Member "x", "{x:[1,2],x:[3]}");
      ("member duplicate object", Member "x", "{x:{k:1,k:2},x:[3]}");
      ("member empty first duplicate", Member "x", "{x:[],x:[3]}");
      ("member scalar first duplicate", Member "x", "{x:0,x:[3]}");
      ("member escaped key", Member "x", {|{"\u0078":[1,2],x:[3]}|});
      ("member empty key", Member "", {|{a:0,"":{k:1,k:2},b:3}|});
      ( "member comments",
        Member "x",
        "/*root*/{a:0,/*key*/x/*colon*/:/*array*/[1/*comma*/,//line\n"
        ^ "{k:2}/*end*/]/*tail*/,b:3}//eof"
      );
      ("root scalar", Root, "1");
      ("root string", Root, {|"text"|});
    ]

let check_items_source name at text source =
  let expected = expected_items at (Json.from_string text) in
  let seen = ref [] in
  let actual =
    Json.Input.fold_items ~at ~init:items_init
      ~f:(fun state value ->
        seen := value :: !seen;
        Json.Input.Continue (value :: state)
      )
      source
  in
  check_items name (Ok expected) actual;
  let expected_seen =
    match expected with
    | Json.Input.Folded values ->
        List.filteri (fun i _ -> i < List.length values - 1) values
    | Json.Input.Materialized _ ->
        []
  in
  Alcotest.(check (list item_testable))
    (name ^ " callbacks") expected_seen !seen

let input_items () =
  List.iter
    (fun (name, at, text) ->
      check_items_source name at text (Json.Input.String text);
      check_items_source (name ^ " value") at text
        (Json.Input.Value (Json.from_string text))
    )
    items_cases;
  let value = `String "unparsed\255\000" in
  let check_same at value =
    match
      Json.Input.fold_items ~at ~init:()
        ~f:(fun _ _ -> Alcotest.fail "unexpected callback")
        (Json.Input.Value value)
    with
    | Ok (Json.Input.Materialized (Json.Input.Whole actual)) ->
        Alcotest.(check bool) "same supplied value" true (value == actual)
    | _ ->
        Alcotest.fail "expected the whole supplied value"
  in
  check_same Json.Input.Root value;
  check_same (Json.Input.Member "missing") (`Assoc [ ("x", value) ]);
  check_items "Value children do not parse" (Ok (Json.Input.Folded [ value ]))
    (Json.Input.fold_items ~at:Json.Input.Root ~init:[]
       ~f:(fun state item ->
         Alcotest.(check bool) "same supplied child" true (item == value);
         Json.Input.Continue (item :: state)
       )
       (Json.Input.Value (`List [ value ]))
    )

let items_errors =
  let open Json.Input in
  [
    ("leading zero boundary", Root, "[01]", []);
    ("exponent boundary", Root, "[1e+]", []);
    ("array boundary", Root, "[1 2]", []);
    ("object boundary", Root, "{a:1 b:2}", []);
    ("member array boundary", Member "x", "{x:[1 2]}", []);
    ("member object boundary", Member "x", "{x:{a:1 b:2}}", []);
    ("incomplete child", Root, "[{a:[1,]},{a:2}]", []);
    ("late array boundary", Root, "[0,1 2]", [ `Int 0 ]);
    ("late object boundary", Root, "{a:0,b:1 c:2}", [ `Int 0 ]);
    ("array trailing comma", Root, "[1,]", [ `Int 1 ]);
    ("object trailing comma", Root, "{a:1,}", [ `Int 1 ]);
    ("truncated child", Root, "[1,{", [ `Int 1 ]);
    ("missing boundary", Root, "[1", []);
    ("root junk", Root, "[1] junk", [ `Int 1 ]);
    ("root second document", Root, "{a:1} []", [ `Int 1 ]);
    ("root tail comment", Root, "[1] /*", [ `Int 1 ]);
    ("selected tail", Member "x", "{x:[1],tail:[2,]}", [ `Int 1 ]);
    ("selected parent boundary", Member "x", "{x:[1] y:2}", [ `Int 1 ]);
    ("selected missing parent end", Member "x", "{x:[1]", [ `Int 1 ]);
    ("invalid later duplicate", Member "x", "{x:[1],x:[01]}", [ `Int 1 ]);
    ("empty then invalid duplicate", Member "x", "{x:[],x:[01]}", []);
    ("scalar then invalid duplicate", Member "x", "{x:0,x:[01]}", []);
  ]

let check_items_error name full actual =
  match full with
  | Error message ->
      check_items name (Error message) actual
  | Ok _ ->
      Alcotest.failf "%s: full parser accepted malformed input" name

let input_items_errors () =
  List.iter
    (fun (name, at, text, expected_seen) ->
      let seen = ref [] in
      let actual =
        Json.Input.fold_items ~at ~init:items_init
          ~f:(fun state value ->
            seen := value :: !seen;
            Json.Input.Continue (value :: state)
          )
          (Json.Input.String text)
      in
      check_items_error name (Json.parse_string text) actual;
      Alcotest.(check (list Testable.jotason))
        (name ^ " visible prefix") expected_seen (List.rev !seen)
    )
    items_errors;
  List.iter
    (fun (name, text) ->
      List.iter
        (fun at ->
          check_items_error name (Json.parse_string text)
            (Json.Input.fold_items ~at ~init:items_init
               ~f:(fun state value -> Json.Input.Continue (value :: state))
               (Json.Input.String text)
            )
        )
        [
          Json.Input.Root;
          Json.Input.Member "wanted";
          Json.Input.Member "missing";
        ]
    )
    discarded_errors

let validate_items_cases =
  let open Json.Input in
  [
    (Root, "[1,2,{a:[3]}]");
    (Root, "{a:1,a:2,b:[3]}");
    (Root, "[1]");
    (Root, "{a:1}");
    (Member "x", "{x:[1,2],x:[3],tail:{a:[4]}}");
    (Member "x", "{x:{a:1,b:2},tail:3}");
    (Root, "[1,01]");
    (Root, "{a:1,b:1e+}");
    (Root, "[1,]");
    (Root, "{a:1,}");
    (Root, "[1,2");
    (Root, "[1] junk");
    (Root, "[1] /*");
    (Member "x", "{x:[1,2],x:[01]}");
    (Member "x", "{x:{a:1,b:2},tail:[3,]}");
    (Member "x", "{x:[1] y:2}");
    (Member "x", "{x:[1]}");
    (Member "x", "{x:[1]} junk");
  ]

let check_validate_items name at full source =
  let calls = ref 0 in
  let actual =
    Json.Input.fold_items ~at ~init:items_init
      ~f:(fun state value ->
        incr calls;
        Json.Input.Validate_rest (value :: state)
      )
      source
  in
  Alcotest.(check int) (name ^ " stopped callbacks") 1 !calls;
  match full with
  | Ok _ ->
      check_items name (Ok (Json.Input.Folded (`Int 1 :: items_init))) actual
  | Error _ ->
      check_items_error name full actual

let input_items_validate_rest () =
  List.iter
    (fun (at, text) ->
      let full = Json.parse_string text in
      check_validate_items text at full (Json.Input.String text);
      match full with
      | Ok value ->
          check_validate_items (text ^ " value") at full (Json.Input.Value value)
      | Error _ ->
          ()
    )
    validate_items_cases

let input_items_sources () =
  List.iter
    (fun (name, at, text) ->
      with_input_file text (fun file ->
          check_items_source (name ^ " file") at text (Json.Input.File file);
          with_input_channel file (fun channel ->
              check_items_source (name ^ " channel") at text
                (Json.Input.Channel channel);
              Alcotest.(check int)
                "validated EOF" (String.length text) (pos_in channel);
              seek_in channel 0;
              Alcotest.(check char)
                "borrowed channel open" text.[0] (input_char channel)
          )
      )
    )
    items_cases;
  List.iter
    (fun (name, at, text, _) ->
      with_input_file text (fun file ->
          let f state value = Json.Input.Continue (value :: state) in
          check_items_error (name ^ " file") (Json.parse_file file)
            (Json.Input.fold_items ~at ~init:items_init ~f (Json.Input.File file)
            );
          with_input_channel file (fun channel ->
              let expected = Json.parse_channel channel in
              seek_in channel 0;
              check_items_error (name ^ " channel") expected
                (Json.Input.fold_items ~at ~init:items_init ~f
                   (Json.Input.Channel channel)
                );
              seek_in channel 0
          )
      )
    )
    items_errors;
  List.iter
    (fun (at, text) ->
      with_input_file text (fun file ->
          check_validate_items (text ^ " file") at (Json.parse_file file)
            (Json.Input.File file);
          with_input_channel file (fun channel ->
              let full = Json.parse_channel channel in
              seek_in channel 0;
              check_validate_items (text ^ " channel") at full
                (Json.Input.Channel channel);
              seek_in channel 0
          )
      )
    )
    validate_items_cases;
  with_input_file "" (fun file ->
      let f _ _ = Alcotest.fail "unexpected callback" in
      let missing = file ^ ".missing" in
      check_items_error "missing file" (Json.parse_file missing)
        (Json.Input.fold_items ~at:Json.Input.Root ~init:[] ~f
           (Json.Input.File missing)
        );
      with_input_channel file (fun channel ->
          close_in channel;
          check_items_error "closed channel"
            (Json.parse_channel channel)
            (Json.Input.fold_items ~at:Json.Input.Root ~init:[] ~f
               (Json.Input.Channel channel)
            )
      )
  )

let[@inline never] raise_items_callback error = raise error

let check_items_exception at source error =
  let original_trace = ref "" in
  match
    Json.Input.fold_items ~at ~init:()
      ~f:(fun _ _ ->
        try raise_items_callback error
        with caught ->
          let trace = Printexc.get_raw_backtrace () in
          original_trace := Printexc.raw_backtrace_to_string trace;
          Printexc.raise_with_backtrace caught trace
      )
      source
  with
  | _ ->
      Alcotest.fail "callback exception did not escape"
  | exception caught ->
      let trace =
        Printexc.get_raw_backtrace () |> Printexc.raw_backtrace_to_string
      in
      Alcotest.(check bool) "callback exception identity" true (caught == error);
      Alcotest.(check bool)
        "callback trace recorded" true (!original_trace <> "");
      Alcotest.(check bool)
        "callback trace retained" true
        (String.starts_with ~prefix:!original_trace trace)

let input_items_exceptions () =
  let recording = Printexc.backtrace_status () in
  Fun.protect
    ~finally:(fun () -> Printexc.record_backtrace recording)
    (fun () ->
      Printexc.record_backtrace true;
      List.iter
        (fun error ->
          List.iter
            (fun (at, text) ->
              check_items_exception at (Json.Input.String text) error;
              check_items_exception at
                (Json.Input.Value (Json.from_string text))
                error;
              with_input_file text (fun file ->
                  check_items_exception at (Json.Input.File file) error;
                  with_input_channel file (fun channel ->
                      check_items_exception at (Json.Input.Channel channel)
                        error;
                      seek_in channel 0;
                      Alcotest.(check char)
                        "channel open after exception" text.[0]
                        (input_char channel)
                  )
              )
            )
            [
              (Json.Input.Root, "[1,2]");
              (Json.Input.Root, "[1]");
              (Json.Input.Root, "{a:1}");
              (Json.Input.Member "x", "{x:[1]}");
              (Json.Input.Member "x", "{x:{a:1,b:2},tail:3}");
            ];
          check_items_exception Json.Input.Root
            (Json.Input.String "[1,invalid]") error
        )
        [
          Failure "callback";
          Json.Json_error "callback";
          Json.End_of_array;
          Json.End_of_object;
        ]
    )

let input_items_file_closure () =
  if Sys.file_exists "/proc/self/fd" then
    List.iter
      (fun text ->
        with_input_file text (fun file ->
            let descriptors () = Array.length (Sys.readdir "/proc/self/fd") in
            let before = descriptors () in
            for _ = 1 to 32 do
              List.iter
                (fun at ->
                  List.iter
                    (fun f ->
                      ignore
                        (Json.Input.fold_items ~at ~init:() ~f
                           (Json.Input.File file)
                        )
                    )
                    [
                      (fun () _ -> Json.Input.Continue ());
                      (fun () _ -> Json.Input.Validate_rest ());
                    ];
                  let error = Failure "close after callback" in
                  match
                    Json.Input.fold_items ~at ~init:()
                      ~f:(fun _ _ -> raise error)
                      (Json.Input.File file)
                  with
                  | _ ->
                      ()
                  | exception caught ->
                      Alcotest.(check bool)
                        "callback identity on cleanup" true (caught == error)
                )
                [
                  Json.Input.Root;
                  Json.Input.Member "x";
                  Json.Input.Member "missing";
                ]
            done;
            Alcotest.(check int)
              "no leaked file descriptors" before (descriptors ())
        )
      )
      [
        "[1,2]";
        "{x:[1,2],tail:3}";
        "{x:[1],tail:[01]}";
        "[1,01]";
        "[01]";
        "1";
        "{x:1}";
      ]

let input_items_refill () =
  let padding = String.make 65537 'x' in
  let text =
    "{before:[\"" ^ padding ^ "\"],x:[{k:\"" ^ padding ^ "\"},2],tail:[\""
    ^ padding ^ "\"]}"
  in
  with_input_file text (fun file ->
      with_input_channel file (fun channel ->
          check_items_source "refilled items" (Json.Input.Member "x") text
            (Json.Input.Channel channel);
          seek_in channel 0
      )
  )

let input_items_pipe () =
  if not Sys.win32 then
    List.iter
      (fun (at, prefix, tail, validate_rest, valid) ->
        let input_read, input_write = Unix.pipe () in
        let event_read, event_write = Unix.pipe () in
        let close fd =
          try Unix.close fd with Unix.Unix_error (Unix.EBADF, _, _) -> ()
        in
        let send fd char =
          if Unix.write fd (Bytes.make 1 char) 0 1 <> 1 then
            failwith "short pipe write"
        in
        match Unix.fork () with
        | 0 ->
            close input_write;
            close event_read;
            let channel = Unix.in_channel_of_descr input_read in
            ( try
                let result =
                  Json.Input.fold_items ~at ~init:0
                    ~f:(fun count value ->
                      if value <> `Int (count + 1) then
                        failwith "unexpected pipe item";
                      send event_write 'I';
                      if validate_rest then
                        Json.Input.Validate_rest (count + 1)
                      else
                        Json.Input.Continue (count + 1)
                    )
                    (Json.Input.Channel channel)
                in
                ignore (Unix.fstat (Unix.descr_of_in_channel channel));
                let expected_count =
                  if validate_rest || tail = "" then
                    1
                  else
                    2
                in
                let correct =
                  match result with
                  | Ok (Json.Input.Folded count) ->
                      valid && count = expected_count
                  | Error _ ->
                      not valid
                  | _ ->
                      false
                in
                send event_write
                  ( if correct then
                      'S'
                    else
                      'F'
                  )
              with _ -> ( try send event_write 'F' with _ -> ()
              )
            );
            close_in_noerr channel;
            close event_write;
            Unix._exit 0
        | pid ->
            Fun.protect
              ~finally:(fun () ->
                List.iter close
                  [ input_read; input_write; event_read; event_write ];
                ( try Unix.kill pid Sys.sigkill
                  with Unix.Unix_error (Unix.ESRCH, _, _) -> ()
                );
                ignore (Unix.waitpid [] pid)
              )
              (fun () ->
                close input_read;
                close event_write;
                let write text =
                  let bytes = Bytes.of_string text in
                  if
                    Unix.write input_write bytes 0 (Bytes.length bytes)
                    <> Bytes.length bytes
                  then
                    Alcotest.fail "short input write"
                in
                let receive expected =
                  let ready, _, _ = Unix.select [ event_read ] [] [] 3. in
                  if ready = [] then
                    Alcotest.fail "timed out waiting for parser event";
                  let byte = Bytes.create 1 in
                  if Unix.read event_read byte 0 1 <> 1 then
                    Alcotest.fail "missing parser event";
                  Alcotest.(check char)
                    "parser event" expected (Bytes.get byte 0)
                in
                write prefix;
                receive 'I';
                write tail;
                close input_write;
                if (not validate_rest) && tail <> "" && valid then receive 'I';
                receive 'S'
              )
      )
      [
        (Json.Input.Root, "[1,", "2]", false, true);
        (Json.Input.Root, "{a:1,", "a:2}", false, true);
        (Json.Input.Member "x", "{before:0,x:[1,", "2],tail:3}", false, true);
        (Json.Input.Member "x", "{x:{a:1,", "a:2},x:[3]}", false, true);
        (Json.Input.Root, "[1]", "", false, true);
        (Json.Input.Root, "[1,", "2]", true, true);
        (Json.Input.Member "x", "{x:[1,", "2],tail:[01]}", true, false);
        (Json.Input.Root, "[1,", "01]", false, false);
      ]

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
      from_string_fail_nested_unterminated
    );
    ( "from_string_fail_unterminated_structure",
      `Quick,
      from_string_fail_unterminated_structure
    );
    ( "from_string_fail_unstarted_structure",
      `Quick,
      from_string_fail_unstarted_structure
    );
    ( "from_string_fail_unstarted_object",
      `Quick,
      from_string_fail_unstarted_object
    );
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
    ("input_selection", `Quick, input_selection);
    ("input_value", `Quick, input_value);
    ("input_selection_errors", `Quick, input_selection_errors);
    ("input_sources", `Quick, input_sources);
    ("input_channel_refill", `Quick, input_channel_refill);
    ("input_file_closure", `Quick, input_file_closure);
    ("input_discarded_containers", `Quick, input_discarded_containers);
    ("input_items", `Quick, input_items);
    ("input_items_errors", `Quick, input_items_errors);
    ("input_items_validate_rest", `Quick, input_items_validate_rest);
    ("input_items_sources", `Quick, input_items_sources);
    ("input_items_exceptions", `Quick, input_items_exceptions);
    ("input_items_file_closure", `Quick, input_items_file_closure);
    ("input_items_refill", `Quick, input_items_refill);
    ("input_items_pipe", `Quick, input_items_pipe);
  ]
