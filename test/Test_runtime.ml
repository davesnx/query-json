let test query input expected =
  let fn () =
    let result =
      match Json.parse_string input with
      | Error err -> Alcotest.fail ("JSON parse error: " ^ err.message)
      | Ok json -> (
          match Core.run ~colorize:false query json with
          | Ok r -> r
          | Error err -> Alcotest.fail err)
    in
    ();
    Alcotest.check Alcotest.string "should be equal" expected result
  in
  Alcotest.test_case query `Quick fn

let identity =
  [
    test {|.|} {|"Hello, world!"|} {|"Hello, world!"|};
    test {|.|} {|{"foo": 42}|} {|{ "foo": 42 }|};
    test {|.|} {|["boo", "balala"]|} {|[ "boo", "balala" ]|};
  ]

let literals =
  [
    test {|true|} {|null|} {|true|};
    test {|false|} {|null|} {|false|};
    test {|null|} {|null|} {|null|};
    test {|42|} {|null|} {|42|};
    test {|-1|} {|null|} {|-1|};
  ]

let comments =
  [
    (* Inline comments *)
    test {|.foo # get the foo field|} {|{"foo": 42}|} {|42|};
    test {|. + 1 # add one|} {|5|} {|6|};
    (* Comments at start *)
    test {|# This is a comment
.foo|} {|{"foo": 42}|} {|42|};
    (* Comments in complex expressions *)
    test {|.[] | # iterate
select(. > 2) # filter
|} {|[1, 2, 3, 4]|} "3\n4";
    (* Multiple comments *)
    test {|# comment 1
# comment 2
.|} {|42|} {|42|};
    (* Empty comment *)
    test {|.#
|} {|42|} {|42|};
  ]

let large_numbers =
  (* 64-bit integer overflow handling *)
  (* OCaml's int on 64-bit systems is limited to 63 bits (max: 4611686018427387903) *)
  [
    test {|.|} {|4611686018427387928|} {|4611686018427387928|};
    test {|.|} {|4611686018427387903|} {|4611686018427387903|};
    test {|.|} {|9223372036854775807|} {|9223372036854775807|};
    test {|.|} {|-9223372036854775808|} {|-9223372036854775808|};
    test {|.foo|} {|{"foo": 4611686018427387928}|} {|4611686018427387928|};
    test {|.[]|} {|[4611686018427387928, 42]|} "4611686018427387928\n42";
    test {|.[0]|} {|[4611686018427387928, 42]|} {|4611686018427387928|};
    test {|.data.value|} {|{"data": {"value": 4611686018427387928}}|}
      {|4611686018427387928|};
    test {|.|} {|{"large": 4611686018427387928, "small": 42}|}
      {|{ "large": 4611686018427387928, "small": 42 }|};
  ]

let object_identifier_index =
  [
    test {|.foo|} {|{"foo": 42, "bar": "less interesting data"}|} {|42|};
    test {|.foo | .bar|} {|{"foo": {"bar": 42}, "bar": "badvalue"}|} {|42|};
    test {|.foo.bar|} {|{"foo": {"bar": 42}, "bar": "badvalue"}|} {|42|};
    test {|.foo_bar|} {|{"foo_bar": 2}|} {|2|};
    test {|."foo"."bar"|} {|{"foo": {"bar": 20}}|} {|20|};
  ]

let optional_object_identifier_index =
  [
    test {|.foo?|} {|{"foo": 42}|} {|42|};
    test {|.foo?|} {|{}|} {|null|};
    test {|.foo?|} {|{"foo": 42, "bar": "less interesting data"}|} {|42|};
    test {|.foo?|} {|{"notfoo": true, "alsonotfoo": false}|} {|null|};
    test {|.a + (.b? // 0)|} {|{"a":42}|} {|42|};
  ]

let array_index =
  [
    test {|.[0]|} {|["a","b","c","d","e"]|} {|"a"|};
    test {|.[3]?|} {|["a","b"]|} {|null|};
    test {|.[-1]|} {|["a","b","c","d","e"]|} {|"e"|};
    test {|.[-2]|} {|[1,2,3]|} {|2|};
    test {|.[0]|}
      {|[{"name":"JSON", "good":true}, {"name":"XML", "good":false}]|}
      {|{ "name": "JSON", "good": true }|};
    test {|.[2]?|}
      {|[{"name":"JSON", "good":true}, {"name":"XML", "good":false}]|} {|null|};
  ]

let array_index_multiple =
  [
    test {|.[0,1]|} {|[1,2,3]|} "1\n2";
    test {|.[1,2]|} {|["a","b","c"]|} "\"b\"\n\"c\"";
    test {|.[0,2,4]|} {|[10,20,30,40,50]|} "10\n30\n50";
    test {|.[4,2]|} {|["a","b","c","d","e"]|} "\"e\"\n\"c\"";
  ]

let array_string_slice =
  [
    test {|.[2:4]|} {|["a","b","c","d","e"]|} {|[ "c", "d" ]|};
    test {|.[2:4]|} {|"abcdefghi"|} {|"cd"|};
    test {|.[5:7]|} {|["a","b","c"]|} {|[]|};
    test {|.[5:7]|} {|"abc"|} {|""|};
    test {|.[:3]|} {|["a","b","c","d","e"]|} {|[ "a", "b", "c" ]|};
    test {|.[:-2]|} {|["a","b","c","d","e"]|} {|[ "a", "b", "c" ]|};
    test {|.[:3]|} {|"abcdefghi"|} {|"abc"|};
    test {|.[:-2]|} {|"abcdefghi"|} {|"abcdefg"|};
    test {|.[-2:]|} {|["a","b","c","d","e"]|} {|[ "d", "e" ]|};
    test {|.[2:]|} {|["a","b","c","d","e"]|} {|[ "c", "d", "e" ]|};
    test {|.[-2:]|} {|"abcdefghi"|} {|"hi"|};
    test {|.[2:]|} {|"abcdefghi"|} {|"cdefghi"|};
    test {|.[-4:-2]|} {|["a","b","c","d","e"]|} {|[ "b", "c" ]|};
    test {|.[-2:-4]|} {|["a","b","c","d","e"]|} {|[]|};
    test {|.[-4:-2]|} {|"abcdefghi"|} {|"fg"|};
    test {|.[-2:-4]|} {|"abcde"|} {|""|};
  ]

let array_object_value_iterator =
  [
    test {|.[]|} {|["a","b","c"]|} "\"a\"\n\"b\"\n\"c\"";
    test {|.[]|}
      {|[{"name":"JSON", "good":true}, {"name":"XML", "good":false}]|}
      "{ \"name\": \"JSON\", \"good\": true }\n\
       { \"name\": \"XML\", \"good\": false }";
    test {|.foo[]|} {|{"foo":[1,2,3]}|} "1\n2\n3";
    test {|.[]|} {|{"a": 1, "b": 1}|} "1\n1";
    test {|.[]|} {|[1,2,3]|} "1\n2\n3";
    test {|.[]|} {|[]|} {||};
  ]

let comma =
  [
    test {|1,1|} {|[]|} "1\n1";
    test {|1,.|} {|[]|} "1\n[]";
    test {|.foo, .bar|} {|{"foo": 42, "bar": "something else", "baz": true}|}
      "42\n\"something else\"";
    test {|.user, .projects[]|}
      {|{"user":"stedolan", "projects": ["jq", "wikiflow"]}|}
      "\"stedolan\"\n\"jq\"\n\"wikiflow\"";
  ]

let pipe =
  [
    test {|.[] | .name|}
      {|[{"name":"JSON", "good":true}, {"name":"XML", "good":false}]|}
      "\"JSON\"\n\"XML\"";
  ]

let parenthesis =
  [
    test {|(. + 2) * 5|} {|1|} {|15|};
    test {|[(.,1),((.,.[]),(2,3))]|} {|["a","b"]|}
      {|[ [ "a", "b" ], 1, [ "a", "b" ], "a", "b", 2, 3 ]|};
    test {|[([5,5][]),.,.[]]|} {|[1,2,3]|} {|[ 5, 5, [ 1, 2, 3 ], 1, 2, 3 ]|};
  ]

let array_construction =
  [
    test {|[.]|} {|[2]|} {|[ [ 2 ] ]|};
    test {|[[2]]|} {|[3]|} {|[ [ 2 ] ]|};
    test {|[{}]|} {|[2]|} {|[ {} ]|};
    test {|[.[]]|} {|["a"]|} {|[ "a" ]|};
    test {|[.user, .projects[]]|}
      {|{"user":"stedolan", "projects": ["jq", "wikiflow"]}|}
      {|[ "stedolan", "jq", "wikiflow" ]|};
    test {|[ .[] | . * 2]|} {|[1, 2, 3]|} {|[ 2, 4, 6 ]|};
    test {|[1,2,empty,3,empty,4]|} {|null|} {|[ 1, 2, 3, 4 ]|};
  ]

let object_construction =
  [
    test {|{a: 1}|} {|null|} {|{ "a": 1 }|};
    test {|{user}|} {|null|} {|{ "user": null }|};
    test {|{user}|} {|{"user": 42}|} {|{ "user": 42 }|};
    test {|{user: .foo}|} {|{"user": 42, "foo": "something_else"}|}
      {|{ "user": "something_else" }|};
    test {|{user: {bar: .foo}}|} {|{"user": 42, "foo": "something_else"}|}
      {|{ "user": { "bar": "something_else" } }|};
    test {|{x: (1,2)},{x:3} | .x|} {|null|} "1\n2\n3";
    test {|{user, title: .titles[]}|}
      {|{"user":"stedolan","titles":["JQ Primer", "More JQ"]}|}
      "{ \"user\": \"stedolan\", \"title\": \"JQ Primer\" }\n\
       { \"user\": \"stedolan\", \"title\": \"More JQ\" }";
    test {|{(.user): .titles}|}
      {|{"user":"stedolan","titles":["JQ Primer", "More JQ"]}|}
      {|{ "stedolan": [ "JQ Primer", "More JQ" ] }|};
    test {|[.[] | { name: .name, city: .address.city}]|}
      {|[{"name": "Gilbert", "address": {"city": "Toulouse"}}, {"name": "Alexa", "address": {"city": "Albi"}}]|}
      {|[ { "name": "Gilbert", "city": "Toulouse" }, { "name": "Alexa", "city": "Albi" } ]|};
  ]

let addition =
  [
    test {|1+1|} {|null|} {|2|};
    test {|1+1|} {|"wtasdf"|} {|2|};
    test {|.+4|} {|15|} {|19|};
    test {|[1,2,3] + [.]|} {|null|} {|[ 1, 2, 3, null ]|};
    test {|{"a":1} + {"b":2} + {"c":3}|} {|"asdfasdf"|}
      {|{ "a": 1, "b": 2, "c": 3 }|};
    test {|"asdf" + "jkl;" + . + . + .|} {|"some string"|}
      {|"asdfjkl;some stringsome stringsome string"|};
    test {|.a + 1|} {|{"a": 7}|} {|8|};
    test {|.a + .b|} {|{"a": [1,2], "b": [3,4]}|} {|[ 1, 2, 3, 4 ]|};
    test {|(.a? // 0) + 1|} {|{}|} {|1|};
    test {|{a: 1} + {b: 2} + {c: 3} + {a: 42}|} {|null|}
      {|{ "a": 42, "b": 2, "c": 3 }|};
  ]

let subtraction =
  [
    test {|2-1|} {|null|} {|1|};
    test {|2-(-1)|} {|null|} {|3|};
    test {|42 - .|} {|11|} {|31|};
    test {|[1,2,3,4,1] - [.,3]|} {|1|} {|[ 2, 4 ]|};
    test {|4 - .a|} {|{"a":3}|} {|1|};
    test {|. - ["xml", "yaml"]|} {|["xml", "yaml", "json"]|} {|[ "json" ]|};
  ]

let multiplication_division_modulo =
  [
    test {|[10 * 20, 20 / .]|} {|4|} {|[ 200, 5 ]|};
    test {|1 + 2 * 2 + 10 / 2|} {|null|} {|10|};
    test {|[16 / 4 / 2, 16 / 4 * 2, 16 - 4 - 2, 16 - 4 + 2]|} {|null|}
      {|[ 2, 8, 10, 14 ]|};
    test {|25 % 7|} {|null|} {|4|};
    test {|49732 % 472|} {|null|} {|172|};
    test {|10 % 3|} {|null|} {|1|};
    test {|10 / . * 3|} {|5|} {|6|};
    test {|. / ", "|} {|"a, b,c,d, e"|} {|[ "a", "b,c,d", "e" ]|};
    test {|{"k": {"a": 1, "b": 2}} * {"k": {"a": 0,"c": 3}}|} {|null|}
      {|{ "k": { "a": 0, "b": 2, "c": 3 } }|};
    (* TODO: test {|.[] | (1 / .)?|} {|[1,0,-1]|} {|1|}; *)
  ]

let comparison =
  [
    test {|. < 5|} {|2|} {|true|};
    test {|. > 5|} {|2|} {|false|};
    test {|. <= 5|} {|5|} {|true|};
    test {|. >= 5|} {|5|} {|true|};
  ]

let equality =
  [
    test {|. == false|} {|null|} {|false|};
    test {|. == {"b": {"d": 4, "c": 3}, "a":1}|}
      {|{"a":1, "b": {"c": 3, "d": 4}}|} {|true|};
    test {|.[] == 1|} {|[1, 1.0, "1", "banana"]|} "true\ntrue\nfalse\nfalse";
    (* TODO: test {|. == {"b": {"d": (4 + 1e-20), "c": 3}, "a":1}|} {|{"a":1, "b": {"c": 3, "d": 4}}|} {|true|}; *)
  ]

let boolean_operators =
  [
    test {|true and false|} {|null|} {|false|};
    test {|true or false|} {|null|} {|true|};
    test {|not|} {|true|} {|false|};
    test {|not|} {|false|} {|true|};
    test {|(true, false) or false|} {|null|} "true\nfalse";
    test {|[true, false | not]|} {|null|} {|[ false, true ]|};
    test {|42 and "a string"|} {|null|} {|true|};
    (* TODO: test {|(true, true) and (true, false)|} {|null|} {|true|}; - requires multiple output from both sides of and *)
  ]

let alternative =
  [
    test {|.email // "no-email@example.com"|} {|{"email": "test@example.com"}|}
      {|"test@example.com"|};
    test {|.email // "no-email@example.com"|} {|{"name": "John"}|}
      {|"no-email@example.com"|};
    test {|.email // "no-email@example.com"|} {|{"email": null}|}
      {|"no-email@example.com"|};
    test {|.email // "no-email@example.com"|} {|{"email": false}|}
      {|"no-email@example.com"|};
    test {|.email // "no-email@example.com"|} {|{"email": ""}|} {|""|};
    test {|.count // 0|} {|{"count": 5}|} {|5|};
    test {|.count // 0|} {|{}|} {|0|};
    test {|.value // 10 // 20|} {|{"value": null}|} {|10|};
    test {|.value // 10 // 20|} {|{}|} {|10|};
    test {|empty // 42|} {|null|} {|42|};
    test {|.foo // 42|} {|{"foo": 19}|} {|19|};
    test {|.foo // 42|} {|{}|} {|42|};
    test {|(false, null, 1) // 42|} {|null|} {|1|};
    (* TODO: test {|(false, null, 1) | . // 42|} {|null|} {|42|}; *)
  ]

let update =
  [
    test {|.value |= . * 2|} {|{"value": 5}|} {|{ "value": 10 }|};
    test {|.x |= . + 1|} {|{"x": 10}|} {|{ "x": 11 }|};
    test {|.[] |= . * 2|} {|[1,2,3]|} {|[ 2, 4, 6 ]|};
    (* TODO: test {|(..|select(type=="boolean")) |= if . then 1 else 0 end|} {|[true,false,[5,true,[true,[false]],false]]|} {|[1,0,[5,1,[1,[0]],0]]|}; *)
  ]

let conditionals =
  [
    test {|if false then "h" else 42 end|} {|null|} {|42|};
    test {|if 5 > 10 then 5 elif 5 < 10 then 3 else 2 end|} {|null|} {|3|};
    test {|if . == 0 then "zero" elif . == 1 then "one" else "many" end|} {|2|}
      {|"many"|};
  ]

let try_catch =
  [
    test {|try(.foo)|} {|{"foo": 42}|} {|42|};
    test {|.foo?|} {|{}|} {|null|};
    test {|try(error("test"))|} {|null|} {|null|};
    test {|try .a catch ". is not an object"|} {|true|} {|". is not an object"|};
    test {|try error("some exception") catch .|} {|true|} {|"some exception"|};
    test {|try error("invalid value: \(.)") catch .|} {|42|}
      {|"invalid value: 42"|};
    test {|try error catch .|} {|"error message"|} {|"error message"|};
    test {|try error catch .|} {|33|} {|33|};
    (* $error variable in catch *)
    test {|try error("oops") catch $error.kind|} {|null|} {|"user_error"|};
    test {|try error("oops") catch $error.message|} {|null|} {|"\"oops\""|};
    test {|try error("oops") catch $error.value|} {|null|} {|"oops"|};
    test {|try .foo catch $error.kind|} {|{}|} {|"key_not_found"|};
    (* raise function *)
    test {|try raise("custom"; "my message") catch $error.kind|} {|null|}
      {|"custom"|};
    test {|try raise("custom"; "my message") catch $error.message|} {|null|}
      {|"my message"|};
    test {|try raise("validation"; "bad input") catch $error.value|} {|42|}
      {|42|};
    (* finally clause - value from try/catch is returned, finally runs for side effects *)
    test {|try .foo catch "caught" finally "cleanup"|} {|{"foo": 42}|} {|42|};
    test {|try .foo catch "caught" finally "cleanup"|} {|{}|} {|"caught"|};
    (* Note: try-finally without catch is not supported per LANGUAGE_IMPROVEMENTS.md section 2.3:
       "try" always requires "catch". Use .foo? for optional access instead. *)
  ]

let empty =
  [
    test {|1, empty, 2|} {|null|} "1\n2";
    test {|[1,2,empty,3]|} {|null|} {|[ 1, 2, 3 ]|};
  ]

let range =
  [
    test {|range(0)|} {|null|} {||};
    test {|range(10)|} {|null|} "0\n1\n2\n3\n4\n5\n6\n7\n8\n9";
    test {|range(10;20)|} {|null|} "10\n11\n12\n13\n14\n15\n16\n17\n18\n19";
    test {|range(10;20;2)|} {|null|} "10\n12\n14\n16\n18";
    test {|[range(0;10)]|} {|null|} {|[ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 ]|};
    test {|[range(0;10;3)]|} {|null|} {|[ 0, 3, 6, 9 ]|};
    test {|[range(0;10;-1)]|} {|null|} {|[]|};
    test {|[range(0;-5;-1)]|} {|null|} {|[ 0, -1, -2, -3, -4 ]|};
    test {|[range(0,1;4,5;1,2)]|} {|null|}
      {|[ 0, 1, 2, 3, 0, 2, 0, 1, 2, 3, 4, 0, 2, 4, 1, 2, 3, 1, 3, 1, 2, 3, 4, 1, 3 ]|};
    test {|range(2; 4)|} {|null|} "2\n3";
    test {|[range(2; 4)]|} {|null|} {|[ 2, 3 ]|};
    test {|[range(4)]|} {|null|} {|[ 0, 1, 2, 3 ]|};
  ]

let while_ =
  [ test {|[while(.<100; .*2)]|} {|1|} {|[ 1, 2, 4, 8, 16, 32, 64 ]|} ]

let until =
  [
    test {|[until(.>100; .*2)]|} {|1|} {|[ 128 ]|};
    test {|[.,1]|until(.[0] < 1; [.[0] - 1, .[1] * .[0]])|.[1]|} {|4|} {|24|};
  ]

let recurse =
  [
    test {|[recurse(.+1; . < 5)]|} {|0|} {|[ 0, 1, 2, 3, 4 ]|};
    test {|recurse(. * .; . < 20)|} {|2|} "2\n4\n16";
    (* TODO: test {|recurse(.foo[])|} {|{"foo":[{"foo": []}, {"foo":[{"foo":[]}]}]}|} {|{"foo":[{"foo":[]},{"foo":[{"foo":[]}]}]}|};  *)
    (* TODO: test {|recurse|} {|{"a":0,"b":[1]}|} {|{"a":0,"b":[1]}|}; *)
  ]

let walk =
  [
    test {|walk(if type == "number" then . + 1 else . end)|} {|{"a":1}|}
      {|{ "a": 2 }|};
    test {|walk(if type == "array" then sort else . end)|}
      {|[[4, 1, 7], [8, 5, 2], [3, 6, 9]]|}
      {|[ [ 1, 4, 7 ], [ 2, 5, 8 ], [ 3, 6, 9 ] ]|};
    test
      {|walk( if type == "object" then with_entries( .key |= sub( "^_+"; "") ) else . end )|}
      {|[ { "_a": { "__b": 2 } } ]|} {|[ { "a": { "b": 2 } } ]|};
  ]

let reduce =
  [
    test {|reduce .[] as $x (0; . + $x)|} {|[1,2,3,4,5]|} {|15|};
    test {|reduce .[] as $item (0; . + $item)|} {|[10,20,30]|} {|60|};
    test {|reduce .[] as $x (0; . + $x)|} {|[5]|} {|5|};
    test {|reduce .[] as $item (0; . + $item)|} {|[1,2,3,4,5]|} {|15|};
    (* TODO: test {|reduce .[] as [$i,$j] (0; . + $i * $j)|} {|[[1,2],[3,4],[5,6]]|} {|44|}; *)
    (* TODO: test {|reduce .[] as {$x,$y} (null; .x += $x | .y += [$y])|} {|[{"x":"a","y":1},{"x":"b","y":2},{"x":"c","y":3}]|} {|{"x":"abc","y":[1,2,3]}|}; *)
  ]

let foreach =
  [
    test {|[foreach .[] as $x (0; . + $x; .)]|} {|[1,2,3]|} {|[ 1, 3, 6 ]|};
    test {|[foreach .[] as $x (0; . + $x; .)]|} {|[0,1,2,3,4]|}
      {|[ 0, 1, 3, 6, 10 ]|};
    test {|[foreach .[] as $x (""; . + $x; .)]|} {|["a","b","c"]|}
      {|[ "a", "ab", "abc" ]|};
    test {|foreach .[] as $x (0; . + $x; . * 2)|} {|[1,2,3]|} "2\n6\n12";
    test {|foreach .[] as $item (0; . + $item; [$item, . * 2])|} {|[1,2,3,4,5]|}
      "[ 1, 2 ]\n[ 2, 6 ]\n[ 3, 12 ]\n[ 4, 20 ]\n[ 5, 30 ]";
    test {|foreach .[] as $item (0; . + $item)|} {|[1,2,3,4,5]|}
      "1\n3\n6\n10\n15";
    (* TODO: test {|foreach .[] as $item (0; . + 1; {index: ., $item})|} {|["foo", "bar", "baz"]|} {|{"index":1,"item":"foo"}|}; *)
  ]

let limit =
  [
    test {|limit(3; range(10))|} {|null|} "0\n1\n2";
    test {|limit(2; .[])|} {|[1,2,3,4,5]|} "1\n2";
    test {|[limit(3; range(10))]|} {|null|} {|[ 0, 1, 2 ]|};
    test {|[limit(3; .[])]|} {|[0,1,2,3,4,5,6,7,8,9]|} {|[ 0, 1, 2 ]|};
    test {|[limit(5; infinite)]|} {|null|} {|[ 0, 1, 2, 3, 4 ]|};
  ]

let isempty =
  [
    test {|isempty(empty)|} {|null|} {|true|};
    test {|isempty(.[])|} {|[]|} {|true|};
    test {|isempty(.[])|} {|[1]|} {|false|};
    test {|isempty(.[])|} {|[1,2,3]|} {|false|};
    test {|isempty(range(3))|} {|null|} {|false|};
  ]

let map =
  [
    test {|map(keys)|}
      {|[{}, {"abcd":1,"abc":2,"abcde":3}, {"x":1, "z": 3, "y":2}]|}
      {|[ [], [ "abc", "abcd", "abcde" ], [ "x", "y", "z" ] ]|};
    test {|map(add)|}
      {|[[], [1,2,3], ["a","b","c"], [[3],[4,5],[6]], [{"a":1}, {"b":2}, {"a":3}]]|}
      {|[ null, 6, "abc", [ 3, 4, 5, 6 ], { "a": 3, "b": 2 } ]|};
    test {|map_values(.+1)|} {|[0,1,2]|} {|[ 1, 2, 3 ]|};
    test {|map_values(.+1)|} {|{"a":1,"b":2}|} {|{ "a": 2, "b": 3 }|};
    test {|map(select(. > 2))|} {|[1,2,3,4,5]|} {|[ 3, 4, 5 ]|};
    test {|map(.+1)|} {|[1,2,3]|} {|[ 2, 3, 4 ]|};
    test {|map_values(.+1)|} {|{"a": 1, "b": 2, "c": 3}|}
      {|{ "a": 2, "b": 3, "c": 4 }|};
    test {|map(., .)|} {|[1,2]|} {|[ 1, 1, 2, 2 ]|};
    test {|map_values(. // empty)|} {|{"a": null, "b": true, "c": false}|}
      {|{ "b": true }|};
  ]

let flat_map =
  [
    test {|flat_map(. * 2)|} {|[1,2,3]|} {|[ 2, 4, 6 ]|};
    test {|flat_map([., . * 2])|} {|[1,2]|} {|[ 1, 2, 2, 4 ]|};
  ]

let select =
  [
    test {|map(select(. >= 2))|} {|[1,5,3,0,7]|} {|[ 5, 3, 7 ]|};
    test {|.[] | select(.id == "second")|}
      {|[{"id": "first", "val": 1}, {"id": "second", "val": 2}]|}
      {|{ "id": "second", "val": 2 }|};
  ]

let has =
  [
    test {|has("foo")|} {|{"foo": 42}|} {|true|};
    test {|map(has("foo"))|} {|[{"foo": 42}, {"only_bar": false}]|}
      {|[ true, false ]|};
    test {|map(has("foo"))|} {|[{"foo": 42}, {}]|} {|[ true, false ]|};
    test {|map(has(2))|} {|[[0,1], ["a","b","c"]]|} {|[ false, true ]|};
  ]

let in_ =
  [
    test {|map(in({"foo": 42}))|} {|["foo", "bar"]|} {|[ true, false ]|};
    test {|.[] | in({"foo": 42})|} {|["foo", "bar"]|} "true\nfalse";
    test {|map(in([0,1]))|} {|[2, 0]|} {|[ false, true ]|};
  ]

let type_ =
  [
    test {|type|} {|42|} {|"number"|};
    test {|type|} {|"string"|} {|"string"|};
    test {|map(type)|} {|[1, "a", null]|} {|[ "number", "string", "null" ]|};
    test {|map(type)|} {|[0, false, [], {}, null, "hello"]|}
      {|[ "number", "boolean", "array", "object", "null", "string" ]|};
  ]

let length =
  [
    test {|length|} {|[1,2,3]|} {|3|};
    test {|map(length)|} {|[[], [1,2]]|} {|[ 0, 2 ]|};
    test {|.[] | length|} {|[[1,2], "string", {"a":2}, null, -5]|}
      "2\n6\n1\n0\n5";
  ]

let utf8bytelength =
  [
    test {|utf8bytelength|} {|""|} {|0|};
    test {|utf8bytelength|} {|"µ"|} {|2|};
    (* ASCII is 1 byte per char *)
    test {|utf8bytelength|} {|"hello"|} {|5|};
  ]

let reverse =
  [
    test {|reverse|} {|[1,2,3]|} {|[ 3, 2, 1 ]|};
    test {|reverse|} {|[1,2,3,4]|} {|[ 4, 3, 2, 1 ]|};
  ]

let sort =
  [
    test {|sort|} {|[3,1,2]|} {|[ 1, 2, 3 ]|};
    test {|sort_by(.name)|} {|[{"name":"z"},{"name":"a"}]|}
      {|[ { "name": "a" }, { "name": "z" } ]|};
    test {|sort|} {|[8,3,null,6]|} {|[ null, 3, 6, 8 ]|};
    test {|sort_by(.foo)|}
      {|[{"foo":4, "bar":10}, {"foo":3, "bar":10}, {"foo":2, "bar":1}]|}
      {|[ { "foo": 2, "bar": 1 }, { "foo": 3, "bar": 10 }, { "foo": 4, "bar": 10 } ]|};
    (* TODO: test {|sort_by(.foo, .bar)|} {|[{"foo":4, "bar":10}, {"foo":3, "bar":20}, {"foo":2, "bar":1}, {"foo":3, "bar":10}]|} {|[{"foo":2, "bar":1}, {"foo":3, "bar":10}, {"foo":3, "bar":20}, {"foo":4, "bar":10}]|}; *)
  ]

(* unique, unique_by *)
let unique =
  [
    test {|unique|} {|[1,2,1,3,2]|} {|[ 1, 2, 3 ]|};
    test {|unique_by(.x)|} {|[{"x":1},{"x":2},{"x":1}]|}
      {|[ { "x": 1 }, { "x": 2 } ]|};
    test {|unique_by(.foo)|}
      {|[{"foo": 1, "bar": 2}, {"foo": 1, "bar": 3}, {"foo": 4, "bar": 5}]|}
      {|[ { "foo": 1, "bar": 2 }, { "foo": 4, "bar": 5 } ]|};
    test {|unique_by(length)|}
      {|["chunky", "bacon", "kitten", "cicada", "asparagus"]|}
      {|[ "chunky", "bacon", "asparagus" ]|};
  ]

let min_max =
  [
    test {|min|} {|[1,2,3]|} {|1|};
    test {|max|} {|[1,2,3]|} {|3|};
    test {|min_by(.x)|} {|[{"x":2},{"x":1}]|} {|{ "x": 1 }|};
    test {|min|} {|[5,4,2,7]|} {|2|};
    test {|max_by(.foo)|} {|[{"foo":1, "bar":14}, {"foo":2, "bar":3}]|}
      {|{ "foo": 2, "bar": 3 }|};
  ]

let group_by =
  [
    test {|group_by(.x)|} {|[{"x":1},{"x":2},{"x":1}]|}
      {|{ "1": [ { "x": 1 }, { "x": 1 } ], "2": [ { "x": 2 } ] }|};
    test {|group_by(.foo)|}
      {|[{"foo":1, "bar":10}, {"foo":3, "bar":100}, {"foo":1, "bar":1}]|}
      {|{ "1": [ { "foo": 1, "bar": 10 }, { "foo": 1, "bar": 1 } ], "3": [ { "foo": 3, "bar": 100 } ] }|};
    test {|group_by(.type)|}
      {|[{"type":"a","v":1},{"type":"b","v":2},{"type":"a","v":3}]|}
      {|{ "a": [ { "type": "a", "v": 1 }, { "type": "a", "v": 3 } ], "b": [ { "type": "b", "v": 2 } ] }|};
    test {|group_by(.x)."1"|} {|[{"x":1},{"x":2},{"x":1}]|}
      {|[ { "x": 1 }, { "x": 1 } ]|};
    test {|group_by(.active)|}
      {|[{"active":true},{"active":false},{"active":true}]|}
      {|{ "false": [ { "active": false } ], "true": [ { "active": true }, { "active": true } ] }|};
  ]

let any_all =
  [
    test {|any|} {|[true, false]|} {|true|};
    test {|all|} {|[true, true]|} {|true|};
    test {|all|} {|[true, false]|} {|false|};
    test {|any|} {|[false, false]|} {|false|};
    test {|any|} {|[]|} {|false|};
    test {|all|} {|[]|} {|true|};
    test {|any(. > 2)|} {|[1,2,3]|} {|true|};
    test {|any(. > 10)|} {|[1,2,3]|} {|false|};
    test {|all(. > 0)|} {|[1,2,3]|} {|true|};
    test {|all(. > 2)|} {|[1,2,3]|} {|false|};
  ]

let some_find =
  [
    test {|some(. > 2)|} {|[1,2,3]|} {|true|};
    test {|some(. > 10)|} {|[1,2,3]|} {|false|};
    test {|find(. > 2)|} {|[1,2,3,4]|} {|3|};
    test {|find(. > 10)|} {|[1,2,3]|} {|null|};
  ]

let flatten =
  [
    test {|flatten|} {|[[1,2],[3,4]]|} {|[ 1, 2, 3, 4 ]|};
    test {|flatten(1)|} {|[[[1,2]],[[3,4]]]|} {|[ [ 1, 2 ], [ 3, 4 ] ]|};
    test {|flatten(3,2,1)|} {|[0, [1], [[2]], [[[3]]]]|}
      "[ 0, 1, 2, 3 ]\n[ 0, 1, 2, [ 3 ] ]\n[ 0, 1, [ 2 ], [ [ 3 ] ] ]";
    test {|flatten|} {|[[]]|} {|[]|};
    test {|flatten|} {|[{"foo": "bar"}, [{"foo": "baz"}]]|}
      {|[ { "foo": "bar" }, { "foo": "baz" } ]|};
  ]

let transpose =
  [
    test {|transpose|} {|[[1,2],[3,4]]|} {|[ [ 1, 3 ], [ 2, 4 ] ]|};
    test {|transpose|} {|[[1,2,3],[4,5,6]]|}
      {|[ [ 1, 4 ], [ 2, 5 ], [ 3, 6 ] ]|};
    test {|transpose|} {|[]|} {|[]|};
    test {|transpose|} {|[[1], [2,3]]|} {|[ [ 1, 2 ], [ null, 3 ] ]|};
  ]

let add =
  [
    test {|add|} {|["a","b","c"]|} {|"abc"|};
    test {|add|} {|[1, 2, 3]|} {|6|};
    test {|add|} {|[]|} {|null|};
    test {|[.[] | select(has("a")) | .a] | add|} {|[{"a":3}, {"a":5}, {"b":6}]|}
      {|8|};
  ]

(* to_entries, from_entries, with_entries(f) *)
let entries =
  [
    test {|to_entries|} {|{"a":1,"b":2}|}
      {|[ { "key": "a", "value": 1 }, { "key": "b", "value": 2 } ]|};
    test {|from_entries|} {|[{"key":"a","value":1}]|} {|{ "a": 1 }|};
    test {|from_entries|} {|[{"key":"a", "value":1}, {"key":"b", "value":2}]|}
      {|{ "a": 1, "b": 2 }|};
    test {|with_entries(.value |= . * 2)|} {|{"a": 1, "b": 2, "c": 3}|}
      {|{ "a": 2, "b": 4, "c": 6 }|};
    test {|with_entries(.value |= . + 1)|} {|{"x": 10, "y": 20}|}
      {|{ "x": 11, "y": 21 }|};
    test {|with_entries(.key |= . + "_suffix")|} {|{"a": 1, "b": 2}|}
      {|{ "a_suffix": 1, "b_suffix": 2 }|};
    test {|with_entries(.value |= if . > 5 then . * 2 else . end)|}
      {|{"a": 3, "b": 10}|} {|{ "a": 3, "b": 20 }|};
    test {|with_entries(.key |= "KEY_" + .)|} {|{"a": 1, "b": 2}|}
      {|{ "KEY_a": 1, "KEY_b": 2 }|};
  ]

let contains =
  [
    test {|contains("foo")|} {|"foobar"|} {|true|};
    test {|contains([2])|} {|[1,2,3]|} {|true|};
    test {|contains("bar")|} {|"foobar"|} {|true|};
    test {|contains(["bazzzzz", "bar"])|} {|["foobar", "foobaz", "blarp"]|}
      {|false|};
    test {|contains(["baz", "bar"])|} {|["foobar", "foobaz", "blarp"]|} {|true|};
    test {|contains({foo: 12, bar: [{barp: 12}]})|}
      {|{"foo": 12, "bar":[1,2,{"barp":12, "blip":13}]}|} {|true|};
    test {|contains({foo: 12, bar: [{barp: 15}]})|}
      {|{"foo": 12, "bar":[1,2,{"barp":12, "blip":13}]}|} {|false|};
  ]

let inside =
  [
    test {|inside("foobar")|} {|"bar"|} {|true|};
    test {|inside(["foobar", "foobaz", "blarp"])|} {|["baz", "bar"]|} {|true|};
    test {|inside(["foobar", "foobaz", "blarp"])|} {|["bazzzzz", "bar"]|}
      {|false|};
    test {|inside({"foo": 12, "bar":[1,2,{"barp":12, "blip":13}]})|}
      {|{"foo": 12, "bar": [{"barp": 12}]}|} {|true|};
    test {|inside({"foo": 12, "bar":[1,2,{"barp":12, "blip":13}]})|}
      {|{"foo": 12, "bar": [{"barp": 15}]}|} {|false|};
  ]

let startswith_endswith =
  [
    test {|starts_with("Hello")|} {|"Hello, world"|} {|true|};
    test {|ends_with("world")|} {|"Hello, world"|} {|true|};
    test {|[.[]|starts_with("foo")]|}
      {|["fo", "foo", "barfoo", "foobar", "barfoob"]|}
      {|[ false, true, false, true, false ]|};
    test {|[.[]|ends_with("foo")]|} {|["foobar", "barfoo"]|} {|[ false, true ]|};
  ]

let trimstr =
  [
    test {|[.[]|ltrimstr("foo")]|} {|["fo", "foo", "barfoo", "foobar", "afoo"]|}
      {|[ "fo", "", "barfoo", "bar", "afoo" ]|};
    test {|[.[]|rtrimstr("foo")]|} {|["fo", "foo", "barfoo", "foobar", "foob"]|}
      {|[ "fo", "", "bar", "foobar", "foob" ]|};
    (* TODO: test {|[.[]|trimstr("foo")]|} ... - trimstr (both ends) not implemented *)
  ]

let trim =
  [
    test {|trim|} {|" abc "|} {|"abc"|};
    test {|ltrim|} {|" abc "|} {|"abc "|};
    test {|rtrim|} {|" abc "|} {|" abc"|};
    test {|trim|} {|"  \t\n hello \r\n  "|} {|"hello"|};
  ]

let ascii_case =
  [
    test {|ascii_upcase|} {|"useful but not for é"|} {|"USEFUL BUT NOT FOR é"|};
  ]

let split_join =
  [
    test {|split(",")|} {|"Hello,world,ignore"|}
      {|[ "Hello", "world", "ignore" ]|};
    test {|join(",")|} {|[ "Hello", "world", "ignore" ]|}
      {|"Hello,world,ignore"|};
    test {|join(", ")|} {|["a","b,c,d","e"]|} {|"a, b,c,d, e"|};
    test {|split(", ")|} {|"a, b,c,d, e, "|} {|[ "a", "b,c,d", "e", "" ]|};
    test {|join(" ")|} {|["a",1,2.3,true,null,false]|} {|"a 1 2.3 true false"|};
  ]

let explode_implode =
  [
    test {|explode|} {|"hello"|} {|[ 104, 101, 108, 108, 111 ]|};
    test {|implode|} {|[72,101,108,108,111]|} {|"Hello"|};
    test {|explode|} {|"foobar"|} {|[ 102, 111, 111, 98, 97, 114 ]|};
    test {|implode|} {|[65, 66, 67]|} {|"ABC"|};
  ]

let index =
  [
    test {|index("b")|} {|"abc"|} {|1|};
    test {|rindex("b")|} {|"abcb"|} {|3|};
    test {|index(", ")|} {|"a,b, cd, efg, hijk"|} {|3|};
    test {|rindex(", ")|} {|"a,b, cd, efg, hijk"|} {|12|};
    test {|index(1)|} {|[0,1,2,1,3,1,4]|} {|1|};
    test {|index([1,2])|} {|[0,1,2,3,1,4,2,5,1,2,6,7]|} {|1|};
    test {|rindex(1)|} {|[0,1,2,1,3,1,4]|} {|5|};
    test {|rindex([1,2])|} {|[0,1,2,3,1,4,2,5,1,2,6,7]|} {|8|};
    test {|indices(", ")|} {|"a,b, cd, efg, hijk"|} {|[ 3, 7, 12 ]|};
    test {|indices(1)|} {|[0,1,2,1,3,1,4]|} {|[ 1, 3, 5 ]|};
    test {|indices([1,2])|} {|[0,1,2,3,1,4,2,5,1,2,6,7]|} {|[ 1, 8 ]|};
  ]

let math_abs =
  [
    test {|abs|} {|-42|} {|42|};
    test {|.[] | abs|} {|[-1, -2, 3]|} "1\n2\n3";
    test {|map(abs)|} {|[-10, -1.1, -0.1]|} {|[ 10, 1.1, 0.1 ]|};
  ]

(* Math functions: floor, ceil, round *)
let math_floor_ceil_round =
  [
    test {|floor|} {|3.7|} {|3|};
    test {|floor|} {|3.14159|} {|3|};
    test {|ceil|} {|3.2|} {|4|};
    test {|round|} {|3.7|} {|4|};
  ]

let math_sqrt = [ test {|sqrt|} {|16|} {|4|}; test {|sqrt|} {|9|} {|3|} ]
let math_log_exp = [ test {|log10|} {|100|} {|2|}; test {|exp|} {|0|} {|1|} ]

let math_trig =
  [
    test {|sin|} {|0|} {|0|};
    test {|cos|} {|0|} {|1|};
    test {|tan|} {|0|} {|0|};
    test {|asin|} {|0|} {|0|};
    test {|acos|} {|1|} {|0|};
    test {|atan|} {|0|} {|0|};
    (* test {|atan(1; 1)|} {|null|} {|0.7853981633974483|}; *)
  ]

let nan_infinite =
  [
    test {|is_nan|} {|42|} {|false|};
    test {|is_nan|} {|42.5|} {|false|};
    (* The following tests use `infinite` which in this implementation
       is an infinite generator (0,1,2,...) for use with limit, NOT the IEEE
       infinity float. These tests from jq manual are incompatible and hang:
       test {|.[] | (infinite * .) < 0|} {|[-1, 1]|} {|true|};
       test {|infinite, nan | type|} {|null|} {|"number"|};
    *)
  ]

(* tonumber, to_number *)
let tonumber =
  [
    test {|to_number|} {|"42"|} {|42|};
    test {|.[] | to_number|} {|[1, "1"]|} "1\n1";
  ]

let toboolean =
  [ (* TODO: test {|.[] | toboolean|} {|["true", "false", true, false]|} {|true|}; *) ]

let tostring =
  [
    test {|to_string|} {|42|} {|"42"|};
    test {|.[] | to_string|} {|[1, "1", [1]]|} "\"1\"\n\"1\"\n\"[ 1 ]\"";
    test {|[.[]|to_string]|} {|[1, "foo", ["foo"]]|}
      {|[ "1", "foo", "[ \"foo\" ]" ]|};
  ]

let string_interpolation =
  [
    test {|"Hello, \(.name)! You are \(.age) years old."|}
      {|{"name": "Alice", "age": 30}|} {|"Hello, Alice! You are 30 years old."|};
    test {|"Array: \(.)"|} {|[1,2,3]|} {|"Array: [ 1, 2, 3 ]"|};
    test {|"The value of x is \(.x) and the object is \(.)"|} {|{"x": 10}|}
      {|"The value of x is 10 and the object is { \"x\": 10 }"|};
    test {|"\(.) * 2 = \(. * 2)"|} {|5|} {|"5 * 2 = 10"|};
    test {|"The input was \(.), which is one less than \(.+1)"|} {|42|}
      {|"The input was 42, which is one less than 43"|};
  ]

let template_literals =
  [
    (* Basic template literal *)
    test {|`Hello, ${.name}!`|} {|{"name": "world"}|} {|"Hello, world!"|};
    (* Multiple interpolations *)
    test {|`${.a} + ${.b} = ${.a + .b}`|} {|{"a": 2, "b": 3}|} {|"2 + 3 = 5"|};
    (* Template literal without interpolation *)
    test {|`plain string`|} {|null|} {|"plain string"|};
    (* Escaped characters in template *)
    test {|`line1\nline2`|} {|null|} {|"line1\nline2"|};
    (* Template with complex expression *)
    test {|`Items: ${.items | map(to_string) | join(", ")}`|}
      {|{"items": [1, 2, 3]}|} {|"Items: 1, 2, 3"|};
    (* Nested braces in expression *)
    test {|`Result: ${{"value": .x}.value}`|} {|{"x": 42}|} {|"Result: 42"|};
    (* Empty template *)
    test {|``|} {|null|} {|""|};
    (* Template with only interpolation - strings are not re-quoted *)
    test {|`${.}`|} {|"hello"|} {|"hello"|};
  ]

let regex_test =
  [
    test {|test("^hello")|} {|"hello world"|} {|true|};
    test {|test("^hello")|} {|"world hello"|} {|false|};
    test {|test("[0-9]+")|} {|"abc123def"|} {|true|};
    test {|test("foo")|} {|"foo"|} {|true|};
    (* TODO: test {|.[] | test("a b c # spaces are ignored"; "ix")|} {|["xabcd", "ABC"]|} {|true|}; *)
  ]

let regex_match =
  [
    test {|match("foo")|} {|"foo bar foo"|}
      {|{ "offset": 0, "length": 3, "string": "foo", "captures": [] }|};
    (* TODO: test {|match("(abc)+"; "g")|} {|"abc abc"|} {|{"offset": 0, "length": 3, "string": "abc", "captures": [{"offset": 0, "length": 3, "string": "abc", "name": null}]}|}; *)
    (* TODO: test {|match(["foo", "ig"])|} {|"foo bar FOO"|} {|{"offset": 0, "length": 3, "string": "foo", "captures": []}|}; *)
    (* TODO: test {|match("foo (?<bar123>bar)? foo"; "ig")|} {|"foo bar foo foo foo"|} {|{"offset": 0, "length": 11, "string": "foo bar foo", "captures": [{"offset": 4, "length": 3, "string": "bar", "name": "bar123"}]}|}; *)
    (* TODO: test {|[ match("."; "g")] | length|} {|"abc"|} {|3|}; *)
  ]

let regex_capture =
  [ (* TODO: test {|capture("(?<a>[a-z]+)-(?<n>[0-9]+)")|} {|"xyzzy-14"|} {|{ "a": "xyzzy", "n": "14" }|}; *) ]

let regex_sub_gsub =
  [
    test {|sub("world"; "universe")|} {|"hello world"|} {|"hello universe"|};
    test {|gsub("l"; "L")|} {|"hello"|} {|"heLLo"|};
    (* TODO: test {|sub("[^a-z]*(?<x>[a-z]+)"; "Z\(.x)"; "g")|} {|"123abc456def"|} {|"ZabcZdef"|}; *)
    (* TODO: test {|[sub("(?<a>.)"; "\(.a|ascii_upcase)", "\(.a|ascii_downcase)")]|} {|"aB"|} {|["AB","aB"]|}; *)
    (* TODO: test {|gsub("(?<x>.)[^a]*"; "+\(.x)-")|} {|"Abcabc"|} {|"+A-+a-"|}; *)
    (* TODO: test {|[gsub("p"; "a", "b")]|} {|"p"|} {|["a","b"]|}; *)
  ]

let regex_scan =
  [
    test {|scan("[0-9]+")|} {|"abc123def456"|} "\"123\"\n\"456\"";
    test {|[scan("[a-z]+")]|} {|"hello world test"|}
      {|[ "hello", "world", "test" ]|};
    test {|scan("c")|} {|"abcdefabc"|} "\"c\"\n\"c\"";
    (* TODO: test {|scan("(a+)(b+)")|} {|"abaabbaaabbb"|} {|["a","b"]|}; *)
  ]

let regex_split =
  [ (* TODO: test {|split(", *"; null)|} {|"ab,cd, ef"|} {|["ab","cd","ef"]|}; *) ]

let regex_splits =
  [ (* TODO: test {|splits(", *")|} {|"ab,cd, ef, gh"|} {|"ab"|}; *)
    (* TODO: test {|splits(",? *"; "n")|} {|"ab,cd ef, gh"|} {|"ab"|}; *) ]

let path =
  [
    test {|path(.foo)|} {|{"foo": 1}|} {|[ "foo" ]|};
    test {|paths|} {|{"a": {"b": 1}}|} "[ \"a\" ]\n[ \"a\", \"b\" ]";
    test {|[paths]|} {|[1,[],{"a":2}]|} {|[ [ 0 ], [ 1 ], [ 2 ], [ 2, "a" ] ]|};
    test {|[paths(type == "number")]|} {|[1,[],{"a":2}]|}
      {|[ [ 0 ], [ 2, "a" ] ]|};
    test {|get_path(["a", "b"])|} {|{"a": {"b": 42}}|} {|42|};
    test {|get_path(["a","b"])|} {|null|} {|null|};
    test {|set_path(["a", "b"]; 99)|} {|{"a": {"b": 42}}|}
      {|{ "a": { "b": 99 } }|};
    test {|set_path(["x"]; 1)|} {|{}|} {|{ "x": 1 }|};
    test {|set_path(["a","b"]; 1)|} {|null|} {|{ "a": { "b": 1 } }|};
    test {|set_path(["a","b"]; 1)|} {|{"a":{"b":0}}|} {|{ "a": { "b": 1 } }|};
    (* TODO: test {|[path(..)]|} {|{"a":[{"b":1}]}|} {|[ [], [ "a" ], [ "a", 0 ], [ "a", 0, "b" ] ]|}; *)
    test {|set_path([0,"a"]; 1)|} {|null|} {|[ { "a": 1 } ]|};
    (* TODO: test {|[get_path(["a","b"], ["a","c"])]|} {|{"a":{"b":0, "c":1}}|} {|[0, 1]|}; *)
  ]

let delpaths =
  [
    test {|delete_paths([["a","b"]])|} {|{"a":{"b":1},"x":{"y":2}}|}
      {|{ "a": {}, "x": { "y": 2 } }|};
  ]

let del =
  [
    test {|del(.foo)|} {|{"foo": 1, "bar": 2}|} {|{ "bar": 2 }|};
    test {|del(.[0])|} {|[1,2,3]|} {|[ 2, 3 ]|};
    test {|del(.foo)|} {|{"foo": 42, "bar": 9001, "baz": 42}|}
      {|{ "bar": 9001, "baz": 42 }|};
    test {|del(.[1, 2])|} {|["foo", "bar", "baz"]|} {|[ "foo" ]|};
  ]

let object_index_brackets =
  [
    test {|.["foo"]|} {|{"foo": 42}|} {|42|};
    test {|.["foo"]?|} {|{"foo": 42}|} {|42|};
    test {|[.foo?]|} {|[1,2]|} {|[ null ]|};
  ]

let recursive_descent =
  [
    (* Basic recursive descent - outputs all values *)
    test {|[.. | numbers]|} {|{"a":1,"b":{"c":2}}|} {|[ 1, 2 ]|};
    test {|[.. | strings]|} {|{"a":"x","b":["y"]}|} {|[ "x", "y" ]|};
    test {|[.. | .a? | select(. != null)]|} {|[[{"a":1}]]|} {|[ 1 ]|};
  ]

let type_selectors =
  [
    test {|.[]|numbers|} {|[[],{},1,"foo",null,true,false]|} {|1|};
    test {|.[]|strings|} {|[[],{},1,"foo",null,true,false]|} {|"foo"|};
    test {|.[]|booleans|} {|[[],{},1,"foo",null,true,false]|} "true\nfalse";
    test {|.[]|nulls|} {|[[],{},1,"foo",null,true,false]|} {|null|};
    test {|.[]|arrays|} {|[[],{},1,"foo",null,true,false]|} {|[]|};
    test {|.[]|objects|} {|[[],{},1,"foo",null,true,false]|} {|{}|};
    test {|.[]|iterables|} {|[[],{},1,"foo",null,true,false]|} "[]\n{}";
    test {|.[]|scalars|} {|[[],{},1,"foo",null,true,false]|}
      "1\n\"foo\"\nnull\ntrue\nfalse";
    test {|.[]|values|} {|[[],{},1,"foo",null,true,false]|}
      "[]\n{}\n1\n\"foo\"\ntrue\nfalse";
  ]

let variable_binding =
  [
    test {|(.bar as $x | .foo | . + $x)|} {|{"foo":10, "bar":200}|} {|210|};
    test {|(. as $i | [(.*2 | (. as $i | $i)), $i])|} {|5|} {|[ 10, 5 ]|};
    (* TODO: test {|. as [$a, $b, {c: $c}] | $a + $b + $c|} {|[2, 3, {"c": 4, "d": 5}]|} {|9|}; - pattern destructuring *)
    (* TODO: test {|.[] as [$a, $b] | {a: $a, b: $b}|} {|[[0], [0, 1], [2, 1, 0]]|} {|{"a":0,"b":null}|}; - pattern destructuring *)
  ]

let destructuring_alternative =
  [ (* TODO: test {|.[] as {$a, $b, c: {$d, $e}} ?// {$a, $b, c: [{$d, $e}]} | {$a, $b, $d, $e}|} {|[{"a": 1, "b": 2, "c": {"d": 3, "e": 4}}, {"a": 1, "b": 2, "c": [{"d": 3, "e": 4}]}]|} {|{"a":1,"b":2,"d":3,"e":4}|}; *)
    (* TODO: test {|.[] as {$a, $b, c: {$d}} ?// {$a, $b, c: [{$e}]} | {$a, $b, $d, $e}|} {|[{"a": 1, "b": 2, "c": {"d": 3, "e": 4}}, {"a": 1, "b": 2, "c": [{"d": 3, "e": 4}]}]|} {|{"a":1,"b":2,"d":3,"e":null}|}; *)
    (* TODO: test {|.[] as [$a] ?// [$b] | if $a != null then error("err: \($a)") else {$a,$b} end|} {|[[3]]|} {|{"a":null,"b":3}|}; *) ]

let optional_operator =
  [
    test {|[.[] | .a?]|} {|[{}, true, {"a":1}]|} {|[ null, null, 1 ]|};
    (* TODO: test {|[.[] | to_number?]|} {|["1", "invalid", "3", 4]|} {|[ 1, 3, 4 ]|}; - requires parser support for expr? *)
  ]

let arithmetic_update =
  [
    test {|.foo += 1|} {|{"foo": 42}|} {|{ "foo": 43 }|};
    test {|.foo -= 2|} {|{"foo": 42}|} {|{ "foo": 40 }|};
    test {|.foo *= 2|} {|{"foo": 21}|} {|{ "foo": 42 }|};
    test {|.foo /= 2|} {|{"foo": 42}|} {|{ "foo": 21 }|};
    (* //= works when field exists with non-null/false value - keeps original *)
    test {|.foo //= 10|} {|{"foo": 42}|} {|{ "foo": 42 }|};
    test {|.foo //= 10|} {|{"foo": false}|} {|{ "foo": 10 }|};
  ]

let keys =
  [
    test {|keys|} {|[42,3,35]|} {|[ 0, 1, 2 ]|};
    test {|keys|} {|{"abc": 1, "abcd": 2, "Foo": 3}|}
      {|[ "Foo", "abc", "abcd" ]|};
  ]

let pick =
  [
    test {|pick(.a, .b.c, .x)|} {|{"a": 1, "b": {"c": 2, "d": 3}, "e": 4}|}
      {|{ "a": 1, "b": { "c": 2 }, "x": null }|};
    test {|pick(.[2], .[0], .[0])|} {|[1,2,3,4]|} {|[ 1, null, 3 ]|};
  ]

let combinations =
  [
    test {|combinations|} {|[[1,2], [3, 4]]|}
      {|[ 1, 3 ]
[ 1, 4 ]
[ 2, 3 ]
[ 2, 4 ]|};
    test {|combinations(2)|} {|[0, 1]|} {|[ 0, 0 ]
[ 0, 1 ]
[ 1, 0 ]
[ 1, 1 ]|};
  ]

let repeat =
  [
    test {|[limit(5; repeat(. * 2))]|} {|1|} {|[ 2, 4, 8, 16, 32 ]|};
    (* TODO: test {|[repeat(.*2, error)?]|} {|1|} {|[2]|}; - requires ? postfix on expressions *)
  ]

let loc =
  [ (* TODO: test {|try error("\($__loc__)") catch .|} {|null|} {|"{\"file\":\"<top-level>\",\"line\":1}"|};  *) ]

let env =
  [
    (* Test that env and $ENV both work - use HOME which should exist *)
    test {|$ENV.HOME != null|} {|null|} {|true|};
    test {|env.HOME != null|} {|null|} {|true|};
  ]

let bsearch =
  [
    test {|bsearch(0)|} {|[0,1]|} {|0|};
    test {|bsearch(0)|} {|[1,2,3]|} {|-1|};
    (* TODO: test {|bsearch(4) as $ix | if $ix < 0 then .[-(1+$ix)] = 4 else . end|} {|[1,2,3]|} {|[1,2,3,4]|}; *)
  ]

let date =
  [ (* TODO: test {|fromdate|} {|"2015-03-05T23:51:47Z"|} {|1425599507|}; *)
    (* TODO: test {|strptime("%Y-%m-%dT%H:%M:%SZ")|} {|"2015-03-05T23:51:47Z"|} {|[2015,2,5,23,51,47,4,63]|}; *)
    (* TODO: test {|strptime("%Y-%m-%dT%H:%M:%SZ")|mktime|} {|"2015-03-05T23:51:47Z"|} {|1425599507|}; *) ]

let assignment =
  [
    test {|.a = .b|} {|{"a": {"b": 10}, "b": 20}|} {|{ "a": 20, "b": 20 }|};
    test {|.a |= .b|} {|{"a": {"b": 10}, "b": 20}|} {|{ "a": 10, "b": 20 }|};
    test {|(.a, .b) = range(3)|} {|null|} {|{ "a": 0, "b": 0 }|};
    test {|(.a, .b) |= range(3)|} {|null|} {|{ "a": 0, "b": 0 }|};
  ]

let defining_functions =
  [
    test {|fn addvalue(f): . + [f]; map(addvalue(.[0]))|} {|[[1,2],[10,20]]|}
      {|[ [ 1, 2, 1 ], [ 10, 20, 10 ] ]|};
    (* as-binding requires parentheses in our parser: (f as $x | body) *)
    test {|fn addvalue(f): (f as $x | map(. + $x)); addvalue(.[0])|}
      {|[[1,2],[10,20]]|} {|[ [ 1, 2, 1, 2 ], [ 10, 20, 1, 2 ] ]|};
    (* fn keyword - def is deprecated *)
    test {|fn double: . * 2; 5 | double|} {|null|} {|10|};
    test {|fn addto(x): . + x; 3 | addto(4)|} {|null|} {|7|};
    test {|fn greet(name): "Hello, \(name)!"; "World" | greet(.)|} {|null|}
      {|"Hello, World!"|};
  ]

let skip =
  [
    test {|[skip(3; .[])]|} {|[0,1,2,3,4,5,6,7,8,9]|}
      {|[ 3, 4, 5, 6, 7, 8, 9 ]|};
    test {|[skip(0; .[])]|} {|[1,2,3]|} {|[ 1, 2, 3 ]|};
    test {|[skip(5; .[])]|} {|[1,2,3]|} {|[]|};
  ]

let first_last_nth =
  [
    test {|[first(range(.)), last(range(.)), nth(5; range(.))]|} {|10|}
      {|[ 0, 9, 5 ]|};
    (* TODO: first?(expr) syntax requires parser support - see LANGUAGE_IMPROVEMENTS.md section 1.4
       test {|[first?(empty), last?(empty), nth?(5; empty)]|} {|null|}
       {|[ null, null, null ]|};
    *)
    (* TODO: test {|[range(.)]|[first, last, nth(5)]|} {|10|} {|[0,9,5]|}; *)
  ]

let generators_iterators =
  [ (* TODO: test {|fn range(init; upto; by): fn _range: if (by > 0 and . < upto) or (by < 0 and . > upto) then ., ((.+by)|_range) else empty end; if init == upto then empty elif by == 0 then init else init|_range end; range(0; 10; 3)|} {|null|} {|0|}; *)
    (* TODO: test {|fn while(cond; update): fn _while: if cond then ., (update | _while) else empty end; _while; [while(.<100; .*2)]|} {|1|} {|[1,2,4,8,16,32,64]|}; *) ]

let decimal_number =
  [ (* TODO: test {|.|} {|0.12345678901234567890123456789|} {|0.12345678901234567890123456789|}; *)
    (* TODO: test {|[., tojson] == if have_decnum then [12345678909876543212345,"12345678909876543212345"] else [12345678909876543000000,"12345678909876543000000"] end|} {|12345678909876543212345|} {|true|}; *)
    (* TODO: test {|[1234567890987654321,-1234567890987654321 | tojson] == if have_decnum then ["1234567890987654321","-1234567890987654321"] else ["1234567890987654400","-1234567890987654400"] end|} {|null|} {|true|}; *)
    (* TODO: test {|. < 0.12345678901234567890123456788|} {|0.12345678901234567890123456789|} {|false|}; - passes but depends on bignum *)
    (* TODO: test {|map([., . == 1]) | tojson == if have_decnum then "[[1,true],[1.000,true],[1.0,true],[1.00,true]]" else "[[1,true],[1,true],[1,true],[1,true]]" end|} {|[1, 1.000, 1.0, 100e-2]|} {|true|}; *)
    (* TODO: test {|. as $big | [$big, $big + 1] | map(. > 10000000000000000000000000000000) | . == if have_decnum then [true, false] else [false, false] end|} {|10000000000000000000000000000001|} {|true|}; *) ]

let tobase =
  [
    test
      {|fn tobase($b; $digits):
          fn mod: . % $b;
          fn div: ((. - mod) / $b);
          fn getdigits: recurse(select(. >= $b) | div) | mod;
          fn getchar: (. as $i | $digits[$i]);
          select(2 <= $b and $b <= 36)
          | [getdigits] | map(getchar) | reverse | add;
        42 | tobase(2; "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ" | split(""))|}
      {|null|} {|"101010"|};
    test
      {|fn tobase($b; $digits):
          fn mod: . % $b;
          fn div: ((. - mod) / $b);
          fn getdigits: recurse(select(. >= $b) | div) | mod;
          fn getchar: (. as $i | $digits[$i]);
          select(2 <= $b and $b <= 36)
          | [getdigits] | map(getchar) | reverse | add;
        255 | tobase(16; "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ" | split(""))|}
      {|null|} {|"FF"|};
    test
      {|fn tobase($b; $digits):
          fn mod: . % $b;
          fn div: ((. - mod) / $b);
          fn getdigits: recurse(select(. >= $b) | div) | mod;
          fn getchar: (. as $i | $digits[$i]);
          select(2 <= $b and $b <= 36)
          | [getdigits] | map(getchar) | reverse | add;
        64 | tobase(8; "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ" | split(""))|}
      {|null|} {|"100"|};
  ]

let cumulative_sum =
  [
    test
      {|fn running_total: reduce .[] as $x ([]; . + [((. | last) // 0) + $x]);
        [1,2,3,4,5] | running_total|}
      {|null|} {|[ 1, 3, 6, 10, 15 ]|};
    test {|reduce .[] as $item (0; . + $item.value)|}
      {|[{"value": 10}, {"value": 20}, {"value": 30}]|} {|60|};
    test {|[foreach .[] as $x (0; . + $x; .)]|} {|[1,2,3,4,5]|}
      {|[ 1, 3, 6, 10, 15 ]|};
  ]

let flatten_nested =
  [
    test {|[.. | numbers]|} {|{"a": 1, "b": {"c": 2, "d": {"e": 3}}}|}
      {|[ 1, 2, 3 ]|};
    test {|[.. | strings]|}
      {|{"name": "foo", "nested": {"title": "bar", "items": ["a", "b"]}}|}
      {|[ "foo", "bar", "a", "b" ]|};
    test {|flatten|} {|[[1, 2], [3, [4, 5]], 6]|} {|[ 1, 2, 3, 4, 5, 6 ]|};
    test {|flatten(1)|} {|[[1, 2], [3, [4, 5]], 6]|}
      {|[ 1, 2, 3, [ 4, 5 ], 6 ]|};
  ]

let walk_transforms =
  [
    test {|walk(if type == "number" then . * 2 else . end)|}
      {|{"a": 1, "b": {"c": 2}}|} {|{ "a": 2, "b": { "c": 4 } }|};
    test
      {|walk(if type == "object" then with_entries(.key |= ascii_upcase) else . end)|}
      {|{"foo": {"bar": 1}}|} {|{ "FOO": { "BAR": 1 } }|};
    test
      {|walk(if type == "object" then with_entries(select(.value != null)) else . end)|}
      {|{"a": 1, "b": null, "c": {"d": null, "e": 2}}|}
      {|{ "a": 1, "c": { "e": 2 } }|};
  ]

let group_aggregate =
  [
    test
      {|group_by(.category) | to_entries | map({category: .key, count: (.value | length)})|}
      {|[{"category": "A", "val": 1}, {"category": "B", "val": 2}, {"category": "A", "val": 3}]|}
      {|[ { "category": "A", "count": 2 }, { "category": "B", "count": 1 } ]|};
    test
      {|group_by(.category) | to_entries | map({category: .key, total: (.value | map(.val) | add)})|}
      {|[{"category": "A", "val": 10}, {"category": "B", "val": 20}, {"category": "A", "val": 30}]|}
      {|[ { "category": "A", "total": 40 }, { "category": "B", "total": 20 } ]|};
    test
      {|group_by(.region) | to_entries | map({
          region: .key,
          count: (.value | length),
          total: (.value | map(.sales) | add),
          avg: ((.value | map(.sales) | add) / (.value | length))
        })|}
      {|[{"region": "East", "sales": 100}, {"region": "West", "sales": 200}, {"region": "East", "sales": 150}]|}
      {|[
  {
    "region": "East",
    "count": 2,
    "total": 250,
    "avg": 125
  },
  {
    "region": "West",
    "count": 1,
    "total": 200,
    "avg": 200
  }
]|};
  ]

let recursive_functions =
  [
    test {|fn fact: if . <= 1 then 1 else . * ((. - 1) | fact) end; 5 | fact|}
      {|null|} {|120|};
    test
      {|fn fib: if . <= 1 then . else ((. - 1) | fib) + ((. - 2) | fib) end; 10 | fib|}
      {|null|} {|55|};
    test
      {|fn depth: if type == "object" and has("children") then 1 + ([.children[] | depth] | max) else 0 end;
        depth|}
      {|{"name": "root", "children": [{"name": "a", "children": [{"name": "b"}]}, {"name": "c"}]}|}
      {|2|};
  ]

let data_transforms =
  [
    test
      {|group_by(.date) | to_entries | map({date: .key} + (.value | map({(.product): .sales}) | add))|}
      {|[{"date": "2024-01", "product": "A", "sales": 100}, {"date": "2024-01", "product": "B", "sales": 200}, {"date": "2024-02", "product": "A", "sales": 150}]|}
      {|[ { "date": "2024-01", "A": 100, "B": 200 }, { "date": "2024-02", "A": 150 } ]|};
    test {|[((.[0] | keys[]) as $k | {($k): [.[][$k]]})] | add|}
      {|[{"a": 1, "b": 2}, {"a": 3, "b": 4}]|}
      {|{ "a": [ 1, 3 ], "b": [ 2, 4 ] }|};
    test
      {|(.users[] as $user | .orders[] | select(.user_id == $user.id) | {user_name: $user.name, order_id: .id, amount: .amount})|}
      {|{"users": [{"id": 1, "name": "Alice"}], "orders": [{"id": 101, "user_id": 1, "amount": 50}]}|}
      {|{ "user_name": "Alice", "order_id": 101, "amount": 50 }|};
  ]

let string_processing =
  [
    test
      {|split("\n") | map(split(",")) | .[1:][] | {name: .[0], age: (.[1] | to_number)}|}
      {|"name,age\nAlice,30\nBob,25"|}
      "{ \"name\": \"Alice\", \"age\": 30 }\n{ \"name\": \"Bob\", \"age\": 25 }";
    test
      {|gsub("[^a-zA-Z ]"; "") | split(" ") | map(select(length > 0)) | group_by(.) | to_entries | map({word: .key, count: (.value | length)}) | sort_by(.count) | reverse|}
      {|"the cat and the dog"|}
      {|[
  {
    "word": "the",
    "count": 2
  },
  {
    "word": "dog",
    "count": 1
  },
  {
    "word": "cat",
    "count": 1
  },
  {
    "word": "and",
    "count": 1
  }
]|};
  ]

let path_operations =
  [
    test {|[paths(type != "object" and type != "array")]|}
      {|{"a": 1, "b": {"c": 2}}|} {|[ [ "a" ], [ "b", "c" ] ]|};
    test {|set_path(["a", "b"]; 99)|} {|{"a": {"b": 1, "c": 2}}|}
      {|{ "a": { "b": 99, "c": 2 } }|};
    test {|[get_path(["a"]), get_path(["b", "c"])]|} {|{"a": 1, "b": {"c": 2}}|}
      {|[ 1, 2 ]|};
  ]

let complex_filtering =
  [
    test
      {|.[] | select(.active == true and .age >= 18 and (.roles | contains(["admin"])))|}
      {|[{"name": "Alice", "active": true, "age": 25, "roles": ["admin", "user"]}, {"name": "Bob", "active": true, "age": 17, "roles": ["admin"]}, {"name": "Carol", "active": false, "age": 30, "roles": ["admin"]}]|}
      {|{ "name": "Alice", "active": true, "age": 25, "roles": [ "admin", "user" ] }|};
    test {|.. | objects | select(has("target")) | .target|}
      {|{"a": {"target": 1}, "b": {"c": {"target": 2}}}|} "1\n2";
    test {|.[] | select(any(.tags[]; . == "important"))|}
      {|[{"name": "a", "tags": ["foo", "bar"]}, {"name": "b", "tags": ["important", "urgent"]}]|}
      {|{ "name": "b", "tags": [ "important", "urgent" ] }|};
  ]

let fizzbuzz =
  [
    test
      {|fn fizzbuzz:
          if . % 15 == 0 then "FizzBuzz"
          elif . % 3 == 0 then "Fizz"
          elif . % 5 == 0 then "Buzz"
          else . | to_string
          end;
        [range(1;16) | fizzbuzz]|}
      {|null|}
      {|[ "1", "2", "Fizz", "4", "Buzz", "Fizz", "7", "8", "Fizz", "Buzz", "11", "Fizz", "13", "14", "FizzBuzz" ]|};
  ]

let object_merge =
  [
    test {|reduce .[] as $obj ({}; . * $obj)|}
      {|[{"a": 1}, {"b": 2}, {"c": 3}]|} {|{ "a": 1, "b": 2, "c": 3 }|};
    test {|{"a": {"x": 1}} * {"a": {"y": 2}}|} {|null|}
      {|{ "a": { "x": 1, "y": 2 } }|};
    test {|reduce .[] as $obj ({}; . * $obj)|}
      {|[{"a": 1, "b": 2}, {"b": 3, "c": 4}]|} {|{ "a": 1, "b": 3, "c": 4 }|};
  ]

let array_algorithms =
  [
    test
      {|fn chunk: if length <= 3 then [.] else [.[0:3]] + (.[3:] | chunk) end;
        [1,2,3,4,5,6,7] | chunk|}
      {|null|} {|[ [ 1, 2, 3 ], [ 4, 5, 6 ], [ 7 ] ]|};
    test {|transpose | map({a: .[0], b: .[1]})|} {|[[1,2,3], ["a","b","c"]]|}
      {|[ { "a": 1, "b": "a" }, { "a": 2, "b": "b" }, { "a": 3, "b": "c" } ]|};
    test
      {|fn window: if length < 3 then empty else .[0:3], (.[1:] | window) end;
        [[1,2,3,4,5] | window]|}
      {|null|} {|[ [ 1, 2, 3 ], [ 2, 3, 4 ], [ 3, 4, 5 ] ]|};
  ]

let statistics =
  [
    test {|{count: length, sum: add, min: min, max: max, mean: (add / length)}|}
      {|[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]|}
      {|{ "count": 10, "sum": 55, "min": 1, "max": 10, "mean": 5.5 }|};
    test
      {|sort | ((length / 2 | floor) as $mid | (($mid - 1) as $prev | if length % 2 == 0 then (.[$prev] + .[$mid]) / 2 else .[$mid] end))|}
      {|[3, 1, 4, 1, 5, 9, 2, 6]|} {|3.5|};
  ]

let index_operations =
  [
    test {|map({(.id | to_string): .}) | add|}
      {|[{"id": 1, "name": "a"}, {"id": 2, "name": "b"}]|}
      {|{ "1": { "id": 1, "name": "a" }, "2": { "id": 2, "name": "b" } }|};
    test {|group_by(.category)|}
      {|[{"category": "x", "v": 1}, {"category": "y", "v": 2}, {"category": "x", "v": 3}]|}
      {|{ "x": [ { "category": "x", "v": 1 }, { "category": "x", "v": 3 } ], "y": [ { "category": "y", "v": 2 } ] }|};
  ]

let snake_case_aliases =
  [
    (* to_string works *)
    test {|to_string|} {|42|} {|"42"|};
    (* to_number works *)
    test {|to_number|} {|"42"|} {|42|};
    (* get_path works (getpath is deprecated) *)
    test {|get_path(["a", "b"])|} {|{"a": {"b": 42}}|} {|42|};
    (* set_path works (setpath is deprecated) *)
    test {|set_path(["a", "b"]; 99)|} {|{"a": {"b": 42}}|}
      {|{ "a": { "b": 99 } }|};
    (* delete_paths works (delpaths is deprecated) *)
    test {|delete_paths([["a","b"]])|} {|{"a":{"b":1},"x":{"y":2}}|}
      {|{ "a": {}, "x": { "y": 2 } }|};
    (* starts_with works *)
    test {|starts_with("Hello")|} {|"Hello, world"|} {|true|};
    (* ends_with works *)
    test {|ends_with("world")|} {|"Hello, world"|} {|true|};
    (* trim_start / ltrimstr - both should work *)
    test {|trim_start("foo")|} {|"foobar"|} {|"bar"|};
    test {|ltrimstr("foo")|} {|"foobar"|} {|"bar"|};
    (* trim_end / rtrimstr - both should work *)
    test {|trim_end("bar")|} {|"foobar"|} {|"foo"|};
    test {|rtrimstr("bar")|} {|"foobar"|} {|"foo"|};
    (* is_nan / isnan - both should work *)
    test {|is_nan|} {|42|} {|false|};
    test {|isnan|} {|42|} {|false|};
    (* is_infinite / isinfinite - both should work *)
    test {|is_infinite|} {|42|} {|false|};
    test {|isinfinite|} {|42|} {|false|};
    (* is_normal / isnormal - both should work *)
    test {|is_normal|} {|42|} {|true|};
    test {|isnormal|} {|42|} {|true|};
    (* to_uppercase / ascii_upcase - both should work *)
    test {|to_uppercase|} {|"hello"|} {|"HELLO"|};
    test {|ascii_upcase|} {|"hello"|} {|"HELLO"|};
    (* to_lowercase / ascii_downcase - both should work *)
    test {|to_lowercase|} {|"HELLO"|} {|"hello"|};
    test {|ascii_downcase|} {|"HELLO"|} {|"hello"|};
    (* find_indices / indices - both should work *)
    test {|find_indices(", ")|} {|"a,b, cd, efg, hijk"|} {|[ 3, 7, 12 ]|};
    test {|indices(", ")|} {|"a,b, cd, efg, hijk"|} {|[ 3, 7, 12 ]|};
    (* Edge cases for snake_case functions *)
    (* to_string works on all types *)
    test {|to_string|} {|null|} {|"null"|};
    test {|to_string|} {|true|} {|"true"|};
    test {|to_string|} {|[1,2]|} {|"[ 1, 2 ]"|};
    test {|to_string|} {|{"a":1}|} {|"{ \"a\": 1 }"|};
    (* to_number with different string formats *)
    test {|to_number|} {|"3.14"|} {|3.14|};
    test {|to_number|} {|"-42"|} {|-42|};
    test {|to_number|} {|42|} {|42|};
    (* numbers pass through *)
    (* starts_with / ends_with edge cases *)
    test {|starts_with("")|} {|"hello"|} {|true|};
    test {|ends_with("")|} {|"hello"|} {|true|};
    test {|starts_with("hello")|} {|"hello"|} {|true|};
    test {|ends_with("hello")|} {|"hello"|} {|true|};
    test {|starts_with("x")|} {|""|} {|false|};
    test {|ends_with("x")|} {|""|} {|false|};
    (* trim_start / trim_end when pattern not present *)
    test {|trim_start("xxx")|} {|"hello"|} {|"hello"|};
    test {|trim_end("xxx")|} {|"hello"|} {|"hello"|};
    (* get_path with nested paths *)
    test {|get_path(["a", "b", "c"])|} {|{"a": {"b": {"c": 42}}}|} {|42|};
    test {|get_path([])|} {|{"a": 1}|} {|{ "a": 1 }|};
    test {|get_path(["missing"])|} {|{}|} {|null|};
    (* set_path creating nested structure *)
    test {|set_path(["x", "y", "z"]; 1)|} {|{}|}
      {|{ "x": { "y": { "z": 1 } } }|};
    (* find_indices for arrays *)
    test {|find_indices(2)|} {|[1, 2, 3, 2, 4, 2]|} {|[ 1, 3, 5 ]|};
    test {|indices("x")|} {|"axbxcx"|} {|[ 1, 3, 5 ]|};
  ]

let collection_helpers =
  [
    (* pluck - extract key from array of objects *)
    test {|pluck(.a)|} {|[{"a":1},{"a":2},{"a":3}]|} {|[ 1, 2, 3 ]|};
    test {|pluck(.name)|} {|[{"name":"alice"},{"name":"bob"}]|}
      {|[ "alice", "bob" ]|};
    test {|pluck(.x)|} {|[{"x":1,"y":2},{"y":3}]|} {|[ 1, null ]|};
    test {|pluck(.a.b)|} {|[{"a":{"b":1}},{"a":{"b":2}}]|} {|[ 1, 2 ]|};
    (* compact - remove null values from array *)
    test {|compact|} {|[1,null,2,null,3]|} {|[ 1, 2, 3 ]|};
    test {|compact|} {|[null,null]|} {|[]|};
    test {|compact|} {|[1,2,3]|} {|[ 1, 2, 3 ]|};
    test {|compact|} {|[]|} {|[]|};
    test {|[1,null,2] | compact|} {|null|} {|[ 1, 2 ]|};
    (* partition - split into [matching, non-matching] *)
    test {|partition(. > 2)|} {|[1,2,3,4,5]|} {|[ [ 3, 4, 5 ], [ 1, 2 ] ]|};
    test {|partition(. > 10)|} {|[1,2,3]|} {|[ [], [ 1, 2, 3 ] ]|};
    test {|partition(. < 0)|} {|[1,2,3]|} {|[ [], [ 1, 2, 3 ] ]|};
    test {|partition(.active)|} {|[{"active":true},{"active":false}]|}
      {|[ [ { "active": true } ], [ { "active": false } ] ]|};
    test {|partition(type == "number")|} {|[1,"a",2,"b",3]|}
      {|[ [ 1, 2, 3 ], [ "a", "b" ] ]|};
    (* is_empty - check if array/string/object is empty *)
    test {|is_empty|} {|[]|} {|true|};
    test {|is_empty|} {|[1,2,3]|} {|false|};
    test {|is_empty|} {|""|} {|true|};
    test {|is_empty|} {|"hello"|} {|false|};
    test {|is_empty|} {|{}|} {|true|};
    test {|is_empty|} {|{"a":1}|} {|false|};
    test {|is_empty|} {|null|} {|true|};
    (* is_blank - check if null, empty, or whitespace-only *)
    test {|is_blank|} {|null|} {|true|};
    test {|is_blank|} {|""|} {|true|};
    test {|is_blank|} {|"   "|} {|true|};
    test {|is_blank|} {|"\t\n"|} {|true|};
    test {|is_blank|} {|"hello"|} {|false|};
    test {|is_blank|} {|" hello "|} {|false|};
    test {|is_blank|} {|[]|} {|true|};
    test {|is_blank|} {|[1]|} {|false|};
    test {|is_blank|} {|{}|} {|true|};
    test {|is_blank|} {|{"a":1}|} {|false|};
    (* assert - fail if assertion fails *)
    test {|assert(. > 0)|} {|5|} {|5|};
    test {|assert(type == "number")|} {|42|} {|42|};
    test {|assert(length > 0)|} {|[1,2,3]|} {|[ 1, 2, 3 ]|};
    (* debug - side-effect output (result unchanged) *)
    test {|. | debug("test")|} {|42|} {|42|};
    test {|debug|} {|{"a":1}|} {|{ "a": 1 }|};
  ]

let deep_traversal =
  [
    test {|[descend]|} {|{"a": {"b": 1}}|}
      {|[ { "a": { "b": 1 } }, { "b": 1 }, 1 ]|};
    test {|[descend]|} {|[1, [2, 3]]|}
      {|[ [ 1, [ 2, 3 ] ], 1, [ 2, 3 ], 2, 3 ]|};
    test {|[descend] | length|} {|{"x": {"y": {"z": 1}}}|} {|4|};
    test {|[descend]|} {|42|} {|[ 42 ]|};
    test {|[descend]|} {|"hello"|} {|[ "hello" ]|};
    test {|[dive]|} {|{"a": {"b": 1}}|}
      {|[ { "a": { "b": 1 } }, { "b": 1 }, 1 ]|};
    test {|[dive]|} {|{"a": 1, "b": 2}|} {|[ { "a": 1, "b": 2 }, 1, 2 ]|};
    test {|find_all(type == "number")|} {|{"a": 1, "b": {"c": 2, "d": "str"}}|}
      {|[ 1, 2 ]|};
    test {|find_all(. > 5)|} {|[1, [2, 10], {"x": 20}]|} {|[ 10, 20 ]|};
    test {|find_all(type == "array")|} {|{"a": [1, 2], "b": {"c": [3, 4]}}|}
      {|[ [ 1, 2 ], [ 3, 4 ] ]|};
    test {|find_all(type == "string")|}
      {|{"name": "alice", "data": {"value": "test"}}|} {|[ "alice", "test" ]|};
    test {|find_all(type == "boolean")|} {|{"a": 1, "b": "str"}|} {|[]|};
    test {|find_first(type == "number")|} {|{"a": "str", "b": {"c": 42}}|}
      {|42|};
    test {|find_first(. > 10)|} {|[1, [2, 20], 30]|} {|20|};
    test {|find_first(type == "boolean")|} {|{"a": 1, "b": "str"}|} {|null|};
    test {|paths_to(type == "number")|} {|{"a": 1, "b": {"c": 2}}|}
      {|[ [ "a" ], [ "b", "c" ] ]|};
    test {|paths_to(. == "target")|} {|{"x": "target", "y": {"z": "target"}}|}
      {|[ [ "x" ], [ "y", "z" ] ]|};
    test {|paths_to(type == "number")|} {|[1, [2, 3]]|}
      {|[ [ 0 ], [ 1, 0 ], [ 1, 1 ] ]|};
    test {|paths_to(type == "boolean")|} {|{"a": 1}|} {|[]|};
    test {|paths_to(type == "number") | length|}
      {|{"a": 1, "b": {"c": 2, "d": 3}}|} {|3|};
    test {|find_all(.name?)|} {|{"users":[{"name":"alice"},{"name":"bob"}]}|}
      {|[ "alice", "bob" ]|};
  ]

let tests =
  List.concat
    [
      identity;
      literals;
      comments;
      large_numbers;
      object_identifier_index;
      optional_object_identifier_index;
      array_index;
      array_index_multiple;
      array_string_slice;
      array_object_value_iterator;
      comma;
      pipe;
      parenthesis;
      array_construction;
      object_construction;
      addition;
      subtraction;
      multiplication_division_modulo;
      comparison;
      equality;
      boolean_operators;
      alternative;
      update;
      conditionals;
      try_catch;
      empty;
      range;
      while_;
      until;
      recurse;
      walk;
      reduce;
      foreach;
      limit;
      isempty;
      map;
      flat_map;
      select;
      has;
      in_;
      type_;
      length;
      reverse;
      sort;
      unique;
      min_max;
      group_by;
      any_all;
      some_find;
      flatten;
      transpose;
      add;
      entries;
      contains;
      inside;
      startswith_endswith;
      trimstr;
      trim;
      ascii_case;
      split_join;
      explode_implode;
      utf8bytelength;
      index;
      math_abs;
      math_floor_ceil_round;
      math_sqrt;
      math_log_exp;
      math_trig;
      nan_infinite;
      tonumber;
      toboolean;
      tostring;
      string_interpolation;
      template_literals;
      regex_test;
      regex_match;
      regex_capture;
      regex_sub_gsub;
      regex_scan;
      regex_split;
      regex_splits;
      path;
      delpaths;
      del;
      object_index_brackets;
      recursive_descent;
      type_selectors;
      variable_binding;
      destructuring_alternative;
      optional_operator;
      arithmetic_update;
      keys;
      pick;
      combinations;
      repeat;
      loc;
      env;
      bsearch;
      date;
      assignment;
      defining_functions;
      skip;
      first_last_nth;
      generators_iterators;
      decimal_number;
      (* programs *)
      tobase;
      cumulative_sum;
      flatten_nested;
      walk_transforms;
      group_aggregate;
      recursive_functions;
      data_transforms;
      string_processing;
      path_operations;
      complex_filtering;
      fizzbuzz;
      object_merge;
      array_algorithms;
      statistics;
      index_operations;
      snake_case_aliases;
      collection_helpers;
      deep_traversal;
    ]
