let rec show_demand : Json.demand -> string = function
  | Skip ->
      "Skip"
  | All ->
      "All"
  | Items d ->
      "Items (" ^ show_demand d ^ ")"
  | Fields fs ->
      let fs = List.sort (fun (a, _) (b, _) -> String.compare a b) fs in
      "Fields ["
      ^ String.concat "; "
          (List.map (fun (k, d) -> Printf.sprintf "%S, %s" k (show_demand d)) fs)
      ^ "]"

let analysis query expected =
  Alcotest.test_case query `Quick (fun () ->
      match Core.parse ~debug:false ~colorize:false query with
      | Error err ->
          Alcotest.fail err
      | Ok ast ->
          Alcotest.(check string)
            "demand" expected
            (show_demand (Demand.of_expression ast))
  )

let analysis_tests =
  [
    analysis "." "All";
    analysis ".a" {|Fields ["a", All]|};
    analysis ".a.b" {|Fields ["a", Fields ["b", All]]|};
    analysis ".[]" "All";
    analysis ".[] | .a" {|Items (Fields ["a", All])|};
    analysis ".a, .b.c" {|Fields ["a", All; "b", Fields ["c", All]]|};
    analysis ".a.b, .a.c" {|Fields ["a", Fields ["b", All; "c", All]]|};
    analysis ".a, .a.b" {|Fields ["a", All]|};
    analysis ".a, .[]" "All";
    analysis "1" "Skip";
    analysis ".a | 1" {|Fields ["a", Skip]|};
    analysis "[]" "Skip";
    analysis "[.[] | 1]" "Items (Skip)";
    analysis "[.[] | .a]" {|Items (Fields ["a", All])|};
    analysis "[.a] | .[] | .b" {|Fields ["a", Fields ["b", All]]|};
    analysis "[.a] | .b" {|Fields ["a", All]|};
    analysis "map(.a)" {|Items (Fields ["a", All])|};
    analysis "map(.a) | .[] | .b" {|Items (Fields ["a", Fields ["b", All]])|};
    analysis "map(1)" "Items (Skip)";
    analysis "select(.a)" "All";
    analysis ".[] | select(.a > 1) | .b" {|Items (Fields ["a", All; "b", All])|};
    analysis ".[] | select(.a) | 1" {|Items (Fields ["a", All])|};
    analysis ".a > .b" {|Fields ["a", All; "b", All]|};
    analysis ".a and 1" {|Fields ["a", All]|};
    analysis ".a ?? .b.c" {|Fields ["a", All; "b", Fields ["c", All]]|};
    analysis "if .a then .b.c else .d end | 1"
      {|Fields ["a", All; "b", Fields ["c", Skip]; "d", Skip]|};
    analysis "sort_by(.a)" "All";
    analysis "sort_by(.a) | .[] | .b" {|Items (Fields ["a", All; "b", All])|};
    analysis "unique_by(.a) | map(.b)" {|Items (Fields ["a", All; "b", All])|};
    analysis "min_by(.a) | .b" {|Items (Fields ["a", All; "b", All])|};
    analysis "max_by(.a) | 1" {|Items (Fields ["a", All])|};
    analysis "group_by(.a) | 1" {|Items (Fields ["a", All])|};
    analysis "group_by(.a) | .x" "All";
    analysis ".[0]" "All";
    analysis ".[0] | .a" "All";
    analysis ".a?" "All";
    analysis ".a | length" "All";
    analysis "keys" "All";
    analysis ".[1:2]" "All";
    analysis "{a: .a}" "All";
    analysis ".a |= 1" "All";
    analysis ".a = 1" "All";
    analysis "descend | .a" "All";
    analysis ". as $x | $x.a" "All";
    analysis "reduce .[] as $x (0; . + $x)" "All";
    analysis "foreach .[] as $x (0; . + $x; .)" "All";
    analysis "try .a catch 1" "All";
    analysis "fn f: .a; f" "All";
    analysis "$ENV" "All";
    analysis ".[\"a\"]" {|Fields ["a", All]|};
    analysis "path(.a)" "All";
    analysis "range(3)" "All";
    analysis "has(\"a\")" "All";
    analysis "to_entries" "All";
    analysis ".a | to_string" "All";
  ]

let documents =
  [
    {|{"a": 1, "b": {"c": 2, "d": [3, 4]}, "a-b": 5}|};
    {|{"a": 1, "a": 2, "b": {"c": 1, "c": [2]}}|};
    {|{"b": {"d": 1}}|};
    {|{"a": null, "b": null}|};
    {|{"\u0061": "escaped", "b\n": 1, "c": "x\u00e9"}|};
    {|[{"a": 1, "b": "x"}, {"a": 3, "b": "y", "c": [1]}, {"a": 2}]|};
    {|[{"a": {"b": 1}}, {"a": [1]}, {"a": "s"}, {"b": 1}]|};
    {|[{"a": 2, "b": 1}, {"a": 1, "b": 2}, {"a": 2, "b": 3}]|};
    {|[[1, 2], {"a": 1}, "x", 1.50, null, true]|};
    {|[]|};
    {|{}|};
    {|"text"|};
    {|12.50|};
    {|null|};
    {|[{"a": 1e3, "b": -0.0}, {"a": 1E-2, "b": 99999999999999999999}]|};
    {|{"a": [1, 2], "b": {"a": 1}}|};
    {|{a: 1, b: NaN, c: Infinity} /* c */|};
    "{\"a\": 1,\n \"b\": [1, 2, tru]}";
    "{\"a\": 1, \"b\": \"\\q\"}";
    "[{\"a\": 1}, {\"a\": 2}";
    "{\"a\": 1} x";
    "{\"b\": 1e99999999999999999999, \"a\": 1}";
    "";
  ]

let queries =
  [
    ".";
    ".a";
    ".b";
    ".b.c";
    ".b.d";
    ".a.b";
    ".[]";
    ".[] | .a";
    ".[] | .a.b";
    ".[] | .b";
    "[.[] | .a]";
    "map(.a)";
    "map(.a) | .[] | .b";
    "map(1)";
    "1";
    ".a | 1";
    ".a, .b";
    ".a, .b.c, .a";
    "select(.a)";
    ".[] | select(.a > 1) | .b";
    "map(select(.a > 1) | .b)";
    ".a > .b";
    ".a ?? .b";
    ".z ?? .a";
    "if .a then .b else .c end";
    "if .a then 1 else .b.c end";
    "sort_by(.a)";
    "sort_by(.a) | map(.b)";
    "unique_by(.a) | map(.b)";
    "min_by(.a) | .b";
    "max_by(.a)";
    "group_by(.a)";
    "group_by(.a) | 1";
    "[.[] | 1]";
    ".a and .b";
    ".[] | .a | 1";
    ".a +";
    "length";
  ]

let full_run query input =
  match Json.parse_string input with
  | Error err ->
      Error err
  | Ok json ->
      Core.run ~colorize:false query json

let demand_run query input =
  Core.run_input ~colorize:false query (fun demand ->
      Json.parse_string ~demand input
  )

let differential =
  List.concat_map
    (fun query ->
      List.map
        (fun input ->
          Alcotest.test_case (Printf.sprintf "%s on %S" query input) `Quick
            (fun () ->
              Alcotest.(check (result string string))
                "same as a full read" (full_run query input)
                (demand_run query input)
          )
        )
        documents
    )
    queries

