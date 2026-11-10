(* Tests for Jotason writing/serialization *)

let to_string_tests =
  let test ?suf expected =
    Alcotest.(check string)
      __LOC__ expected
      (Json.to_string ?suf Fixtures.json_value)
  in
  [
    ( "to_string with default settings",
      `Quick,
      fun () -> test Fixtures.json_string
    );
    ( "to_string with newline",
      `Quick,
      fun () -> test ~suf:"\n" Fixtures.json_string_newline
    );
    ( "to_string without newline",
      `Quick,
      fun () -> test ~suf:"" Fixtures.json_string
    );
  ]

let to_file_tests =
  let test ?suf expected =
    let output_file = Filename.temp_file "test_jotason_to_file" ".json" in
    Json.to_file ?suf output_file Fixtures.json_value;
    let file_content =
      let ic = open_in_bin output_file in
      let length = in_channel_length ic in
      let s = really_input_string ic length in
      close_in ic;
      s
    in
    Sys.remove output_file;
    Alcotest.(check string) __LOC__ expected file_content
  in
  [
    ( "to_file with default settings",
      `Quick,
      fun () -> test Fixtures.json_string_newline
    );
    ( "to_file with newline",
      `Quick,
      fun () -> test ~suf:"\n" Fixtures.json_string_newline
    );
    ( "to_file without newline",
      `Quick,
      fun () -> test ~suf:"" Fixtures.json_string
    );
  ]

(* Covers the Pretty (indented) writer's per-item rendering
   (write_list_item(_plain)/write_assoc_item(_plain)) and float formatting:
   code paths touched while removing a per-element closure allocation and
   routing non-integral floats through caml_format_float directly instead
   of Printf. *)
let pretty_uncolored json =
  Json.Pretty.to_string_colored ~colorize:false ~summarize:false json
let pretty_colored json =
  Json.Pretty.to_string_colored ~colorize:true ~summarize:false json
let quote s = "\"" ^ s ^ "\""
let green s = "\027[32m" ^ s ^ "\027[39m\027[0m"
let key_color s = "\027[1m\027[34m" ^ s ^ "\027[39m\027[0m"

let float_tests =
  let test f expected =
    ( Printf.sprintf "pretty float %h" f,
      `Quick,
      fun () ->
        Alcotest.(check string) __LOC__ expected (pretty_uncolored (`Float f))
    )
  in
  [
    test 1.0 "1";
    (* whole-valued floats print without a decimal point *)
    test 1e5 "100000";
    test (-0.0) "0";
    test 3.14159 "3.14159";
    test (-2.5) "-2.5";
    test 100.25 "100.25";
    test 1.5e-10 "1.5e-10";
  ]

let assoc_multiline_test =
  let n = 12 in
  let key i = Printf.sprintf "key%d" i in
  let json : Json.t = `Assoc (List.init n (fun i -> (key i, `Int i))) in
  let line ~last i =
    Printf.sprintf "  %s: %d%s"
      (quote (key i))
      i
      ( if last then
          "\n"
        else
          ",\n"
      )
  in
  let line_colored ~last i =
    Printf.sprintf "  %s: %s%s"
      (key_color (quote (key i)))
      (green (string_of_int i))
      ( if last then
          "\n"
        else
          ",\n"
      )
  in
  let body_of mk =
    String.concat "" (List.init n (fun i -> mk ~last:(i = n - 1) i))
  in
  [
    ( "pretty multi-line object: >120 compact-width forces one key per line, \
       exercising both interior (comma) and final (no comma) entries",
      `Quick,
      fun () ->
        Alcotest.(check string)
          __LOC__
          ("{\n" ^ body_of line ^ "}")
          (pretty_uncolored json)
    );
    ( "pretty multi-line object, colored",
      `Quick,
      fun () ->
        Alcotest.(check string)
          __LOC__
          ("{\n" ^ body_of line_colored ^ "}")
          (pretty_colored json)
    );
  ]

let list_multiline_with_empty_test =
  let n = 45 in
  let json : Json.t =
    `List (`List [] :: `Assoc [] :: List.init n (fun i -> `Int i))
  in
  let last i = i = n - 1 in
  let body_of ~empty ~item =
    empty "[]" ^ empty "{}"
    ^ String.concat "" (List.init n (fun i -> item ~last:(last i) i))
  in
  let plain_empty s = Printf.sprintf "  %s,\n" s in
  let plain_item ~last i =
    Printf.sprintf "  %d%s" i
      ( if last then
          "\n"
        else
          ",\n"
      )
  in
  let colored_item ~last i =
    Printf.sprintf "  %s%s"
      (green (string_of_int i))
      ( if last then
          "\n"
        else
          ",\n"
      )
  in
  [
    ( "pretty multi-line array: nested empty [] and {} stay on one line inside \
       a multi-line parent, and the closure-free per-item writer still gets \
       the last-item newline (no trailing comma) right",
      `Quick,
      fun () ->
        Alcotest.(check string)
          __LOC__
          ("[\n" ^ body_of ~empty:plain_empty ~item:plain_item ^ "]")
          (pretty_uncolored json)
    );
    ( "pretty multi-line array, colored",
      `Quick,
      fun () ->
        Alcotest.(check string)
          __LOC__
          ("[\n" ^ body_of ~empty:plain_empty ~item:colored_item ^ "]")
          (pretty_colored json)
    );
  ]

(* 100 levels of single-child nesting: past `indent_for`'s cached-depth cap
   (64), so this exercises the uncached `String.make` fallback. *)
let deep_indent_test =
  let depth = 100 in
  let json : Json.t =
    let rec build n =
      if n = 0 then
        `Int 0
      else
        `List [ build (n - 1) ]
    in
    build depth
  in
  let indent n = String.make (2 * n) ' ' in
  let opens = String.concat "" (List.init depth (fun i -> indent i ^ "[\n")) in
  let value = indent depth ^ "0\n" in
  let closes =
    String.concat ""
      (List.init depth (fun j ->
           let line = indent (depth - 1 - j) ^ "]" in
           if j = depth - 1 then
             line
           else
             line ^ "\n"
       )
      )
  in
  let expected = opens ^ value ^ closes in
  [
    ( "pretty multi-line array: 100-deep single nesting exercises indent_for \
       past its cached-depth cap",
      `Quick,
      fun () -> Alcotest.(check string) __LOC__ expected (pretty_uncolored json)
    );
  ]

let single_json =
  List.flatten
    [
      to_file_tests;
      to_string_tests;
      float_tests;
      assoc_multiline_test;
      list_multiline_with_empty_test;
      deep_indent_test;
    ]
