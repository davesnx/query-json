let read demand s =
  match Json.from_string ~demand s with
  | v ->
      Ok v
  | exception Json.Json_error msg ->
      Error msg

let full s = read Json.All s
let same_value = Alcotest.testable Json.pp (fun a b -> compare a b = 0)
let outcome = Alcotest.(result same_value string)

let check_value name demand input expected () =
  Alcotest.check outcome name (Ok expected) (read demand input)

let check_full name demand input () =
  Alcotest.check outcome name (full input) (read demand input)

let check_error name demand input expected () =
  Alcotest.check outcome name (Error expected) (read demand input)

let a = Json.Fields [ ("a", All) ]

let fields_keep_listed =
  check_value "keeps listed members only" a
    {|{"b": [1, {"c": 2}], "a": 1, "c": "x"}|}
    (`Assoc [ ("a", `Int 1) ])

let fields_keep_duplicates =
  check_value "keeps every duplicate in order" a
    {|{"a": 1, "b": 2, "a": [3], "a": "4"}|}
    (`Assoc [ ("a", `Int 1); ("a", `List [ `Int 3 ]); ("a", `String "4") ])

let fields_skip_value =
  check_value "a listed key with Skip stores null"
    (Fields [ ("a", Skip) ])
    {|{"a": {"deep": [1, 2]}, "b": 2}|}
    (`Assoc [ ("a", `Null) ])

let fields_missing_key =
  check_value "a missing key reads the object in full"
    (Fields [ ("a", All); ("z", All) ])
    {|{"a": 1, "b": {"c": [true]}}|}
    (`Assoc [ ("a", `Int 1); ("b", `Assoc [ ("c", `List [ `Bool true ]) ]) ])

let fields_missing_nested =
  check_value "a missing key below a kept member reads that member in full"
    (Fields [ ("a", Fields [ ("x", All) ]) ])
    {|{"a": {"y": 1, "z": [2]}, "b": 3}|}
    (`Assoc [ ("a", `Assoc [ ("y", `Int 1); ("z", `List [ `Int 2 ]) ]) ])

let fields_empty_object =
  check_value "an empty object has every key missing" a {|{}|} (`Assoc [])

let fields_missing_keeps_lines =
  check_error "line numbers after a reread object" a
    "{\"b\": 1,\n\"c\": 2\n}\n\n x"
    "Line 5, bytes 1-2:\nJunk after end of JSON value: 'x'"

let fields_kind_mismatch_array =
  check_value "Fields on an array reads it in full" a {|[{"b": 1}, 2]|}
    (`List [ `Assoc [ ("b", `Int 1) ]; `Int 2 ])

let fields_kind_mismatch_scalar =
  check_value "Fields on a string reads it in full" a {|"text"|} (`String "text")

let items_array =
  check_value "Items reads every element with its demand"
    (Items (Fields [ ("x", All) ]))
    {|[{"x": 1, "y": 2}, {"y": 3, "x": [4]}]|}
    (`List [ `Assoc [ ("x", `Int 1) ]; `Assoc [ ("x", `List [ `Int 4 ]) ] ])

let items_skip =
  check_value "Items Skip keeps one null per element" (Items Skip)
    {|[1, "a", {"b": 2}, [3], null]|}
    (`List [ `Null; `Null; `Null; `Null; `Null ])

let items_kind_mismatch_object =
  check_value "Items on an object reads it in full" (Items Skip)
    {|{"a": 1, "b": [2]}|}
    (`Assoc [ ("a", `Int 1); ("b", `List [ `Int 2 ]) ])

let items_kind_mismatch_scalar =
  check_value "Items on a number reads it in full" (Items Skip) {|12.50|}
    (`Decimal (Json.Decimal.of_lexeme_exn "12.50"))

let escaped_key =
  check_value "an escaped key matches its decoded name"
    (Fields [ ("a\"b", All); ("é", All) ])
    {|{"a\"b": 1, "é": 2, "a\"c": 3}|}
    (`Assoc [ ("a\"b", `Int 1); ("é", `Int 2) ])

let escaped_skipped_key =
  check_value "an escaped key that is not listed is skipped" a
    {|{"é\n": 1, "a": 2}|}
    (`Assoc [ ("a", `Int 2) ])

let unquoted_key =
  check_value "an unquoted key matches" a {|{b: 1, a: 2}|}
    (`Assoc [ ("a", `Int 2) ])

let key_prefix =
  check_value "a key that only shares a prefix does not match" a
    {|{"ab": 1, "": 2, "a": 3}|}
    (`Assoc [ ("a", `Int 3) ])

let skip_every_kind =
  check_value "every kind of value is skipped"
    (Fields [ ("keep", All) ])
    {|{"s": "plain", "e": "a\n\"bé😀", "i": -12,
       "big": 123456789012345678901234567890, "d": 1.25, "x": 1.5e+10,
       "t": true, "f": false, "n": null, "nan": NaN, "inf": Infinity,
       "ninf": -Infinity, "o": {"a": [1, {"b": "c"}]}, "eo": {}, "ea": [],
       "a": [[], [[1]], "x"], /* comment */ "keep": "yes" // line
     }|}
    (`Assoc [ ("keep", `String "yes") ])

let skip_root =
  check_value "Skip on the root stores null" Skip {|{"a": [1, "b"]}|} `Null

let all_is_full =
  check_full "All is the full reader" All {|{"a": [1, {"b": "c"}], "a": 2}|}

let bad_fragments =
  [
    "tru";
    "nul";
    "-";
    "-x";
    "01";
    "1.";
    "1e";
    "+1";
    {|"abc|};
    {|"\q"|};
    {|"\u12"|};
    {|"\uD83Dx"|};
    {|"\uD83DA"|};
    "[1 2]";
    "[1,]";
    "{\"a\" 1}";
    "{\"a\": 1 \"b\": 2}";
    "{1: 2}";
    "{\"a\": 1,}";
    "/* open";
    "[";
    "{";
    "}";
    "x";
    "1e99999999999999999999";
    "1e-99999999999999999999";
  ]

let skipped_error fragment =
  let input = "{\"keep\": 1,\n \"skip\": " ^ fragment ^ "\n}" in
  ( Printf.sprintf "error inside a skipped member %S" fragment,
    `Quick,
    fun () ->
      Alcotest.(check (result string string))
        "same outcome as the full reader"
        (Json.parse_string input |> Result.map Json.to_string)
        (Json.parse_string ~demand:(Fields [ ("keep", All) ]) input
        |> Result.map Json.to_string
        )
  )

let skipped_error_text =
  check_error "exact error text inside a skipped member"
    (Fields [ ("keep", All) ])
    "{\"keep\": 1,\n  \"skip\": [1, \"a\\qb\"]}"
    "Line 2, bytes 17-22:\nInvalid escape sequence 'qb\"]}'"

let skipped_exponent_failure () =
  let input = {|{"keep": 1, "skip": 1e99999999999999999999}|} in
  Alcotest.(check (result string string))
    "exponent conversion failure is kept"
    (Error "Failure(\"int_of_string\") There was an error reading the string")
    (Json.parse_string ~demand:(Fields [ ("keep", All) ]) input
    |> Result.map Json.to_string
    )

let missing_key_across_chunks () =
  let input_file = Filename.temp_file "test_jotason_demand" ".json" in
  Fun.protect
    ~finally:(fun () -> Sys.remove input_file)
    (fun () ->
      let demand = Json.Fields [ ("a", Fields [ ("z", All) ]); ("q", All) ] in
      List.iter
        (fun size ->
          let json =
            Printf.sprintf
              "{\"b\": 0,\n \"a\": {\"pad\": \"%s\",\n \"k\": [1]}}"
              (String.make size 'p')
          in
          Out_channel.with_open_bin input_file (fun oc -> output_string oc json);
          Alcotest.check outcome
            (Printf.sprintf "file of %d bytes" (String.length json))
            (full json)
            ( match Json.from_file ~demand input_file with
            | v ->
                Ok v
            | exception Json.Json_error msg ->
                Error msg
            )
        )
        [ 10; 65500; 65536; 200_000 ]
    )

let demand_across_chunk fragment () =
  let demand = Json.Fields [ ("k", All) ] in
  let input_file = Filename.temp_file "test_jotason_demand" ".json" in
  Fun.protect
    ~finally:(fun () -> Sys.remove input_file)
    (fun () ->
      for shift = 0 to String.length fragment + 8 do
        let json =
          "{\"k\": 0,"
          ^ String.make (65536 - shift) ' '
          ^ "\"s\": " ^ fragment ^ "}"
        in
        Out_channel.with_open_bin input_file (fun oc -> output_string oc json);
        Alcotest.check outcome
          (Printf.sprintf "%S split at %d" fragment shift)
          (read demand json)
          ( match Json.from_file ~demand input_file with
          | v ->
              Ok v
          | exception Json.Json_error msg ->
              Error msg
          )
      done
    )

let tests =
  [
    ("Fields keeps listed", `Quick, fields_keep_listed);
    ("Fields keeps duplicates", `Quick, fields_keep_duplicates);
    ("Fields with Skip", `Quick, fields_skip_value);
    ("Fields missing key", `Quick, fields_missing_key);
    ("Fields missing nested key", `Quick, fields_missing_nested);
    ("Fields empty object", `Quick, fields_empty_object);
    ("Fields reread keeps lines", `Quick, fields_missing_keeps_lines);
    ("Fields on array", `Quick, fields_kind_mismatch_array);
    ("Fields on scalar", `Quick, fields_kind_mismatch_scalar);
    ("Items array", `Quick, items_array);
    ("Items Skip", `Quick, items_skip);
    ("Items on object", `Quick, items_kind_mismatch_object);
    ("Items on scalar", `Quick, items_kind_mismatch_scalar);
    ("escaped key", `Quick, escaped_key);
    ("escaped skipped key", `Quick, escaped_skipped_key);
    ("unquoted key", `Quick, unquoted_key);
    ("key prefix", `Quick, key_prefix);
    ("skip every kind", `Quick, skip_every_kind);
    ("skip root", `Quick, skip_root);
    ("All", `Quick, all_is_full);
    ("skipped error text", `Quick, skipped_error_text);
    ("skipped exponent failure", `Quick, skipped_exponent_failure);
    ("missing key across chunks", `Quick, missing_key_across_chunks);
  ]
  @ List.map skipped_error bad_fragments
  @ List.map
      (fun fragment ->
        ( Printf.sprintf "demand across chunk %S" fragment,
          `Quick,
          demand_across_chunk fragment
        )
      )
      Test_read.chunk_fragments
