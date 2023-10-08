open QueryJsonCore;

let json_testable = Alcotest.testable(Json.pp, Json.equal);

let case = (input, expected) => {
  let fn = () => {
    let result =
      switch (Json.parseString(input)) {
      | Ok(r) => r
      | Error(err) => Alcotest.fail(err)
      };
    ();
    Alcotest.check(json_testable, "should be equal", result, expected);
  };
  Alcotest.test_case(input, `Quick, fn);
};

let tests = [
  case({| { "int": 12345 } |}, `Assoc([("int", `Int(12345))])),
  case(
    {| { "not_overflow": 46116860184273879 } |},
    `Assoc([("not_overflow", `Int(46116860184273879))]),
  ),
  case(
    {| { "overflow": 12345678999999999999 } |},
    `Assoc([("overflow", `String("12345678999999999999"))]),
  ),
];