let stream query expected =
  Alcotest.test_case ("stream " ^ query) `Quick (fun () ->
      match Core.parse ~debug:false ~colorize:false query with
      | Error err ->
          Alcotest.fail err
      | Ok ast ->
          Alcotest.(check (option string))
            "per-element query" expected
            (Option.map Ast.show_expression (Demand.stream ast))
  )

let stream_tests =
  [
    stream ".[]" (Some "Identity");
    stream ".[] | ." (Some "Identity");
    stream ".[] | .a" (Some {|(Key "a")|});
    stream ". | .[] | .a" (Some {|(Key "a")|});
    stream "(.[] | .a) | .b" (Some {|(Pipe ((Key "a"), (Key "b")))|});
    stream ".[] | (.a | .b)" (Some {|(Pipe ((Key "a"), (Key "b")))|});
    stream ".[] | .a, .b" (Some {|(Comma ((Key "a"), (Key "b")))|});
    stream ".[] | select(.a > 1) | [.a, .b]"
      (Some
         (Ast.show_expression
            (Pipe
               ( Fn1
                   (With_expr
                      ( Select,
                        Operation
                          (Key "a", Greater_than, Literal (Number (Integer "1")))
                      )
                   ),
                 List (Some (Comma (Key "a", Key "b")))
               )
            )
         )
      );
    stream ".[] | .[]" (Some "(Index [])");
    stream ".a | .[]" None;
    stream ".[]?" None;
    stream ".[0] | .a" None;
    stream "map(.a)" None;
    stream "[.[] | .a]" None;
    stream ".[] | debug" None;
    stream ".[] | .a | debug(\"m\")" None;
    stream ".[] | stderr" None;
    stream ".[] | if .a then debug else 1 end" None;
    stream ".[] | [.a | debug]" None;
    stream ".[] | fn f: .a; f"
      (Some {|(Pipe ((Fn ("f", [], (Key "a"))), (Apply ("f", []))))|});
    stream "fn f: .a; .[] | f" None;
    stream ".[] | (fn f: .a; f)"
      (Some {|(Pipe ((Fn ("f", [], (Key "a"))), (Apply ("f", []))))|});
    stream ".[] | halt" (Some "(Fn0 Halt)");
    stream ".[] | error" (Some "(Fn1 (With_expr (Error_msg, Identity)))");
    stream "(fn f: .a; .[]) | f" None;
  ]

let capture_stdout f =
  flush stdout;
  let file = Filename.temp_file "test_demand" ".out" in
  let fd = Unix.openfile file [ O_WRONLY; O_TRUNC ] 0o600 in
  let saved = Unix.dup Unix.stdout in
  Unix.dup2 fd Unix.stdout;
  Unix.close fd;
  let result =
    Fun.protect
      ~finally:(fun () ->
        flush stdout;
        Unix.dup2 saved Unix.stdout;
        Unix.close saved
      )
      f
  in
  let out = In_channel.with_open_bin file In_channel.input_all in
  Sys.remove file;
  (result, out)

let output_run ~stream query input =
  capture_stdout (fun () ->
      Core.run_output ~colorize:false ~stream query (fun demand each ->
          Json.parse_string_each ~demand ?each input
      )
  )

let printed_full_run query input =
  match full_run query input with
  | Ok s ->
      (Ok (), s ^ "\n")
  | Error err ->
      (Error err, "")

let stream_documents =
  [
    {|[{"a": 1, "b": "x"}, {"a": 2, "b": "y"}, {"a": 3, "b": "z"}]|};
    {|[{"a": 1, "b": "x"}, {"a": 2}, {"a": 3, "b": "z"}]|};
    {|[{"a": 1}, [2], "s", null, 4]|};
    {|[]|};
    {|[ ]|};
    {|[{"a": 1}, {"a": 2}, tru]|};
    {|[{"a": 1}, {"a": 2, "b": "\q"}]|};
    {|[{"a": 1}, {"a": 2}|};
    {|[{"a": 1}, {"a": 2}] x|};
    {|[{"a": 1}, {"a": 3, "b": 1e99999999999999999999}]|};
    {|{"a": [1, 2]}|};
    {|"s"|};
  ]

let stream_queries =
  [
    ".[]";
    ".[] | .a";
    ".[] | .b";
    ".[] | [.a, .b]";
    ".[] | select(.a > 1)";
    ".[] | select(.a > 1) | .b";
    ".[] | .a | . + 1";
    "(.[] | .a) | . * 2";
    ".[] | error";
    ".[] | if .a == 2 then error(\"boom\") else .a end";
    ".[] | if .a == 3 then error else . end";
    ".[] | empty";
    ".[] | .a?";
    ".[] | try .b catch \"none\"";
    ".[] | (.a, .a)";
    ".[] | .[]";
    ".[] | length";
    ".[] | break";
    ".[] | (fn f: .a; f)";
  ]

let output_differential =
  List.concat_map
    (fun query ->
      List.map
        (fun input ->
          Alcotest.test_case
            (Printf.sprintf "held output: %s on %S" query input) `Quick
            (fun () ->
              Alcotest.(check (pair (result unit string) string))
                "same as a full read"
                (printed_full_run query input)
                (output_run ~stream:false query input)
          )
        )
        (stream_documents @ documents)
    )
    (stream_queries @ queries)

