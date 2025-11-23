let test query json_str expected =
  let fn () =
    let result =
      match Json.parse_string json_str with
      | Error err -> Alcotest.fail ("JSON parse error: " ^ err)
      | Ok json -> (
          match Core.run query json with
          | Ok r -> r
          | Error err -> Alcotest.fail err)
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
    test "-1" "null" "-1";
    (* Dictionary construction syntax *)
    test "{a: 1}" "null" {|{ "a": 1 }|};
    (* test "{a,b,(.d):.a,e:.b}" "null" "{\"a\":1,\"b\":2,\"c\":3,\"d\":\"c\"}"; *)
    (* test ".[]" "[1, 2, 3]" "[1,2,3]"; *)
    test "1,1" "[]" "1\n1";
    test "1,." "[]" "1\n[]";
    test "[.]" "[2]" "[ [ 2 ] ]";
    test "[[2]]" "[3]" "[ [ 2 ] ]";
    test "[{}]" "[2]" "[ {} ]";
    (* test "[.[]]" "[\"a\"]" "[\"a\"]"; *)

    test ".foo?" {|{"foo": 42}|} {|42|};
    test ".foo?" {|{}|} "null";

    (* Array index tests *)
    test ".[0]" {|["a","b","c","d","e"]|} {|"a"|};
    test ".[3]" {|["a","b"]|} "null";
    test ".[-1]" {|["a","b","c","d","e"]|} {|"e"|};

    (* Array / String slice tests *)
    test ".[2:4]" {|["a","b","c","d","e"]|} {|[ "c", "d" ]|};
    test ".[2:4]" {|"abcdefghi"|} {|"cd"|};
    test ".[5:7]" {|["a","b","c"]|} {|[]|};
    test ".[5:7]" {|"abc"|} {|""|};
    test ".[:3]" {|["a","b","c","d","e"]|} {|[ "a", "b", "c" ]|};
    test ".[:-2]" {|["a","b","c","d","e"]|} {|[ "a", "b", "c" ]|};
    test ".[:3]" {|"abcdefghi"|} {|"abc"|};
    test ".[:-2]" {|"abcdefghi"|} {|"abcdefg"|};
    test ".[-2:]" {|["a","b","c","d","e"]|} {|[ "d", "e" ]|};
    test ".[2:]" {|["a","b","c","d","e"]|} {|[ "c", "d", "e" ]|};
    test ".[-2:]" {|"abcdefghi"|} {|"hi"|};
    test ".[2:]" {|"abcdefghi"|} {|"cdefghi"|};
    test ".[-4:-2]" {|["a","b","c","d","e"]|} {|[ "b", "c" ]|};
    test ".[-2:-4]" {|["a","b","c","d","e"]|} {|[]|};
    test ".[-4:-2]" {|"abcdefghi"|} {|"fg"|};
    test ".[-2:-4]" {|"abcde"|} {|""|};

    (* Iterator tests *)
    test ".[]" {|["a","b","c"]|} "\"a\"\n\"b\"\n\"c\"";
    test ".[]" {|[{"name":"JSON", "good":true}, {"name":"XML", "good":false}]|} "{ \"name\": \"JSON\", \"good\": true }\n{ \"name\": \"XML\", \"good\": false }";
    test ".foo[]" {|{"foo":[1,2,3]}|} "1\n2\n3";
    test ".[]" {|{"a": 1, "b": 1}|} "1\n1";

    test "1,1" "[]" "1\n1";
    test "1,." "[]" "1\n[]";
    test {|.foo | .bar|} {|{"foo": {"bar": 42}, "bar": "badvalue"}|} {|42|};
    test {|.foo.bar|} {|{"foo": {"bar": 42}, "bar": "badvalue"}|} {|42|};
    test {|.foo_bar|} {|{"foo_bar": 2}|} {|2|};
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
    test {|map(add)|}
         {|[[], [1,2,3], ["a","b","c"], [[3],[4,5],[6]], [{"a":1}, {"b":2}, {"a":3}]]|}
         {|[ null, 6, "abc", [ 3, 4, 5, 6 ], { "a": 4, "b": 2 } ]|};
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
    test {|[range(0;10)]|} {|null|} {|[ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 ]|};
