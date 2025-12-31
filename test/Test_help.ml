let starts_with ~prefix str =
  let plen = String.length prefix in
  String.length str >= plen && String.sub str 0 plen = prefix

let contains ~substring str =
  try
    let _ = Str.search_forward (Str.regexp_string substring) str 0 in
    true
  with Not_found -> false

let test_find_group_exists () =
  let result = Help.find_group "string" in
  Alcotest.(check bool) "string group exists" true (Option.is_some result)

let test_find_group_case_insensitive () =
  let result1 = Help.find_group "STRING" in
  let result2 = Help.find_group "String" in
  let result3 = Help.find_group "string" in
  Alcotest.(check bool) "STRING exists" true (Option.is_some result1);
  Alcotest.(check bool) "String exists" true (Option.is_some result2);
  Alcotest.(check bool) "string exists" true (Option.is_some result3)

let test_find_group_not_found () =
  let result = Help.find_group "nonexistent" in
  Alcotest.(check bool)
    "nonexistent group returns None" true (Option.is_none result)

let test_all_categories_exist () =
  let categories =
    [
      "string";
      "array";
      "object";
      "path";
      "math";
      "type";
      "control";
      "definition";
      "debug";
    ]
  in
  List.iter
    (fun cat ->
      let result = Help.find_group cat in
      Alcotest.(check bool) (cat ^ " group exists") true (Option.is_some result))
    categories

let test_available_categories () =
  let cats = Help.available_categories () in
  Alcotest.(check int) "9 categories available" 9 (List.length cats)

let test_string_group_has_functions () =
  match Help.find_group "string" with
  | None -> Alcotest.fail "string group not found"
  | Some (g : Language.category) ->
      Alcotest.(check bool)
        "string group has functions" true
        (List.length g.functions > 0);
      Alcotest.(check string) "group name is string" "string" g.name

let test_array_group_has_functions () =
  match Help.find_group "array" with
  | None -> Alcotest.fail "array group not found"
  | Some (g : Language.category) ->
      Alcotest.(check bool)
        "array group has functions" true
        (List.length g.functions > 0);
      let has_map =
        List.exists
          (fun (f : Language.function_info) -> f.name = "map")
          g.functions
      in
      Alcotest.(check bool) "array group has map function" true has_map

let test_format_group_produces_output () =
  match Help.find_group "string" with
  | None -> Alcotest.fail "string group not found"
  | Some g ->
      let output = Help.format_group ~colorize:false g in
      Alcotest.(check bool)
        "formatted output is not empty" true
        (String.length output > 0);
      Alcotest.(check bool)
        "output contains STRING FUNCTIONS" true
        (starts_with ~prefix:"STRING FUNCTIONS" output)

let test_format_categories_list () =
  let output = Help.format_categories_list ~colorize:false in
  Alcotest.(check bool)
    "categories list is not empty" true
    (String.length output > 0);
  Alcotest.(check bool)
    "output mentions string" true
    (contains ~substring:"string" output)

let tests =
  [
    Alcotest.test_case "find_group exists" `Quick test_find_group_exists;
    Alcotest.test_case "find_group case insensitive" `Quick
      test_find_group_case_insensitive;
    Alcotest.test_case "find_group not found" `Quick test_find_group_not_found;
    Alcotest.test_case "all categories exist" `Quick test_all_categories_exist;
    Alcotest.test_case "available_categories" `Quick test_available_categories;
    Alcotest.test_case "string group has functions" `Quick
      test_string_group_has_functions;
    Alcotest.test_case "array group has functions" `Quick
      test_array_group_has_functions;
    Alcotest.test_case "format_group produces output" `Quick
      test_format_group_produces_output;
    Alcotest.test_case "format_categories_list" `Quick
      test_format_categories_list;
  ]
