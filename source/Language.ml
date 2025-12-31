type applicable_to = String | Array | Object | Number | Bool | Nil | Any

type arity =
  | No_args
  | One_arg of string (* description of the argument *)
  | Two_args of string * string (* descriptions *)
  | Three_args of string * string * string
  | Variable_args of string (* description *)

type function_info = {
  name : string;
  aliases : string list;
  description : string;
  example : string option;
  applicable_to : applicable_to list;
  insert_text : string option;
  arity : arity;
}

type category = {
  name : string;
  description : string;
  functions : function_info list;
}

let string_functions =
  {
    name = "string";
    description = "String manipulation functions";
    functions =
      [
        {
          name = "split";
          aliases = [];
          description = "Split string by separator";
          example = Some {|"a,b,c" | split(",")  → ["a", "b", "c"]|};
          applicable_to = [ String ];
          insert_text = None;
          arity = One_arg "separator";
        };
        {
          name = "join";
          aliases = [];
          description = "Join array elements with separator";
          example = Some {|["a", "b"] | join(",")  → "a,b"|};
          applicable_to = [ Array ];
          insert_text = None;
          arity = One_arg "separator";
        };
        {
          name = "trim";
          aliases = [];
          description = "Remove whitespace from both ends";
          example = Some {|"  hello  " | trim  → "hello"|};
          applicable_to = [ String ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "trim_start";
          aliases = [ "ltrimstr" ];
          description = "Remove prefix string";
          example = Some {|"foobar" | trim_start("foo")  → "bar"|};
          applicable_to = [ String ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "trim_end";
          aliases = [ "rtrimstr" ];
          description = "Remove suffix string";
          example = Some {|"foobar" | trim_end("bar")  → "foo"|};
          applicable_to = [ String ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "starts_with";
          aliases = [];
          description = "Check if string starts with prefix";
          example = Some {|"hello" | starts_with("he")  → true|};
          applicable_to = [ String ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "ends_with";
          aliases = [];
          description = "Check if string ends with suffix";
          example = Some {|"hello" | ends_with("lo")  → true|};
          applicable_to = [ String ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "contains";
          aliases = [];
          description = "Check if string contains substring";
          example = Some {|"hello" | contains("ell")  → true|};
          applicable_to = [ String; Array; Object ];
          insert_text = None;
          arity = One_arg "json";
        };
        {
          name = "to_lowercase";
          aliases = [ "ascii_downcase" ];
          description = "Convert to lowercase";
          example = Some {|"HELLO" | to_lowercase  → "hello"|};
          applicable_to = [ String ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "to_uppercase";
          aliases = [ "ascii_upcase" ];
          description = "Convert to uppercase";
          example = Some {|"hello" | to_uppercase  → "HELLO"|};
          applicable_to = [ String ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "length";
          aliases = [];
          description = "Get string length";
          example = Some {|"hello" | length  → 5|};
          applicable_to = [ String; Array; Object ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "test";
          aliases = [];
          description = "Test if string matches regex";
          example = Some {|"hello" | test("^he")  → true|};
          applicable_to = [ String ];
          insert_text = None;
          arity = One_arg "pattern";
        };
        {
          name = "match";
          aliases = [];
          description = "Match regex and return match info";
          example = Some {|"foo bar" | match("bar")  → {offset: 4, ...}|};
          applicable_to = [ String ];
          insert_text = None;
          arity = One_arg "pattern";
        };
        {
          name = "scan";
          aliases = [];
          description = "Find all regex matches";
          example = Some {|"a1b2c3" | [scan("[0-9]+")]  → ["1", "2", "3"]|};
          applicable_to = [ String ];
          insert_text = None;
          arity = One_arg "pattern";
        };
        {
          name = "sub";
          aliases = [];
          description = "Replace first regex match";
          example = Some {|"hello" | sub("l"; "L")  → "heLlo"|};
          applicable_to = [ String ];
          insert_text = None;
          arity = Two_args ("pattern", "replacement");
        };
        {
          name = "gsub";
          aliases = [];
          description = "Replace all regex matches";
          example = Some {|"hello" | gsub("l"; "L")  → "heLLo"|};
          applicable_to = [ String ];
          insert_text = None;
          arity = Two_args ("pattern", "replacement");
        };
        {
          name = "explode";
          aliases = [];
          description = "Convert string to array of codepoints";
          example = Some {|"hi" | explode  → [104, 105]|};
          applicable_to = [ String ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "implode";
          aliases = [];
          description = "Convert array of codepoints to string";
          example = Some {|[72, 105] | implode  → "Hi"|};
          applicable_to = [ Array ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "index";
          aliases = [];
          description = "Find first index of substring";
          example = Some {|"hello" | index("l")  → 2|};
          applicable_to = [ String; Array ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "rindex";
          aliases = [];
          description = "Find last index of substring";
          example = Some {|"hello" | rindex("l")  → 3|};
          applicable_to = [ String; Array ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "find_indices";
          aliases = [ "indices" ];
          description = "Find all indices of substring";
          example = Some {|"ababa" | find_indices("a") → [0, 2, 4]|};
          applicable_to = [ String; Array ];
          insert_text = None;
          arity = No_args;
        };
      ];
  }

let array_functions =
  {
    name = "array";
    description = "Array manipulation functions";
    functions =
      [
        {
          name = "map";
          aliases = [];
          description = "Transform each element";
          example = Some {|[1, 2, 3] | map(. * 2) → [2, 4, 6]|};
          applicable_to = [ Array ];
          insert_text = None;
          arity = One_arg "expr";
        };
        {
          name = "select";
          aliases = [ "filter" ];
          description = "Filter elements matching condition";
          example = Some {|[1, 2, 3] | map(select(. > 1)) → [2, 3]|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = One_arg "condition";
        };
        {
          name = "sort";
          aliases = [];
          description = "Sort array";
          example = Some {|[3, 1, 2] | sort → [1, 2, 3]|};
          applicable_to = [ Array ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "sort_by";
          aliases = [];
          description = "Sort by expression result";
          example = Some {|[{a:2}, {a:1}] | sort_by(.a) → [{a:1}, {a:2}]|};
          applicable_to = [ Array ];
          insert_text = None;
          arity = One_arg "expr";
        };
        {
          name = "group_by";
          aliases = [];
          description = "Group elements by expression result";
          example =
            Some
              {|[{x:1}, {x:2}, {x:1}] | group_by(.x) → {"1": [...], "2": [...]}|};
          applicable_to = [ Array ];
          insert_text = None;
          arity = One_arg "expr";
        };
        {
          name = "unique";
          aliases = [ "uniq" ];
          description = "Remove duplicate elements";
          example = Some {|[1, 2, 1, 3] | unique → [1, 2, 3]|};
          applicable_to = [ Array ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "unique_by";
          aliases = [];
          description = "Remove duplicates by expression result";
          example =
            Some {|[{x:1,y:1}, {x:1,y:2}] | unique_by(.x) → [{x:1,y:1}]|};
          applicable_to = [ Array ];
          insert_text = None;
          arity = One_arg "expr";
        };
        {
          name = "first";
          aliases = [ "head" ];
          description = "Get first element";
          example = Some {|[1, 2, 3] | first → 1|};
          applicable_to = [ Array ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "last";
          aliases = [ "tail" ];
          description = "Get last element";
          example = Some {|[1, 2, 3] | last → 3|};
          applicable_to = [ Array ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "nth";
          aliases = [];
          description = "Get nth element from generator";
          example = Some {|nth(2; range(10)) → 2|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = Two_args ("n", "generator");
        };
        {
          name = "reverse";
          aliases = [];
          description = "Reverse array order";
          example = Some {|[1, 2, 3] | reverse → [3, 2, 1]|};
          applicable_to = [ Array ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "flatten";
          aliases = [];
          description = "Flatten nested arrays";
          example = Some {|[[1, 2], [3, 4]] | flatten → [1, 2, 3, 4]|};
          applicable_to = [ Array ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "add";
          aliases = [];
          description = "Sum/concatenate all elements";
          example = Some {|[1, 2, 3] | add → 6|};
          applicable_to = [ Array ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "min";
          aliases = [];
          description = "Get minimum element";
          example = Some {|[3, 1, 2] | min → 1|};
          applicable_to = [ Array ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "max";
          aliases = [];
          description = "Get maximum element";
          example = Some {|[3, 1, 2] | max → 3|};
          applicable_to = [ Array ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "min_by";
          aliases = [];
          description = "Get element with minimum expression value";
          example = Some {|[{a:2}, {a:1}] | min_by(.a) → {a:1}|};
          applicable_to = [ Array ];
          insert_text = None;
          arity = One_arg "expr";
        };
        {
          name = "max_by";
          aliases = [];
          description = "Get element with maximum expression value";
          example = Some {|[{a:2}, {a:1}] | max_by(.a) → {a:2}|};
          applicable_to = [ Array ];
          insert_text = None;
          arity = One_arg "expr";
        };
        {
          name = "any";
          aliases = [];
          description = "Check if any element is truthy";
          example = Some {|[false, true] | any → true|};
          applicable_to = [ Array ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "all";
          aliases = [];
          description = "Check if all elements are truthy";
          example = Some {|[true, true] | all → true|};
          applicable_to = [ Array ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "pluck";
          aliases = [];
          description = "Extract key from array of objects";
          example = Some {|[{a:1}, {a:2}] | pluck(.a) → [1, 2]|};
          applicable_to = [ Array ];
          insert_text = None;
          arity = One_arg "expr";
        };
        {
          name = "compact";
          aliases = [];
          description = "Remove null values from array";
          example = Some {|[1, null, 2] | compact → [1, 2]|};
          applicable_to = [ Array ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "partition";
          aliases = [];
          description = "Split into [matching, non-matching]";
          example = Some {|[1, 2, 3] | partition(. > 1) → [[2, 3], [1]]|};
          applicable_to = [ Array ];
          insert_text = None;
          arity = One_arg "condition";
        };
        {
          name = "transpose";
          aliases = [];
          description = "Transpose array of arrays";
          example = Some {|[[1, 2], [3, 4]] | transpose → [[1, 3], [2, 4]]|};
          applicable_to = [ Array ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "combinations";
          aliases = [];
          description = "All combinations of input arrays";
          example = Some {|[[1, 2], ["a", "b"]] | combinations → [1, "a"], ...|};
          applicable_to = [ Array ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "find";
          aliases = [];
          description = "Find first matching element";
          example = Some {|[1, 2, 3] | find(. > 1) → 2|};
          applicable_to = [ Array ];
          insert_text = None;
          arity = One_arg "condition";
        };
        {
          name = "bsearch";
          aliases = [];
          description = "Binary search (array must be sorted)";
          example = Some {|[1, 2, 3] | bsearch(2) → 1|};
          applicable_to = [ Array ];
          insert_text = None;
          arity = One_arg "target";
        };
      ];
  }

let object_functions =
  {
    name = "object";
    description = "Object manipulation functions";
    functions =
      [
        {
          name = "keys";
          aliases = [];
          description = "Get sorted array of keys";
          example = Some {|{b:1, a:2} | keys  → ["a", "b"]|};
          applicable_to = [ Object ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "keys_unsorted";
          aliases = [];
          description = "Get array of keys in original order";
          example = Some {|{b:1, a:2} | keys_unsorted  → ["b", "a"]|};
          applicable_to = [ Object ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "has";
          aliases = [];
          description = "Check if key exists";
          example = Some {|{a:1} | has("a")  → true|};
          applicable_to = [ Object; Array ];
          insert_text = None;
          arity = One_arg "key";
        };
        {
          name = "in";
          aliases = [];
          description = "Check if key exists in object";
          example = Some {|"a" | in({a:1})  → true|};
          applicable_to = [ String; Number ];
          insert_text = None;
          arity = One_arg "object";
        };
        {
          name = "to_entries";
          aliases = [];
          description = "Convert to [{key, value}, ...]";
          example = Some {|{a:1} | to_entries  → [{key:"a", value:1}]|};
          applicable_to = [ Object ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "from_entries";
          aliases = [];
          description = "Convert from [{key, value}, ...] to object";
          example = Some {|[{key:"a", value:1}] | from_entries  → {a:1}|};
          applicable_to = [ Array ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "with_entries";
          aliases = [];
          description = "Transform each {key, value} entry";
          example = Some {|{a:1} | with_entries(.value += 1)  → {a:2}|};
          applicable_to = [ Object ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "del";
          aliases = [];
          description = "Delete key at path";
          example = Some {|{a:1, b:2} | del(.a)  → {b:2}|};
          applicable_to = [ Object; Array ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "pick";
          aliases = [];
          description = "Select only specified paths";
          example = Some {|{a:1, b:2, c:3} | pick(.a, .c)  → {a:1, c:3}|};
          applicable_to = [ Object ];
          insert_text = None;
          arity = No_args;
        };
      ];
  }

let path_functions =
  {
    name = "path";
    description = "Path and traversal functions";
    functions =
      [
        {
          name = "path";
          aliases = [];
          description = "Get path to expression result";
          example = Some {|{a:{b:1}} | path(.a.b)  → ["a", "b"]|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = One_arg "expr";
        };
        {
          name = "paths";
          aliases = [];
          description = "Get all paths in value";
          example = Some {|{a:{b:1}} | [paths]  → [["a"], ["a","b"]]|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "leaf_paths";
          aliases = [];
          description = "Get paths to leaf values only";
          example = Some {|{a:{b:1}} | [leaf_paths]  → [["a", "b"]]|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "get_path";
          aliases = [ "getpath" ];
          description = "Get value at path";
          example = Some {|{a:{b:1}} | get_path(["a","b"])  → 1|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "set_path";
          aliases = [ "setpath" ];
          description = "Set value at path";
          example = Some {|{a:1} | set_path(["b"]; 2)  → {a:1, b:2}|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "delete_paths";
          aliases = [ "delpaths" ];
          description = "Delete multiple paths";
          example = Some {|{a:1, b:2} | delete_paths([["a"]])  → {b:2}|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "recurse";
          aliases = [];
          description = "Recursively descend into structure";
          example = Some {|{a:{b:1}} | [recurse | numbers]  → [1]|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "..";
          aliases = [];
          description = "Recursive descent";
          example = Some {|{a:{b:1}} | [.. | numbers]  → [1]|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "descend";
          aliases = [];
          description = "Breadth-first traversal of all nested values";
          example = Some {|{a:{b:1}} | [descend]  → [{a:{b:1}}, {b:1}, 1]|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "dive";
          aliases = [];
          description = "Depth-first traversal of all nested values";
          example = Some {|{a:1, b:2} | [dive]  → [{a:1,b:2}, 1, 2]|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "find_all";
          aliases = [];
          description = "Find all values matching condition at any depth";
          example = Some {|{a:1, b:{c:2}} | find_all(type=="number")  → [1, 2]|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "find_first";
          aliases = [];
          description = "Find first value matching condition";
          example = Some {|{a:"x", b:{c:1}} | find_first(type=="number")  → 1|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "paths_to";
          aliases = [];
          description = "Get paths to all matching values";
          example =
            Some
              {|{a:1, b:{c:2}} | paths_to(type=="number")  → [["a"], ["b","c"]]|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "walk";
          aliases = [];
          description = "Transform all values recursively";
          example =
            Some
              {|{a:1} | walk(if type=="number" then .+1 else . end)  → {a:2}|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = One_arg "expr";
        };
      ];
  }

let math_functions =
  {
    name = "math";
    description = "Mathematical functions";
    functions =
      [
        {
          name = "abs";
          aliases = [];
          description = "Absolute value";
          example = Some {|-5 | abs  → 5|};
          applicable_to = [ Number ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "floor";
          aliases = [];
          description = "Round down";
          example = Some {|3.7 | floor  → 3|};
          applicable_to = [ Number ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "ceil";
          aliases = [];
          description = "Round up";
          example = Some {|3.2 | ceil  → 4|};
          applicable_to = [ Number ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "round";
          aliases = [];
          description = "Round to nearest integer";
          example = Some {|3.5 | round  → 4|};
          applicable_to = [ Number ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "sqrt";
          aliases = [];
          description = "Square root";
          example = Some {|16 | sqrt  → 4|};
          applicable_to = [ Number ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "log";
          aliases = [];
          description = "Natural logarithm";
          example = None;
          applicable_to = [ Number ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "log10";
          aliases = [];
          description = "Base-10 logarithm";
          example = Some {|100 | log10  → 2|};
          applicable_to = [ Number ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "log2";
          aliases = [];
          description = "Base-2 logarithm";
          example = None;
          applicable_to = [ Number ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "exp";
          aliases = [];
          description = "e^x";
          example = Some {|0 | exp  → 1|};
          applicable_to = [ Number ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "exp2";
          aliases = [];
          description = "2^x";
          example = None;
          applicable_to = [ Number ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "pow";
          aliases = [];
          description = "x raised to power y";
          example = Some {|pow(2; 3)  → 8|};
          applicable_to = [ Number ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "sin";
          aliases = [];
          description = "Sine";
          example = Some {|0 | sin  → 0|};
          applicable_to = [ Number ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "cos";
          aliases = [];
          description = "Cosine";
          example = Some {|0 | cos  → 1|};
          applicable_to = [ Number ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "tan";
          aliases = [];
          description = "Tangent";
          example = None;
          applicable_to = [ Number ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "asin";
          aliases = [];
          description = "Arc sine";
          example = None;
          applicable_to = [ Number ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "acos";
          aliases = [];
          description = "Arc cosine";
          example = None;
          applicable_to = [ Number ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "atan";
          aliases = [];
          description = "Arc tangent";
          example = None;
          applicable_to = [ Number ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "atan2";
          aliases = [];
          description = "Arc tangent of y/x";
          example = None;
          applicable_to = [ Number ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "sinh";
          aliases = [];
          description = "Hyperbolic sine";
          example = None;
          applicable_to = [ Number ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "cosh";
          aliases = [];
          description = "Hyperbolic cosine";
          example = None;
          applicable_to = [ Number ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "tanh";
          aliases = [];
          description = "Hyperbolic tangent";
          example = None;
          applicable_to = [ Number ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "asinh";
          aliases = [];
          description = "Inverse hyperbolic sine";
          example = None;
          applicable_to = [ Number ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "acosh";
          aliases = [];
          description = "Inverse hyperbolic cosine";
          example = None;
          applicable_to = [ Number ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "atanh";
          aliases = [];
          description = "Inverse hyperbolic tangent";
          example = None;
          applicable_to = [ Number ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "cbrt";
          aliases = [];
          description = "Cube root";
          example = None;
          applicable_to = [ Number ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "trunc";
          aliases = [];
          description = "Truncate toward zero";
          example = None;
          applicable_to = [ Number ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "fabs";
          aliases = [];
          description = "Floating-point absolute value";
          example = None;
          applicable_to = [ Number ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "is_nan";
          aliases = [ "isnan" ];
          description = "Check if NaN";
          example = Some {|42 | is_nan  → false|};
          applicable_to = [ Number ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "is_infinite";
          aliases = [ "isinfinite" ];
          description = "Check if infinite";
          example = None;
          applicable_to = [ Number ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "is_normal";
          aliases = [ "isnormal" ];
          description = "Check if normal number";
          example = None;
          applicable_to = [ Number ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "nan";
          aliases = [];
          description = "NaN constant";
          example = None;
          applicable_to = [ Any ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "infinite";
          aliases = [];
          description = "Infinite sequence 0, 1, 2, ...";
          example = Some {|[limit(3; infinite)]  → [0, 1, 2]|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = No_args;
        };
      ];
  }

let type_functions =
  {
    name = "type";
    description = "Type checking and conversion functions";
    functions =
      [
        {
          name = "type";
          aliases = [];
          description = "Get type as string";
          example = Some {|42 | type  → "number"|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "to_string";
          aliases = [ "tostring" ];
          description = "Convert to string";
          example = Some {|42 | to_string  → "42"|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "to_number";
          aliases = [ "tonumber" ];
          description = "Convert to number";
          example = Some {|"42" | to_number  → 42|};
          applicable_to = [ String; Number ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "numbers";
          aliases = [];
          description = "Select only numbers";
          example = Some {|[1, "a", 2] | .[] | numbers  → 1, 2|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "strings";
          aliases = [];
          description = "Select only strings";
          example = Some {|[1, "a", 2] | .[] | strings  → "a"|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "booleans";
          aliases = [];
          description = "Select only booleans";
          example = Some {|[1, true, "a"] | .[] | booleans  → true|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "nulls";
          aliases = [];
          description = "Select only nulls";
          example = Some {|[1, null] | .[] | nulls  → null|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "arrays";
          aliases = [];
          description = "Select only arrays";
          example = Some {|[1, [], {}] | .[] | arrays  → []|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "objects";
          aliases = [];
          description = "Select only objects";
          example = Some {|[1, [], {}] | .[] | objects  → {}|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "iterables";
          aliases = [];
          description = "Select arrays and objects";
          example = Some {|[1, [], {}] | .[] | iterables  → [], {}|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "scalars";
          aliases = [];
          description = "Select non-iterables";
          example = Some {|[1, [], "a"] | .[] | scalars  → 1, "a"|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "values";
          aliases = [];
          description = "Select non-null values";
          example = Some {|[1, null, 2] | .[] | values  → 1, 2|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "is_empty";
          aliases = [];
          description = "Check if array/string/object is empty";
          example = Some {|[] | is_empty  → true|};
          applicable_to = [ Array; String; Object; Nil ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "is_blank";
          aliases = [];
          description = "Check if null, empty, or whitespace-only";
          example = Some {|"  " | is_blank  → true|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = No_args;
        };
      ];
  }

let control_functions =
  {
    name = "control";
    description = "Control flow and iteration functions";
    functions =
      [
        {
          name = "if-then-else";
          aliases = [];
          description = "Conditional expression";
          example = Some {|if . > 0 then "pos" else "neg" end|};
          applicable_to = [ Any ];
          insert_text = Some "if . then . else . end";
          arity = No_args;
        };
        {
          name = "try-catch";
          aliases = [];
          description = "Error handling";
          example = Some {|try .foo catch "not found"|};
          applicable_to = [ Any ];
          insert_text = Some {|try . catch "error"|};
          arity = One_arg "handler";
        };
        {
          name = "//";
          aliases = [];
          description = "Alternative operator (on null or false)";
          example =
            Some {|.foo // "default"  → "default" if .foo is null/false|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "empty";
          aliases = [];
          description = "Produce no output";
          example = Some {|1, empty, 2  → 1, 2|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "error";
          aliases = [];
          description = "Raise an error";
          example = Some {|error("failed")|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "raise";
          aliases = [];
          description = "Raise a structured error";
          example = Some {|raise("validation"; "invalid input")|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "assert";
          aliases = [];
          description = "Fail if condition is false";
          example = Some {|assert(. > 0; "must be positive")|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "range";
          aliases = [];
          description = "Generate number sequence";
          example = Some {|[range(3)]  → [0, 1, 2]|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = Variable_args "n or from; to or from; to; step";
        };
        {
          name = "while";
          aliases = [];
          description = "Repeat while condition holds";
          example = Some {|1 | [while(. < 8; . * 2)]  → [1, 2, 4]|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = Two_args ("condition", "update");
        };
        {
          name = "until";
          aliases = [];
          description = "Repeat until condition holds";
          example = Some {|1 | [until(. > 8; . * 2)]  → [16]|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = Two_args ("condition", "update");
        };
        {
          name = "repeat";
          aliases = [];
          description = "Repeat expression indefinitely";
          example = Some {|1 | [limit(3; repeat(. * 2))]  → [2, 4, 8]|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = One_arg "expr";
        };
        {
          name = "reduce";
          aliases = [];
          description = "Fold/reduce operation";
          example = Some {|reduce .[] as $x (0; . + $x)|};
          applicable_to = [ Any ];
          insert_text = Some "reduce . as $x (init; update)";
          arity = Variable_args "expr as $var (init; update)";
        };
        {
          name = "foreach";
          aliases = [];
          description = "Iterate with accumulator";
          example = Some {|[foreach .[] as $x (0; . + $x; .)]|};
          applicable_to = [ Any ];
          insert_text = Some "foreach . as $x (init; update; extract)";
          arity = Variable_args "expr as $var (init; update; extract)";
        };
        {
          name = "limit";
          aliases = [];
          description = "Take first n outputs";
          example = Some {|[limit(2; range(10))]  → [0, 1]|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = Two_args ("n", "generator");
        };
        {
          name = "skip";
          aliases = [];
          description = "Skip first n outputs";
          example = Some {|[skip(2; range(5))]  → [2, 3, 4]|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = Two_args ("n", "generator");
        };
        {
          name = "isempty";
          aliases = [];
          description = "Check if expression produces no output";
          example = Some {|isempty(empty)  → true|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = No_args;
        };
      ];
  }

let definition_functions =
  {
    name = "definition";
    description = "Function definition syntax";
    functions =
      [
        {
          name = "fn";
          aliases = [];
          description = "Define a function";
          example = Some {|fn double: . * 2; 5 | double  → 10|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "as";
          aliases = [];
          description = "Bind expression result to variable";
          example = Some {|.x as $x | .y + $x|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = No_args;
        };
      ];
  }

let debug_functions =
  {
    name = "debug";
    description = "Debugging and inspection functions";
    functions =
      [
        {
          name = "debug";
          aliases = [];
          description = "Print value to stderr";
          example = Some {|.foo | debug | .bar|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "stderr";
          aliases = [];
          description = "Print to stderr";
          example = None;
          applicable_to = [ Any ];
          insert_text = None;
          arity = No_args;
        };
      ];
  }

let all_categories =
  [
    string_functions;
    array_functions;
    object_functions;
    path_functions;
    math_functions;
    type_functions;
    control_functions;
    definition_functions;
    debug_functions;
  ]

let find_category name =
  List.find_opt
    (fun c ->
      Stdlib.String.lowercase_ascii c.name = Stdlib.String.lowercase_ascii name)
    all_categories

let category_names () = List.map (fun c -> c.name) all_categories

let all_functions () : function_info list =
  all_categories |> List.concat_map (fun (c : category) -> c.functions)

let all_function_names () =
  let funcs = all_functions () in
  let names = List.map (fun (f : function_info) -> f.name) funcs in
  let aliases = List.concat_map (fun (f : function_info) -> f.aliases) funcs in
  List.sort_uniq Stdlib.String.compare (names @ aliases)

(* Levenshtein distance for fuzzy matching *)
let levenshtein s1 s2 =
  let len1 = String.length s1 in
  let len2 = String.length s2 in
  if len1 = 0 then len2
  else if len2 = 0 then len1
  else
    let matrix = Array.make_matrix (len1 + 1) (len2 + 1) 0 in
    for i = 0 to len1 do
      matrix.(i).(0) <- i
    done;
    for j = 0 to len2 do
      matrix.(0).(j) <- j
    done;
    for i = 1 to len1 do
      for j = 1 to len2 do
        let cost = if s1.[i - 1] = s2.[j - 1] then 0 else 1 in
        matrix.(i).(j) <-
          min
            (min (matrix.(i - 1).(j) + 1) (matrix.(i).(j - 1) + 1))
            (matrix.(i - 1).(j - 1) + cost)
      done
    done;
    matrix.(len1).(len2)

(* Find similar function names for suggestions *)
let suggest_function_name (typo : string) : string list =
  let all_names = all_function_names () in
  let typo_lower = String.lowercase_ascii typo in
  let typo_len = String.length typo in
  (* Calculate distance and filter candidates *)
  let candidates =
    all_names
    |> List.map (fun name ->
        let name_lower = String.lowercase_ascii name in
        let dist = levenshtein typo_lower name_lower in
        (name, dist))
    |> List.filter (fun (name, dist) ->
        (* Accept if distance is reasonable relative to length *)
        let name_len = String.length name in
        let max_dist = max 2 (min typo_len name_len / 3) in
        dist <= max_dist)
    |> List.sort (fun (_, d1) (_, d2) -> compare d1 d2)
    |> List.map fst
  in
  (* Return top 3 suggestions *)
  match candidates with
  | [] -> []
  | _ -> List.filteri (fun i _ -> i < 3) candidates

let type_name_of_applicable = function
  | String -> "string"
  | Array -> "array"
  | Object -> "object"
  | Number -> "number"
  | Bool -> "boolean"
  | Nil -> "null"
  | Any -> "any"

let applicable_of_type_name = function
  | "string" -> Some String
  | "array" -> Some Array
  | "object" -> Some Object
  | "number" -> Some Number
  | "boolean" -> Some Bool
  | "null" -> Some Nil
  | _ -> None

let functions_for_type type_name =
  let all = all_functions () in
  List.filter
    (fun f ->
      List.exists
        (fun a -> a = Any || type_name_of_applicable a = type_name)
        f.applicable_to)
    all

let function_names_for_type type_name =
  functions_for_type type_name |> List.map (fun (f : function_info) -> f.name)

let applicable_of_json_type = function
  | "string" -> String
  | "array" -> Array
  | "object" -> Object
  | "number" -> Number
  | "boolean" -> Bool
  | "null" -> Nil
  | _ -> Any

let find_function (name : string) : function_info option =
  let all : function_info list = all_functions () in
  List.find_opt
    (fun (f : function_info) -> f.name = name || List.mem name f.aliases)
    all

let arity_to_string (name : string) (arity : arity) : string =
  match arity with
  | No_args -> name
  | One_arg arg -> name ^ "(" ^ arg ^ ")"
  | Two_args (arg1, arg2) -> name ^ "(" ^ arg1 ^ "; " ^ arg2 ^ ")"
  | Three_args (arg1, arg2, arg3) ->
      name ^ "(" ^ arg1 ^ "; " ^ arg2 ^ "; " ^ arg3 ^ ")"
  | Variable_args args -> name ^ "(" ^ args ^ ")"

let error_for_missing_arg (name : string) : string =
  match find_function name with
  | Some f ->
      let usage = arity_to_string name f.arity in
      let header =
        match f.arity with
        | No_args -> name ^ " takes no arguments"
        | One_arg arg -> name ^ "() requires " ^ arg
        | Two_args (a, b) -> name ^ "() requires " ^ a ^ " and " ^ b
        | Three_args (a, b, c) ->
            name ^ "() requires " ^ a ^ ", " ^ b ^ ", and " ^ c
        | Variable_args _ -> name ^ "() requires arguments"
      in
      let parts = [ header ] in
      let parts = parts @ [ "  usage: " ^ usage ] in
      let parts = parts @ [ "  description: " ^ f.description ] in
      let parts =
        match f.example with
        | Some ex -> parts @ [ "  example: " ^ ex ]
        | None -> parts
      in
      let types =
        f.applicable_to
        |> List.map type_name_of_applicable
        |> String.concat ", "
      in
      let parts = parts @ [ "  applicable to: " ^ types ] in
      String.concat "\n" parts
  | None -> name ^ "() requires an argument"

(* Map 2-argument function names to AST nodes *)
let map_binary_fn (name : string) (arg1 : Ast.expression)
    (arg2 : Ast.expression) : (Ast.expression, string) result =
  let open Ast in
  match name with
  | "while" -> Ok (While (arg1, arg2))
  | "until" -> Ok (Until (arg1, arg2))
  | "recurse" -> Ok (Recurse_with (arg1, arg2))
  | "try" -> Ok (Try (arg1, Some arg2, None))
  | "limit" -> (
      match arg1 with
      | Literal (Number n) -> Ok (Limit (int_of_float n, arg2))
      | _ ->
          Error
            "limit() first argument must be a number literal\n\
            \  usage: limit(n; generator)\n\
            \  example: limit(3; range(10)) → 0, 1, 2")
  | "skip" -> (
      match arg1 with
      | Literal (Number n) -> Ok (Skip (int_of_float n, arg2))
      | _ ->
          Error
            "skip() first argument must be a number literal\n\
            \  usage: skip(n; generator)\n\
            \  example: skip(2; range(5)) → 2, 3, 4")
  | "sub" -> (
      match (arg1, arg2) with
      | Literal (String pattern), Literal (String replacement) ->
          Ok (Sub (pattern, replacement))
      | Literal (String _), _ ->
          Error
            "sub() second argument must be a string literal\n\
            \  usage: sub(pattern; replacement)\n\
            \  example: sub(\"l\"; \"L\") replaces first match"
      | _, _ ->
          Error
            "sub() first argument must be a string literal pattern\n\
            \  usage: sub(pattern; replacement)\n\
            \  example: sub(\"l\"; \"L\") replaces first match")
  | "gsub" -> (
      match (arg1, arg2) with
      | Literal (String pattern), Literal (String replacement) ->
          Ok (Gsub (pattern, replacement))
      | Literal (String _), _ ->
          Error
            "gsub() second argument must be a string literal\n\
            \  usage: gsub(pattern; replacement)\n\
            \  example: gsub(\"l\"; \"L\") replaces all matches"
      | _, _ ->
          Error
            "gsub() first argument must be a string literal pattern\n\
            \  usage: gsub(pattern; replacement)\n\
            \  example: gsub(\"l\"; \"L\") replaces all matches")
  | "any" -> Ok (Any_with_generator (arg1, arg2))
  | "all" -> Ok (All_with_generator (arg1, arg2))
  | "set_path" | "setpath" -> Ok (Setpath (arg1, arg2))
  | "nth" -> Ok (Nth (arg1, arg2))
  | "raise" -> Ok (Raise (arg1, arg2))
  | "assert" -> Ok (Assert (arg1, Some arg2))
  | "atan2" | "atan" -> Ok (Atan2 (arg1, arg2))
  | "copysign" -> Ok (Copysign (arg1, arg2))
  | "ldexp" -> Ok (Ldexp (arg1, arg2))
  | "fdim" -> Ok (Fdim (arg1, arg2))
  | "remainder" | "drem" -> Ok (Remainder (arg1, arg2))
  | "scalbn" | "scalbln" -> Ok (Scalbn (arg1, arg2))
  | "pow" -> Ok (Pow2 (arg1, arg2))
  (* Not implemented *)
  | "strftime" -> Error "strftime not implemented"
  | "strptime" -> Error "strptime not implemented"
  | "splits" -> Error "splits not implemented (use split)"
  | "sql" -> Error "sql not implemented"
  | "dateadd" | "datesub" -> Error "date arithmetic not implemented"
  | "modulemeta" -> Error "modulemeta not implemented"
  (* Default: generic function application *)
  | _ -> Ok (Apply (name, [ arg1; arg2 ]))

let map_unary_fn (name : string) (arg : Ast.expression) :
    (Ast.expression, string) result =
  let open Ast in
  match name with
  (* Array/iteration functions *)
  | "filter" -> Ok (Map (Select arg))
  | "map" -> Ok (Map arg)
  | "map_values" -> Ok (Map_values arg)
  | "flat_map" -> Ok (Flat_map arg)
  | "select" -> Ok (Select arg)
  | "sort_by" -> Ok (Sort_by arg)
  | "min_by" -> Ok (Min_by arg)
  | "max_by" -> Ok (Max_by arg)
  | "group_by" -> Ok (Group_by arg)
  | "unique_by" -> Ok (Unique_by arg)
  | "find" -> Ok (Find arg)
  | "some" -> Ok (Some_ arg)
  | "path" -> Ok (Path arg)
  | "any" -> Ok (Any_with_condition arg)
  | "all" -> Ok (All_with_condition arg)
  | "walk" -> Ok (Walk arg)
  (* Object functions *)
  | "has" -> Ok (Has arg)
  | "in" -> Ok (In arg)
  | "with_entries" -> Ok (With_entries arg)
  (* String functions *)
  | "startwith" -> Error "startwith is deprecated. Use starts_with instead"
  | "startswith" -> Error "startswith is deprecated. Use starts_with instead"
  | "endwith" -> Error "endwith is deprecated. Use ends_with instead"
  | "endswith" -> Error "endswith is deprecated. Use ends_with instead"
  | "starts_with" -> Ok (Starts_with arg)
  | "ends_with" -> Ok (Ends_with arg)
  | "index" -> Ok (Index_of arg)
  | "rindex" -> Ok (Rindex_of arg)
  | "indices" | "find_indices" -> Ok (Indices arg)
  | "inside" -> Ok (Inside arg)
  | "ltrimstr" | "trim_start" -> Ok (Ltrimstr arg)
  | "rtrimstr" | "trim_end" -> Ok (Rtrimstr arg)
  | "split" -> (
      match arg with
      | Literal (String sep) -> Ok (Split (Literal (String sep)))
      | _ ->
          Error
            "split() requires a string literal separator\n\
            \  expected: string literal\n\
            \  example: split(\",\") splits \"a,b,c\" into [\"a\", \"b\", \
             \"c\"]")
  | "join" -> (
      match arg with
      | Literal (String sep) -> Ok (Join (Literal (String sep)))
      | _ ->
          Error
            "join() requires a string literal separator\n\
            \  expected: string literal\n\
            \  example: join(\",\") joins [\"a\", \"b\"] into \"a,b\"")
  | "contains" -> Ok (Contains arg)
  | "bsearch" -> Ok (Bsearch arg)
  (* Regex functions - require string literals *)
  | "test" -> (
      match arg with
      | Literal (String pattern) -> Ok (Test pattern)
      | _ ->
          Error
            "test() requires a string literal pattern\n\
            \  expected: string literal (regex pattern)\n\
            \  example: test(\"^hello\") checks if string starts with 'hello'")
  | "match" -> (
      match arg with
      | Literal (String pattern) -> Ok (Match pattern)
      | _ ->
          Error
            "match() requires a string literal pattern\n\
            \  expected: string literal (regex pattern)\n\
            \  example: match(\"[0-9]+\") returns match object with offset, \
             captures")
  | "scan" -> (
      match arg with
      | Literal (String pattern) -> Ok (Scan pattern)
      | _ ->
          Error
            "scan() requires a string literal pattern\n\
            \  expected: string literal (regex pattern)\n\
            \  example: scan(\"[0-9]+\") yields all numeric matches")
  | "capture" -> (
      match arg with
      | Literal (String pattern) -> Ok (Capture pattern)
      | _ ->
          Error
            "capture() requires a string literal pattern\n\
            \  expected: string literal (regex pattern with named groups)\n\
            \  example: capture(\"(?<name>\\\\w+)\") returns {name: ...}")
  (* Iteration/limiting functions *)
  | "first" -> Ok (First (Some arg))
  | "last" -> Ok (Last (Some arg))
  | "recurse" -> Ok (Recurse_expr arg)
  | "combinations" -> Ok (Combinations_n arg)
  | "repeat" -> Ok (Repeat arg)
  | "add" -> Ok (Add_expr arg)
  | "isempty" -> Ok (Isempty arg)
  (* Path functions *)
  | "delete_paths" | "delpaths" -> Ok (Delpaths arg)
  | "del" -> Ok (Del arg)
  | "pick" -> Ok (Pick arg)
  | "get_path" | "getpath" -> Ok (Getpath arg)
  | "paths" -> Ok (Paths_filter arg)
  (* Custom functions *)
  | "pluck" -> Ok (Pluck arg)
  | "partition" -> Ok (Partition arg)
  | "find_all" -> Ok (Find_all arg)
  | "find_first" -> Ok (Find_first arg)
  | "paths_to" -> Ok (Paths_to arg)
  (* Control flow *)
  | "assert" -> Ok (Assert (arg, None))
  | "try" -> Ok (Try (arg, None, None))
  | "debug" -> Ok (Debug_msg (Some arg))
  | "error" -> Ok (Error_msg (Some arg))
  | "halt_error" -> (
      match arg with
      | Literal (Number n) -> Ok (Halt_error (Some (int_of_float n)))
      | _ ->
          Error
            "halt_error() requires a number literal exit code\n\
            \  expected: number literal\n\
            \  example: halt_error(1) terminates with exit code 1")
  (* isvalid(expr) -> try (expr | true) catch false *)
  | "isvalid" ->
      Ok
        (Try (Pipe (arg, Literal (Bool true)), Some (Literal (Bool false)), None))
  (* Not implemented *)
  | "format" -> Error "format not implemented"
  | "strftime" -> Error "strftime not implemented"
  | "strptime" -> Error "strptime not implemented"
  | "todateiso8601" | "fromdateiso8601" ->
      Error "ISO date functions not implemented"
  | "localtime" | "gmtime" -> Error "time zone functions not implemented"
  | "mktime" -> Error "mktime not implemented"
  | "tojsonstream" | "fromjsonstream" | "truncate_stream" ->
      Error "JSON stream functions not implemented"
  | "splits" -> Error "splits not implemented (use split)"
  | "tojson" | "fromjson" ->
      Error
        "tojson/fromjson not implemented (use tostring/input is already JSON)"
  | "ascii" -> Error "ascii not implemented"
  | "modulemeta" -> Error "modulemeta not implemented"
  | "input" | "inputs" ->
      Error "input/inputs not implemented (query-json reads all input upfront)"
  | "env" ->
      Error "env() with arg not implemented (use $ENV.name or env object)"
  | "builtins" -> Error "builtins not implemented"
  | "limit" -> Error "limit first argument must be a number literal"
  | "until" | "while" ->
      Error (name ^ " requires two arguments: condition and update")
  (* Default: generic function application *)
  | _ -> Ok (Apply (name, [ arg ]))

(* Map 0-argument function/identifier names to AST nodes *)
let map_nullary_fn (name : string) : (Ast.expression, string) result =
  let open Ast in
  match name with
  (* Basic values *)
  | "empty" -> Ok Empty
  | "null" -> Ok (Literal Null)
  | "true" -> Ok (Literal (Bool true))
  | "false" -> Ok (Literal (Bool false))
  | "nan" -> Ok Nan
  | "not" -> Ok Not
  | "break" -> Ok Break
  | "env" -> Ok Env
  (* Object functions *)
  | "keys" -> Ok Keys
  | "keys_unsorted" -> Ok Keys_unsorted
  | "to_entries" -> Ok To_entries
  | "from_entries" -> Ok From_entries
  (* Array functions *)
  | "head" -> Ok Head
  | "tail" -> Ok Tail
  | "length" -> Ok Length
  | "utf8bytelength" -> Ok Utf8bytelength
  | "type" -> Ok Type
  | "sort" -> Ok Sort
  | "uniq" | "unique" -> Ok Unique
  | "reverse" -> Ok Reverse
  | "min" -> Ok Min
  | "max" -> Ok Max
  | "any" -> Ok Any
  | "all" -> Ok All
  | "first" -> Ok (First None)
  | "last" -> Ok (Last None)
  | "combinations" -> Ok Combinations
  | "transpose" -> Ok (Transpose Identity)
  (* String functions *)
  | "tostring" -> Error "tostring is deprecated. Use to_string instead"
  | "to_string" -> Ok To_string
  | "tonumber" -> Error "tonumber is deprecated. Use to_number instead"
  | "to_number" -> Ok To_number
  | "explode" -> Ok Explode
  | "implode" -> Ok Implode
  | "ascii_upcase" | "to_uppercase" -> Ok Ascii_upcase
  | "ascii_downcase" | "to_lowercase" -> Ok Ascii_downcase
  | "trim" -> Ok Trim
  | "ltrim" -> Ok Ltrim
  | "rtrim" -> Ok Rtrim
  (* Math functions *)
  | "floor" -> Ok Floor
  | "sqrt" -> Ok Sqrt
  | "abs" -> Ok (Fun Absolute)
  | "add" -> Ok (Fun Add)
  | "sin" -> Ok (Fun Sin)
  | "cos" -> Ok (Fun Cos)
  | "tan" -> Ok (Fun Tan)
  | "asin" -> Ok (Fun Asin)
  | "acos" -> Ok (Fun Acos)
  | "atan" -> Ok (Fun Atan)
  | "log" -> Ok (Fun Log)
  | "log10" -> Ok (Fun Log10)
  | "exp" -> Ok (Fun Exp)
  | "pow" -> Ok (Fun Pow)
  | "ceil" -> Ok (Fun Ceil)
  | "round" -> Ok (Fun Round)
  | "infinite" -> Ok (Fun Infinite)
  | "now" -> Ok (Fun Now)
  | "sinh" -> Ok (Fun Sinh)
  | "cosh" -> Ok (Fun Cosh)
  | "tanh" -> Ok (Fun Tanh)
  | "asinh" -> Ok (Fun Asinh)
  | "acosh" -> Ok (Fun Acosh)
  | "atanh" -> Ok (Fun Atanh)
  | "is_infinite" | "isinfinite" -> Ok (Fun Isinfinite)
  | "is_normal" | "isnormal" -> Ok (Fun Isnormal)
  | "trunc" -> Ok (Fun Trunc)
  | "fabs" -> Ok (Fun Fabs)
  | "cbrt" -> Ok (Fun Cbrt)
  | "expm1" -> Ok (Fun Expm1)
  | "exp2" -> Ok (Fun Exp2)
  | "log1p" -> Ok (Fun Log1p)
  | "log2" -> Ok (Fun Log2)
  | "nearbyint" | "rint" -> Ok (Fun Nearbyint)
  | "logb" -> Ok (Fun Logb)
  | "isnan" | "is_nan" -> Ok Is_nan
  (* Recursion *)
  | "recurse" -> Ok Recurse
  | "recurse_down" -> Ok Recurse_down
  (* Path functions *)
  | "paths" -> Ok Paths
  | "leaf_paths" -> Ok Leaf_paths
  (* Control flow *)
  | "error" -> Ok (Error_msg None)
  | "halt" -> Ok Halt
  | "halt_error" -> Ok (Halt_error None)
  (* Type selectors - equivalent to select(type == "...") *)
  | "numbers" ->
      Ok (Select (Operation (Type, Equal, Literal (String "number"))))
  | "strings" ->
      Ok (Select (Operation (Type, Equal, Literal (String "string"))))
  | "objects" ->
      Ok (Select (Operation (Type, Equal, Literal (String "object"))))
  | "arrays" -> Ok (Select (Operation (Type, Equal, Literal (String "array"))))
  | "booleans" ->
      Ok (Select (Operation (Type, Equal, Literal (String "boolean"))))
  | "nulls" -> Ok (Select (Operation (Type, Equal, Literal (String "null"))))
  | "iterables" ->
      Ok
        (Select
           (Operation
              ( Operation (Type, Equal, Literal (String "array")),
                Or,
                Operation (Type, Equal, Literal (String "object")) )))
  | "values" -> Ok (Select (Operation (Identity, Not_equal, Literal Null)))
  | "scalars" ->
      Ok
        (Select
           (Operation
              ( Operation (Type, Not_equal, Literal (String "array")),
                And,
                Operation (Type, Not_equal, Literal (String "object")) )))
  (* Debug/IO *)
  | "debug" -> Ok (Debug_msg None)
  | "stderr" -> Ok Stderr
  (* Custom functions *)
  | "compact" -> Ok Compact
  | "is_empty" -> Ok Is_empty
  | "is_blank" -> Ok Is_blank
  | "descend" -> Ok Descend
  | "dive" -> Ok Dive
  (* Time functions *)
  | "localtime" -> Ok Localtime
  | "gmtime" -> Ok Gmtime
  | "mktime" -> Ok Mktime
  (* isvalid without argument: try (. | true) catch false *)
  | "isvalid" ->
      Ok
        (Try
           ( Pipe (Identity, Literal (Bool true)),
             Some (Literal (Bool false)),
             None ))
  | "builtins" -> Ok Builtins
  | "formats" -> Ok Formats
  (* Functions that require arguments - use rich error messages *)
  | "select" | "map" | "map_values" | "flat_map" | "walk" | "sort_by" | "min_by"
  | "max_by" | "group_by" | "unique_by" | "find" | "path" | "with_entries"
  | "has" | "in" | "contains" | "split" | "join" | "starts_with" | "ends_with"
  | "trim_start" | "trim_end" | "del" | "pick" | "pluck" | "partition"
  | "bsearch" | "inside" | "index" | "rindex" | "indices" | "find_indices"
  | "test" | "match" | "scan" | "capture" | "isempty" | "assert" | "nth"
  | "limit" | "skip" | "while" | "until" | "sub" | "gsub" ->
      Error (error_for_missing_arg name)
  (* Not implemented *)
  | "input" | "inputs" ->
      Error "input/inputs not implemented (query-json reads all input upfront)"
  | "strftime" | "strptime" -> Error "time formatting not implemented"
  | "modulemeta" -> Error "modulemeta not implemented"
  | "tojsonstream" | "fromjsonstream" | "truncate_stream" ->
      Error "JSON stream functions not implemented"
  | "tojson" | "fromjson" ->
      Error
        "tojson/fromjson not implemented (use tostring/input is already JSON)"
  | "input_filename" | "input_line_number" ->
      Error "input metadata not implemented"
  | "fma" -> Error "fma requires three arguments: fma(x; y; z)"
  | "atan2" | "copysign" | "ldexp" | "fdim" | "remainder" | "drem" | "scalbn"
  | "scalbln" ->
      Error (name ^ " requires two arguments")
  | "frexp" | "modf" ->
      Error (name ^ " not implemented (returns multiple values)")
  | "significand" | "lgamma" | "tgamma" | "j0" | "j1" | "y0" | "y1" ->
      Error "special math functions not implemented"
  | "exp10" -> Error "exp10 not implemented"
  | "getpath" | "get_path" -> Error "getpath requires an argument"
  | "setpath" | "set_path" | "delpaths" | "delete_paths" ->
      Error (name ^ " requires arguments")
  (* Default: generic function application with no args *)
  | _ -> Ok (Apply (name, []))
