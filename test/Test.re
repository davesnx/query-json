let _ =
  Alcotest.run(
    "query-json",
    [("Parsing", Parsing_test.tests), ("Runtime", Runtime_test.tests)],
  );