(*     test {|[range(0,1;3,4)]|} {|null|} {|[0,1,2, 0,1,2,3, 1,2, 1,2,3]|}; *)
    test {|[range(0;10;3)]|} {|null|} {|[ 0, 3, 6, 9 ]|};
    test {|[range(0;10;-1)]|} {|null|} {|[]|};
    test {|[range(0;-5;-1)]|} {|null|} {|[ 0, -1, -2, -3, -4 ]|};
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
    test {|2-(-1)|} {|null|} {|3|};
    (* test {|1e+0+0.001e3|} {|"I wonder what this will be?"|} {|20e-1|}; *)
    test {|.+4|} {|15|} {|19|};
    test {|.+null|} {|{"a":42}|} {|{ "a": 42 }|};
    test {|null+.|} {|null|} {|null|};
    test {|.a+.b?|} {|{"a":42}|} {|42|};
    test {|[1,2,3] + [.]|} {|null|} {|[ 1, 2, 3, null ]|};
    test {|{"a":1} + {"b":2} + {"c":3}|} {|"asdfasdf"|} {|{ "a": 1, "b": 2, "c": 3 }|};
    test {|"asdf" + "jkl;" + . + . + .|}
         {|"some string"|} {|"asdfjkl;some stringsome stringsome string"|};
    (* test {|"\u0000\u0020\u0000" + .|}
         {|"\u0000\u0020\u0000"|} {|"\u0000 \u0000\u0000 \u0000"|}; *)
    test {|42 - .|} {|11|} {|31|};
    (* test {|[1,2,3,4,1] - [.,3]|} {|1|} {|[2,4]|}; *)
    test {|[10 * 20, 20 / .]|} {|4|} {|[ 200, 5 ]|};
    test {|1 + 2 * 2 + 10 / 2|} {|null|} {|10|};
    test {|[16 / 4 / 2, 16 / 4 * 2, 16 - 4 - 2, 16 - 4 + 2]|}
         {|null|}
         {|[ 2, 8, 10, 14 ]|};
    test {|25 % 7|} {|null|} {|4|};
    test {|49732 % 472|} {|null|} {|172|};
    test {|has("foo")|} {|{"foo": 42}|} {|true|};
    test {|map(has("foo"))|} {|[{"foo": 42}, {"only_bar": false}]|} {|[ true, false ]|};
    test {|map(in({"foo": 42}))|} {|["foo", "bar"]|} {|[ true, false ]|};
    test {|{user}|} {|null|} {|{ "user": null }|};
    test {|{user}|} {|{"user": 42}|} {|{ "user": 42 }|};
    test {|{user: .foo}|} {|{"user": 42, "foo": "something_else"}|} {|{ "user": "something_else" }|};
    test {|{user: {bar: .foo}}|} {|{"user": 42, "foo": "something_else"}|} {|{ "user": { "bar": "something_else" } }|};
    test {|range(0)|} {|null|} "";
    test {|range(10)|} {|null|} "1\n2\n3\n4\n5\n6\n7\n8\n9";
    test {|range(10;20)|} {|null|} "10\n11\n12\n13\n14\n15\n16\n17\n18\n19";
    test {|range(10;20;2)|} {|null|} "10\n12\n14\n16\n18";
    test {|split(",")|} {|"Hello,world,ignore"|} {|[ "Hello", "world", "ignore" ]|};
    test {|join(",")|} {|[ "Hello", "world", "ignore" ]|} {|"Hello,world,ignore"|};
    test {|if false then "h" else 42 end|} {|null|} {|42|};
    test {|if 5 > 10 then 5 elif 5 < 10 then 3 else 2 end|} {|null|} {|3|};

    (* Large integer tests - testing 64-bit integer overflow handling *)
    (* OCaml's int on 64-bit systems is limited to 63 bits (max: 4611686018427387903) *)
    test "." {|4611686018427387928|} {|4611686018427387928|};
    test "." {|4611686018427387903|} {|4611686018427387903|};
    test "." {|9223372036854775807|} {|9223372036854775807|};
    test "." {|-9223372036854775808|} {|-9223372036854775808|};
    test ".foo" {|{"foo": 4611686018427387928}|} {|4611686018427387928|};
    test ".[]" {|[4611686018427387928, 42]|} "4611686018427387928\n42";
    test ".[0]" {|[4611686018427387928, 42]|} {|4611686018427387928|};
    test ".data.value" {|{"data": {"value": 4611686018427387928}}|} {|4611686018427387928|};
    test "." {|{"large": 4611686018427387928, "small": 42}|} {|{ "large": 4611686018427387928, "small": 42 }|};

    test ".[0,1]" {|[1,2,3]|} "1\n2";
    test ".[1,2]" {|["a","b","c"]|} "\"b\"\n\"c\"";
    test ".[0,2,4]" {|[10,20,30,40,50]|} "10\n30\n50";

    test "abs" "-42" "42";
    test ".[] | abs" "[-1, -2, 3]" "1\n2\n3";

    test "length" {|[1,2,3]|} "3";
    test "map(length)" {|[[], [1,2]]|} {|[ 0, 2 ]|};

    test "map(select(. > 2))" "[1,2,3,4,5]" {|[ 3, 4, 5 ]|};

    test "reverse" "[1,2,3]" {|[ 3, 2, 1 ]|};

    test "true and false" "null" "false";
    test "true or false" "null" "true";
    test "not" "true" "false";
    test "not" "false" "true";

    test "type" "42" {|"number"|};
    test "type" {|"string"|} {|"string"|};
    test "map(type)" {|[1, "a", null]|} {|[ "number", "string", "null" ]|};

    test "floor" "3.7" "3";
    test "sqrt" "16" "4";

    test "to_number" {|"42"|} "42";
    test "tonumber" {|"42"|} "42";

    test "to_string" "42" {|"42"|};
    test "tostring" "42" {|"42"|};

    test "min" "[1,2,3]" "1";
    test "max" "[1,2,3]" "3";

    test "flatten" {|[[1,2],[3,4]]|} {|[ 1, 2, 3, 4 ]|};
    test "flatten(1)" {|[[[1,2]],[[3,4]]]|} {|[ [ 1, 2 ], [ 3, 4 ] ]|};

    test "sort" "[3,1,2]" {|[ 1, 2, 3 ]|};
    test "unique" "[1,2,1,3,2]" {|[ 1, 2, 3 ]|};
    test "any" "[true, false]" "true";
    test "all" "[true, true]" "true";
    test "all" "[true, false]" "false";

    test {|starts_with("Hello")|} {|"Hello, world"|} "true";
    test {|startswith("Hello")|} {|"Hello, world"|} "true";
    test {|startwith("Hello")|} {|"Hello, world"|} "true";
    test {|ends_with("world")|} {|"Hello, world"|} "true";
    test {|endswith("world")|} {|"Hello, world"|} "true";
    test {|endwith("world")|} {|"Hello, world"|} "true";

    test "to_entries" {|{"a":1,"b":2}|} {|[ { "key": "a", "value": 1 }, { "key": "b", "value": 2 } ]|};
    test "from_entries" {|[{"key":"a","value":1}]|} {|{ "a": 1 }|};

    test {|contains("foo")|} {|"foobar"|} "true";
    test "contains([2])" "[1,2,3]" "true";
    test "explode" {|"hello"|} {|[ 104, 101, 108, 108, 111 ]|};
    test "implode" "[72,101,108,108,111]" {|"Hello"|};

    test "25 % 7" "null" "4";
    test "10 % 3" "null" "1";

    test "sort_by(.name)" {|[{"name":"z"},{"name":"a"}]|} {|[ { "name": "a" }, { "name": "z" } ]|};
    test "min_by(.x)" {|[{"x":2},{"x":1}]|} {|{ "x": 1 }|};
    test "unique_by(.x)" {|[{"x":1},{"x":2},{"x":1}]|} {|[ { "x": 1 }, { "x": 2 } ]|};

    test {|index("b")|} {|"abc"|} "1";
    test {|rindex("b")|} {|"abcb"|} "3";

    test "group_by(.x)" {|[{"x":1},{"x":2},{"x":1}]|} {|[ [ { "x": 1 }, { "x": 1 } ], [ { "x": 2 } ] ]|};

    test "[while(.<100; .*2)]" "1" {|[ 1, 2, 4, 8, 16, 32, 64 ]|};
    test "[until(.>100; .*2)]" "1" {|[ 1, 2, 4, 8, 16, 32, 64, 128 ]|};

    test "[recurse(.+1; . < 5)]" "0" {|[ 0, 1, 2, 3, 4 ]|};
    test {|walk(if type == "number" then . + 1 else . end)|} {|{"a":1}|} {|{ "a": 2 }|};

    test "[.[] | { name: .name, city: .address.city}]"
         {|[{"name": "Gilbert", "address": {"city": "Toulouse"}}, {"name": "Alexa", "address": {"city": "Albi"}}]|}
         "[\n  { \"name\": \"Gilbert\", \"city\": \"Toulouse\" },\n  { \"name\": \"Alexa\", \"city\": \"Albi\" }\n]";

    (* Update operator tests *)
    test ".value |= . * 2" {|{"value": 5}|} "10";
    test ".x |= . + 1" {|{"x": 10}|} "11";
    test ".[] |= . * 2" "[1,2,3]" "2\n4\n6";

    (* with_entries tests *)
    test "with_entries(.value |= . * 2)" {|{"a": 1, "b": 2, "c": 3}|} {|{ "a": 2, "b": 4, "c": 6 }|};
    test "with_entries(.value |= . + 1)" {|{"x": 10, "y": 20}|} {|{ "x": 11, "y": 21 }|};
    test "with_entries(.key |= . + \"_suffix\")" {|{"a": 1, "b": 2}|} {|{ "a_suffix": 1, "b_suffix": 2 }|};
    test "with_entries(.value |= if . > 5 then . * 2 else . end)" {|{"a": 3, "b": 10}|} {|{ "a": 3, "b": 20 }|};

    (* Alternative operator tests *)
    test {|.email // "no-email@example.com"|} {|{"email": "test@example.com"}|} {|"test@example.com"|};
    test {|.email // "no-email@example.com"|} {|{"name": "John"}|} {|"no-email@example.com"|};
    test {|.email // "no-email@example.com"|} {|{"email": null}|} {|"no-email@example.com"|};
    test {|.email // "no-email@example.com"|} {|{"email": false}|} {|"no-email@example.com"|};
    test {|.email // "no-email@example.com"|} {|{"email": ""}|} {|""|};
    test {|.count // 0|} {|{"count": 5}|} {|5|};
    test {|.count // 0|} {|{}|} {|0|};
    test {|.value // 10 // 20|} {|{"value": null}|} {|10|};
    test {|.value // 10 // 20|} {|{}|} {|10|};

    (* New features tests *)

    (* nan and is_nan *)
    test "is_nan" "42" "false";
    test "is_nan" "42.5" "false";

    (* transpose *)
    test "transpose" {|[[1,2],[3,4]]|} {|[ [ 1, 3 ], [ 2, 4 ] ]|};
    test "transpose" {|[[1,2,3],[4,5,6]]|} {|[ [ 1, 4 ], [ 2, 5 ], [ 3, 6 ] ]|};
    test "transpose" {|[]|} {|[]|};

    (* flat_map *)
    test "flat_map(. * 2)" "[1,2,3]" {|[ 2, 4, 6 ]|};
    test "flat_map([., . * 2])" "[1,2]" {|[ 1, 2, 2, 4 ]|};

    (* find *)
    test "find(. > 2)" "[1,2,3,4]" "3";
    test "find(. > 10)" "[1,2,3]" "null";

    (* some *)
    test "some(. > 2)" "[1,2,3]" "true";
    test "some(. > 10)" "[1,2,3]" "false";

    (* any with condition *)
    test "any(. > 2)" "[1,2,3]" "true";
    test "any(. > 10)" "[1,2,3]" "false";

    (* all with condition *)
    test "all(. > 0)" "[1,2,3]" "true";
    test "all(. > 2)" "[1,2,3]" "false";

    (* test (regex) *)
    test {|test("^hello")|} {|"hello world"|} "true";
    test {|test("^hello")|} {|"world hello"|} "false";
    test {|test("[0-9]+")|} {|"abc123def"|} "true";

    (* path *)
    test "path(.foo)" {|{"foo": 1}|} {|[ "foo" ]|};

    (* reduce with variables *)
    test "reduce .[] as $x (0; . + $x)" "[1,2,3,4,5]" "15";
    test "reduce .[] as $item (0; . + $item)" "[10,20,30]" "60";

    (* variable references *)
    test "reduce .[] as $x (0; . + $x)" "[5]" "5";

    (* Control flow tests *)
    test "try(.foo)" {|{"foo": 42}|} "42";
    test "try(.foo)" {|{}|} "";
    test "limit(3; range(10))" "null" "1\n2\n3";
    test "limit(2; .[])" "[1,2,3,4,5]" "1\n2";
    test "[limit(3; range(10))]" "null" "[ 1, 2, 3 ]";
    test "isempty(empty)" "null" "true";
    test "isempty(.[])" "[]" "true";
    test "isempty(.[])" "[1]" "false";
    test "del(.foo)" {|{"foo": 1, "bar": 2}|} {|{ "bar": 2 }|};
    test "paths" {|{"a": {"b": 1}}|} "[ \"a\" ]\n[ \"a\", \"b\" ]";
    test "getpath([\"a\", \"b\"])" {|{"a": {"b": 42}}|} "42";

    (* Regex tests *)
    test {|sub("world"; "universe")|} {|"hello world"|} {|"hello universe"|};
    test {|gsub("l"; "L")|} {|"hello"|} {|"heLLo"|};
    test {|scan("[0-9]+")|} {|"abc123def456"|} "\"123\"\n\"456\"";

    (* Object/Path tests *)
    test {|setpath(["a", "b"]; 99)|} {|{"a": {"b": 42}}|} {|{ "a": { "b": 99 } }|};
    test {|setpath(["x"]; 1)|} {|{}|} {|{ "x": 1 }|};
    test {|del(.[0])|} {|[1,2,3]|} {|[ 2, 3 ]|};

    (* Math functions *)
    test "ceil" "3.2" "4";
    test "round" "3.7" "4";
    test "log10" "100" "2";
    test "exp" "0" "1";

    (* limit with infinite - would hang without limit! *)
    test "[limit(5; infinite)]" "null" "[ 0, 1, 2, 3, 4 ]";

    (* More advanced tests *)
    test "sin" "0" "0";
    test "cos" "0" "1";
    test {|[scan("[a-z]+")]|} {|"hello world test"|} {|[ "hello", "world", "test" ]|};

    (* Error propagation with try *)
    test {|try(error("test"))|} "null" "";
  ]
