let test query json expected =
  let fn () =
    let result =
      match Core.run query json with
      | Ok r -> r
      | Error err -> Alcotest.fail err
    in
    ();
    Alcotest.check Alcotest.string "should be equal" expected result
  in
  Alcotest.test_case query `Quick fn

[@@@ocamlformat "disable"] (* Because we want to keep custom formatting for readability of the tests cases *)

let tests =
  [
    (* Simple value tests to check parser. Input is irrelevant *)
    test "true" "null" "true";
    test "false" "null" "false";
    test "null" "null" "null";
    test "42" "null" "42";
    (* test "-1" "null" "-1"; *)
    (* Dictionary construction syntax *)
    (* test "{a: 1}" "null" "{\"a\":1}"; *)
    (* test "{a,b,(.d):.a,e:.b}" "null" "{\"a\":1,\"b\":2,\"c\":3,\"d\":\"c\"}"; *)
    (* test ".[]" "[1, 2, 3]" "[1,2,3]"; *)
    test "1,1" "[]" "1\n1";
    test "1,." "[]" "1\n[]";
    test "[.]" "[2]" "[ [ 2 ] ]";
    test "[[2]]" "[3]" "[ [ 2 ] ]";
    (* test "[{}]" "[2]" "[{}]"; *)
    (* test "[.[]]" "[\"a\"]" "[\"a\"]"; *)
    test "1,1" "[]" "1\n1";
    test "1,." "[]" "1\n[]";
    test {|.foo | .bar|} {|{"foo": {"bar": 42}, "bar": "badvalue"}|} {|42|};
    test {|.foo.bar|} {|{"foo": {"bar": 42}, "bar": "badvalue"}|} {|42|};
    (* test {|.foo_bar|} {|{"foo_bar": 2}|} {|2|}; *)
    (* test {|.["foo"].bar|} {|{"foo": {"bar": 42}, "bar": "badvalue"}|} {|42|}; *)
    test {|."foo"."bar"|} {|{"foo": {"bar": 20}}|} {|20|};
    (* test {|[.[]|.foo?]|} {|[1,[2],{"foo":3,"bar":4},{},{"foo":5}]|}
      {|[3,null,5]|}; *)
    (* test {|[.[]|.foo?.bar?]|} {|[1,[2],[],{"foo":3},{"foo":{"bar":4}},{}]|} {|[4,null]|}; *)
    (* test {|[.[] | length]|} {|[[], {}, [1,2], {"a":42}, "asdf", "\u03bc"]|} {|[0, 0, 2, 1, 4, 1]|}; *)
    test {|map(keys)|}
         {|[{}, {"abcd":1,"abc":2,"abcde":3}, {"x":1, "z": 3, "y":2}]|}
         {|[ [], [ "abcd", "abc", "abcde" ], [ "x", "z", "y" ] ]|};
    (* test {|[1,2,empty,3,empty,4]|} {|null|} {|[ (1, 2, 3, 4) ]|}; *)
    (* test {|map(add)|}
         {|[[], [1,2,3], ["a","b","c"], [[3],[4,5],[6]], [{"a":1}, {"b":2}, {"a":3}]]|}
         {|[null, 6, "abc", [3,4,5,6], {"a":3, "b": 2}]|}; *)
    (* test {|map_values(.+1)|} {|[0,1,2]|} {|[1,2,3]|}; *)
    (* test {|.[]|} {|[1,2,3]|} "1\n2\n3"; *)
    test {|1,1|} {|[]|} "1\n1";
    test {|1,.|} {|[]|} "1\n[]";
    test {|[.]|} {|[2]|} {|[ [ 2 ] ]|};
    (* test {|[(.,1),((.,.[]),(2,3))]|}
         {|["a","b"]|}
         {|[["a","b"],1,["a","b"],"a","b",2,3]|}; *)
    (* test {|[([5,5][]),.,.[]]|} {|[1,2,3]|} {|[5,5,[1,2,3],1,2,3]|}; *)
    (* test {|{x: (1,2)},{x:3} | .x|} {|null|} "1\n2\n3"; *)
    (* test {|.[-2]|} {|[1,2,3]|} {|2|}; *)
    (* test {|[range(0;10)]|} {|null|} {|[0,1,2,3,4,5,6,7,8,9]|}; *)
    (* test {|[range(0,1;3,4)]|} {|null|} {|[0,1,2, 0,1,2,3, 1,2, 1,2,3]|}; *)
    (* test {|[range(0;10;3)]|} {|null|} {|[0,3,6,9]|}; *)
    (* test {|[range(0;10;-1)]|} {|null|} {|[0,-1,-2,-3,-4]|}; *)
    (* test {|[range(0;-5;-1)]|} {|null|} {|[0,-1,-2,-3,-4]|}; *)
    (* test {|[range(0,1;4,5;1,2)]|}
         {|null|}
         {|[0,1,2,3,0,2, 0,1,2,3,4,0,2,4, 1,2,3,1,3, 1,2,3,4,1,3]|}; *)
    (* test {|[while(.<100; .*2)]|}
         {|1|}
         {|[1,2,4,8,16,32,64]|}; *)
    (* test {|[.[]|[.,1]|until(.[0] < 1; [.[0] - 1, .[1] * .[0]])|.[1]]|}
         {|[1,2,3,4,5]|} {|[1,2,6,24,120]|}; *)
    (* test {|flatten(3,2,1)|}
         {|[0, [1], [[2]], [[[3]]]]|}
         "[0,1,2,3]\n[0,1,2,[3]]\n[0,1,[2],[[3]]]"; *)
    (* Builtin functions *)
    test {|1+1|} {|null|} {|2|};
    test {|1+1|} {|"wtasdf"|} {|2|};
    test {|2-1|} {|null|} {|1|};
    (* test {|2-(-1)|} {|null|} {|3|}; *)
    (* test {|1e+0+0.001e3|} {|"I wonder what this will be?"|} {|20e-1|}; *)
    test {|.+4|} {|15|} {|19|};
    (* test {|.+null|} {|{"a":42}|} {|{"a":42}|}; *)
    (* test {|null+.|} {|null|} {|null|}; *)
    (* test {|.a+.b|} {|{"a":42}|} {|42|}; *)
    (* test {|[1,2,3] + [.]|} {|null|} {|[1,2,3,null]|}; *)
    (* test {|{"a":1} + {"b":2} + {"c":3}|} {|"asdfasdf"|} {|{"a":1, "b":2, "c":3}|}; *)
    (* test {|"asdf" + "jkl;" + . + . + .|}
         {|"some string"|} {|"asdfjkl;some stringsome stringsome string"|}; *)
    (* test {|"\u0000\u0020\u0000" + .|}
         {|"\u0000\u0020\u0000"|} {|"\u0000 \u0000\u0000 \u0000"|}; *)
    test {|42 - .|} {|11|} {|31|};
    (* test {|[1,2,3,4,1] - [.,3]|} {|1|} {|[2,4]|}; *)
    test {|[10 * 20, 20 / .]|} {|4|} {|[ 200, 5 ]|};
    test {|1 + 2 * 2 + 10 / 2|} {|null|} {|10|};
    test {|[16 / 4 / 2, 16 / 4 * 2, 16 - 4 - 2, 16 - 4 + 2]|}
         {|null|}
         {|[ 2, 8, 10, 14 ]|};
    (* test {|25 % 7|} {|null|} {|4|}; *)
    (* test {|49732 % 472|} {|null|} {|172|}; *)
  ]
