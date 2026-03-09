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

let single_json = List.flatten [ to_file_tests; to_string_tests ]