let streamed_output =
  let check name query input expected =
    Alcotest.test_case name `Quick (fun () ->
        Alcotest.(check (pair (result unit string) string))
          "streamed output" expected
          (output_run ~stream:true query input)
    )
  in
  [
    check "streamed: success equals held output" ".[] | .a"
      {|[{"a": 1}, {"a": [2]}]|} (Ok (), "1\n[ 2 ]\n");
    check "streamed: no result prints one newline" ".[] | empty" "[1, 2]"
      (Ok (), "\n");
    check "streamed: JSON error after partial output" ".[] | .a"
      {|[{"a": 1}, {"a": 2}, tru]|}
      ( Error "JSON parse error: Line 1, bytes 21-25:\nInvalid token 'tru]'",
        "1\n2\n"
      );
    check "streamed: query error after partial output" ".[] | .a"
      {|[{"a": 1}, 2, {"a": 3}]|}
      ( Error
          "error[type_mismatch]: Cannot index number with string \"a\"\n\n\
          \  in: 2",
        "1\n"
      );
    check "streamed: JSON error wins over an earlier query error" ".[] | .a"
      {|[{"a": 1}, 2, tru]|}
      ( Error "JSON parse error: Line 1, bytes 14-18:\nInvalid token 'tru]'",
        "1\n"
      );
  ]

let tests =
  analysis_tests @ differential @ stream_tests @ output_differential
  @ streamed_output
