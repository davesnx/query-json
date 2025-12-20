let _ =
  Alcotest.run "query-json"
    [
      ("Parsing", Test_parse.tests);
      ("Runtime", Test_runtime.tests);
      ("Errors", Test_errors.tests);
      ("Programs", Test_programs.tests);
    ]
