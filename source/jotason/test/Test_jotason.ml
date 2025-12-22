(* Main test runner for Jotason *)

let () =
  Alcotest.run "Jotason"
    [
      ("read", Test_read.single_json);
      ("write", Test_write.single_json);
    ]

