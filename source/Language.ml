type applicable_to = String | Array | Object | Number | Bool | Nil | Any

type arity =
  | No_args
  | One_arg of string
  | Two_args of string * string
  | Three_args of string * string * string
  | Variable_args of string

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
          example = Some {|"a,b,c" | split(",") → ["a", "b", "c"]|};
          applicable_to = [ String ];
          insert_text = None;
          arity = One_arg "separator";
        };
        {
          name = "join";
          aliases = [];
          description = "Join array elements with separator";
          example = Some {|["a", "b"] | join(",") → "a,b"|};
          applicable_to = [ Array ];
          insert_text = None;
          arity = One_arg "separator";
        };
        {
          name = "trim";
          aliases = [];
          description = "Remove whitespace from both ends";
          example = Some {|"  hello  " | trim → "hello"|};
          applicable_to = [ String ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "trim_start";
          aliases = [];
          description = "Remove prefix string";
          example = Some {|"foobar" | trim_start("foo") → "bar"|};
          applicable_to = [ String ];
          insert_text = None;
          arity = One_arg "prefix";
        };
        {
          name = "trim_end";
          aliases = [];
          description = "Remove suffix string";
          example = Some {|"foobar" | trim_end("bar") → "foo"|};
          applicable_to = [ String ];
          insert_text = None;
          arity = One_arg "suffix";
        };
        {
          name = "starts_with";
          aliases = [];
          description = "Check if string starts with prefix";
          example = Some {|"hello" | starts_with("he") → true|};
          applicable_to = [ String ];
          insert_text = None;
          arity = One_arg "prefix";
        };
        {
          name = "ends_with";
          aliases = [];
          description = "Check if string ends with suffix";
          example = Some {|"hello" | ends_with("lo") → true|};
          applicable_to = [ String ];
          insert_text = None;
          arity = One_arg "suffix";
        };
        {
          name = "contains";
          aliases = [];
          description = "Check if string contains substring";
          example = Some {|"hello" | contains("ell") → true|};
          applicable_to = [ String; Array; Object ];
          insert_text = None;
          arity = One_arg "json";
        };
        {
          name = "to_lowercase";
          aliases = [];
          description = "Convert to lowercase";
          example = Some {|"HELLO" | to_lowercase → "hello"|};
          applicable_to = [ String ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "to_uppercase";
          aliases = [];
          description = "Convert to uppercase";
          example = Some {|"hello" | to_uppercase → "HELLO"|};
          applicable_to = [ String ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "length";
          aliases = [];
          description = "Get string length";
          example = Some {|"hello" | length → 5|};
          applicable_to = [ String; Array; Object ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "test";
          aliases = [];
          description = "Test if string matches regex";
          example = Some {|"hello" | test("^he") → true|};
          applicable_to = [ String ];
          insert_text = None;
          arity = One_arg "pattern";
        };
        {
          name = "match";
          aliases = [];
          description = "Match regex and return match info";
          example = Some {|"foo bar" | match("bar") → {offset: 4, ...}|};
          applicable_to = [ String ];
          insert_text = None;
          arity = One_arg "pattern";
        };
        {
          name = "scan";
          aliases = [];
          description = "Find all regex matches";
          example = Some {|"a1b2c3" | [scan("[0-9]+")] → ["1", "2", "3"]|};
          applicable_to = [ String ];
          insert_text = None;
          arity = One_arg "pattern";
        };
        {
          name = "replace";
          aliases = [ "sub" ];
          description = "Replace first regex match";
          example = Some {|"hello" | replace("l"; "L") → "heLlo"|};
          applicable_to = [ String ];
          insert_text = None;
          arity = Two_args ("pattern", "replacement");
        };
        {
          name = "replace_all";
          aliases = [ "gsub" ];
          description = "Replace all regex matches";
          example = Some {|"hello" | replace_all("l"; "L") → "heLLo"|};
          applicable_to = [ String ];
          insert_text = None;
          arity = Two_args ("pattern", "replacement");
        };
        {
          name = "to_codepoints";
          aliases = [ "explode" ];
          description = "Convert string to array of Unicode codepoints";
          example = Some {|"hi" | to_codepoints → [104, 105]|};
          applicable_to = [ String ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "from_codepoints";
          aliases = [ "implode" ];
          description = "Convert array of Unicode codepoints to string";
          example = Some {|[72, 105] | from_codepoints → "Hi"|};
          applicable_to = [ Array ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "index";
          aliases = [];
          description = "Find first index of substring";
          example = Some {|"hello" | index("l") → 2|};
          applicable_to = [ String; Array ];
          insert_text = None;
          arity = One_arg "needle";
        };
        {
          name = "last_index";
          aliases = [ "rindex" ];
          description = "Find last index of substring or element";
          example = Some {|"hello" | last_index("l") → 3|};
          applicable_to = [ String; Array ];
          insert_text = None;
          arity = One_arg "needle";
        };
        {
          name = "find_indices";
          aliases = [ "indices" ];
          description = "Find all indices of substring";
          example = Some {|"ababa" | find_indices("a") → [0, 2, 4]|};
          applicable_to = [ String; Array ];
          insert_text = None;
          arity = One_arg "needle";
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
          aliases = [];
          description = "Select elements matching condition";
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
          aliases = [];
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
          name = "binary_search";
          aliases = [ "bsearch" ];
          description = "Binary search (array must be sorted)";
          example = Some {|[1, 2, 3] | binary_search(2) → 1|};
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
          description = "Get array of keys in original order";
          example = Some {|{b:1, a:2} | keys → ["b", "a"]|};
          applicable_to = [ Object ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "has";
          aliases = [];
          description = "Check if key exists";
          example = Some {|{a:1} | has("a") → true|};
          applicable_to = [ Object; Array ];
          insert_text = None;
          arity = One_arg "key";
        };
        {
          name = "in";
          aliases = [];
          description = "Check if key exists in object";
          example = Some {|"a" | in({a:1}) → true|};
          applicable_to = [ String; Number ];
          insert_text = None;
          arity = One_arg "object";
        };
        {
          name = "to_entries";
          aliases = [];
          description = "Convert to [{key, value}, ...]";
          example = Some {|{a:1} | to_entries → [{key:"a", value:1}]|};
          applicable_to = [ Object ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "from_entries";
          aliases = [];
          description = "Convert from [{key, value}, ...] to object";
          example = Some {|[{key:"a", value:1}] | from_entries → {a:1}|};
          applicable_to = [ Array ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "with_entries";
          aliases = [];
          description = "Transform each {key, value} entry";
          example = Some {|{a:1} | with_entries(.value += 1) → {a:2}|};
          applicable_to = [ Object ];
          insert_text = None;
          arity = One_arg "expr";
        };
        {
          name = "delete";
          aliases = [];
          description = "Delete key at path";
          example = Some {|{a:1, b:2} | delete(.a) → {b:2}|};
          applicable_to = [ Object; Array ];
          insert_text = None;
          arity = One_arg "path";
        };
        {
          name = "pick";
          aliases = [];
          description = "Select only specified paths";
          example = Some {|{a:1, b:2, c:3} | pick(.a, .c) → {a:1, c:3}|};
          applicable_to = [ Object ];
          insert_text = None;
          arity = One_arg "paths";
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
          example = Some {|{a:{b:1}} | path(.a.b) → ["a", "b"]|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = One_arg "expr";
        };
        {
          name = "paths";
          aliases = [];
          description = "Get all paths in value";
          example = Some {|{a:{b:1}} | [paths] → [["a"], ["a","b"]]|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "leaf_paths";
          aliases = [];
          description = "Get paths to leaf values only";
          example = Some {|{a:{b:1}} | [leaf_paths] → [["a", "b"]]|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "get_path";
          aliases = [];
          description = "Get value at path";
          example = Some {|{a:{b:1}} | get_path(["a","b"]) → 1|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = One_arg "path";
        };
        {
          name = "set_path";
          aliases = [];
          description = "Set value at path";
          example = Some {|{a:1} | set_path(["b"]; 2) → {a:1, b:2}|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = Two_args ("path", "value");
        };
        {
          name = "delete_paths";
          aliases = [];
          description = "Delete multiple paths";
          example = Some {|{a:1, b:2} | delete_paths([["a"]]) → {b:2}|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = One_arg "paths";
        };
        {
          name = "recurse";
          aliases = [];
          description = "Recursively descend into structure";
          example = Some {|{a:{b:1}} | [recurse | numbers] → [1]|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "descend";
          aliases = [];
          description =
            "Breadth-first traversal: yields values level by level, parents \
             before children";
          example = Some {|{a:{b:1}} | [descend] → [{a:{b:1}}, {b:1}, 1]|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "dive";
          aliases = [];
          description =
            "Depth-first traversal: yields each value then immediately its \
             children";
          example = Some {|{a:1, b:2} | [dive] → [{a:1,b:2}, 1, 2]|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "find_all";
          aliases = [];
          description = "Find all values matching condition at any depth";
          example = Some {|{a:1, b:{c:2}} | find_all(type=="number") → [1, 2]|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = One_arg "condition";
        };
        {
          name = "find_first";
          aliases = [];
          description = "Find first value matching condition";
          example = Some {|{a:"x", b:{c:1}} | find_first(type=="number") → 1|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = One_arg "condition";
        };
        {
          name = "paths_to";
          aliases = [];
          description = "Get paths to all matching values";
          example =
            Some
              {|{a:1, b:{c:2}} | paths_to(type=="number") → [["a"], ["b","c"]]|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = One_arg "condition";
        };
        {
          name = "walk";
          aliases = [];
          description = "Transform all values recursively";
          example =
            Some {|{a:1} | walk(if type=="number" then .+1 else . end) → {a:2}|};
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
          example = Some {|-5 | abs → 5|};
          applicable_to = [ Number ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "floor";
          aliases = [];
          description = "Round down";
          example = Some {|3.7 | floor → 3|};
          applicable_to = [ Number ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "ceil";
          aliases = [];
          description = "Round up";
          example = Some {|3.2 | ceil → 4|};
          applicable_to = [ Number ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "round";
          aliases = [];
          description = "Round to nearest integer";
          example = Some {|3.5 | round → 4|};
          applicable_to = [ Number ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "sqrt";
          aliases = [];
          description = "Square root";
          example = Some {|16 | sqrt → 4|};
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
          example = Some {|100 | log10 → 2|};
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
          example = Some {|0 | exp → 1|};
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
          example = Some {|pow(2; 3) → 8|};
          applicable_to = [ Number ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "sin";
          aliases = [];
          description = "Sine";
          example = Some {|0 | sin → 0|};
          applicable_to = [ Number ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "cos";
          aliases = [];
          description = "Cosine";
          example = Some {|0 | cos → 1|};
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
          arity = Two_args ("y", "x");
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
          name = "cube_root";
          aliases = [ "cbrt" ];
          description = "Cube root";
          example = Some {|27 | cube_root → 3|};
          applicable_to = [ Number ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "truncate";
          aliases = [ "trunc" ];
          description = "Truncate toward zero";
          example = Some {|3.7 | truncate → 3|};
          applicable_to = [ Number ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "is_normal";
          aliases = [];
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
          example = Some {|[limit(3; infinite)] → [0, 1, 2]|};
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
          example = Some {|42 | type → "number"|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "to_string";
          aliases = [ "tostring" ];
          description = "Convert to string";
          example = Some {|42 | to_string → "42"|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "to_number";
          aliases = [ "tonumber" ];
          description = "Convert to number";
          example = Some {|"42" | to_number → 42|};
          applicable_to = [ String; Number ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "numbers";
          aliases = [];
          description = "Select only numbers";
          example = Some {|[1, "a", 2] | .[] | numbers → 1, 2|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "strings";
          aliases = [];
          description = "Select only strings";
          example = Some {|[1, "a", 2] | .[] | strings → "a"|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "booleans";
          aliases = [];
          description = "Select only booleans";
          example = Some {|[1, true, "a"] | .[] | booleans → true|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "nulls";
          aliases = [];
          description = "Select only nulls";
          example = Some {|[1, null] | .[] | nulls → null|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "arrays";
          aliases = [];
          description = "Select only arrays";
          example = Some {|[1, [], {}] | .[] | arrays → []|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "objects";
          aliases = [];
          description = "Select only objects";
          example = Some {|[1, [], {}] | .[] | objects → {}|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "iterables";
          aliases = [];
          description = "Select arrays and objects";
          example = Some {|[1, [], {}] | .[] | iterables → [], {}|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "scalars";
          aliases = [];
          description = "Select non-iterables";
          example = Some {|[1, [], "a"] | .[] | scalars → 1, "a"|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "values";
          aliases = [];
          description = "Select non-null values";
          example = Some {|[1, null, 2] | .[] | values → 1, 2|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "is_empty";
          aliases = [];
          description = "Check if array/string/object is empty";
          example = Some {|[] | is_empty → true|};
          applicable_to = [ Array; String; Object; Nil ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "is_blank";
          aliases = [];
          description = "Check if null, empty, or whitespace-only";
          example = Some {|"  " | is_blank → true|};
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
          name = "??";
          aliases = [];
          description = "Alternative operator (on null or false)";
          example = Some {|.foo ?? "default" → "default" if .foo is null/false|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = No_args;
        };
        {
          name = "empty";
          aliases = [];
          description = "Produce no output";
          example = Some {|1, empty, 2 → 1, 2|};
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
          arity = Two_args ("kind", "message");
        };
        {
          name = "assert";
          aliases = [];
          description = "Fail if condition is false";
          example = Some {|assert(. > 0; "must be positive")|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = One_arg "condition";
        };
        {
          name = "range";
          aliases = [];
          description = "Generate number sequence";
          example = Some {|[range(3)] → [0, 1, 2]|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = Variable_args "n or from; to or from; to; step";
        };
        {
          name = "while";
          aliases = [];
          description = "Repeat while condition holds";
          example = Some {|1 | [while(. < 8; . * 2)] → [1, 2, 4]|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = Two_args ("condition", "update");
        };
        {
          name = "until";
          aliases = [];
          description = "Repeat until condition holds";
          example = Some {|1 | [until(. > 8; . * 2)] → [16]|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = Two_args ("condition", "update");
        };
        {
          name = "repeat";
          aliases = [];
          description = "Repeat expression indefinitely";
          example = Some {|1 | [limit(3; repeat(. * 2))] → [2, 4, 8]|};
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
          example = Some {|[limit(2; range(10))] → [0, 1]|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = Two_args ("n", "generator");
        };
        {
          name = "skip";
          aliases = [];
          description = "Skip first n outputs";
          example = Some {|[skip(2; range(5))] → [2, 3, 4]|};
          applicable_to = [ Any ];
          insert_text = None;
          arity = Two_args ("n", "generator");
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
          example = Some {|fn double: . * 2; 5 | double → 10|};
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
  | One_arg arg -> Printf.sprintf "%s(%s)" name arg
  | Two_args (arg1, arg2) -> Printf.sprintf "%s(%s; %s)" name arg1 arg2
  | Three_args (arg1, arg2, arg3) ->
      Printf.sprintf "%s(%s; %s; %s)" name arg1 arg2 arg3
  | Variable_args args -> Printf.sprintf "%s(%s)" name args

let error_for_missing_arg (name : string) : Query_error.t =
  match find_function name with
  | Some f ->
      let usage = arity_to_string name f.arity in
      let message =
        match f.arity with
        | No_args -> Printf.sprintf "%s takes no arguments" name
        | One_arg arg -> Printf.sprintf "%s() requires %s" name arg
        | Two_args (a, b) -> Printf.sprintf "%s() requires %s and %s" name a b
        | Three_args (a, b, c) ->
            Printf.sprintf "%s() requires %s, %s, and %s" name a b c
        | Variable_args _ -> Printf.sprintf "%s() requires arguments" name
      in
      let applicable_to =
        f.applicable_to
        |> List.map type_name_of_applicable
        |> String.concat ", "
      in
      Query_error.missing_argument ~fn_name:name ~message ~usage
        ~description:f.description ~applicable_to ?example:f.example ()
  | None ->
      Query_error.missing_argument ~fn_name:name ~usage:name
        ~description:"Unknown function" ()

(* Check if a function name is a 1-arity function that can accept Identity as default *)
let can_default_to_identity (name : string) : bool =
  match name with
  (* Array/iteration functions that make sense with identity *)
  | "map" | "select" | "sort_by" | "group_by" | "unique_by" | "min_by"
  | "max_by" | "find" | "any" | "all" | "pluck" | "partition" | "walk"
  | "with_entries" | "path" | "paths" | "flat_map" | "map_values" | "repeat"
  | "recurse" | "find_all" | "find_first" | "paths_to" | "is_empty" | "first"
  | "last" | "flatten" | "combinations" | "transpose" | "add" | "delete"
  | "pick" | "assert" | "debug" ->
      true
  (* Functions that require specific argument types (string literals, etc.) *)
  | "test" | "match" | "scan" | "capture" | "split" | "join" | "sub" | "gsub"
  | "starts_with" | "ends_with" | "contains" | "has" | "in" | "inside" | "index"
  | "rindex" | "indices" | "find_indices" | "trim_start" | "trim_end"
  | "bsearch" | "get_path" | "delete_paths" | "error" | "halt_error" | "nth" ->
      false
  | _ -> false

let require_string_literal ~fn_name ~what ~example =
  Query_error.requires_literal ~fn_name ~what ~example

let not_implemented feature = Query_error.not_implemented feature

(* Map 2-argument function names to AST nodes *)
let map_binary_fn (name : string) (arg1 : Ast.expression)
    (arg2 : Ast.expression) : (Ast.expression, Query_error.t) result =
  let open Ast in
  match name with
  | "while" -> Ok (Fn2 (While, arg1, arg2))
  | "until" -> Ok (Fn2 (Until, arg1, arg2))
  | "recurse" -> Ok (Fn2 (Recurse_with, arg1, arg2))
  | "try" -> Ok (Try (arg1, Some arg2, None))
  | "limit" -> (
      match arg1 with
      | Literal ((Int _ | Float _) as n) -> Ok (Fn2 (Limit, Literal n, arg2))
      | _ ->
          Error
            (Query_error.requires_number_literal ~fn_name:"limit"
               ~what:"first argument must be a number literal"
               ~example:"limit(3; range(10)) → 0, 1, 2" ()))
  | "skip" -> (
      match arg1 with
      | Literal ((Int _ | Float _) as n) -> Ok (Fn2 (Skip, Literal n, arg2))
      | _ ->
          Error
            (Query_error.requires_number_literal ~fn_name:"skip"
               ~what:"first argument must be a number literal"
               ~example:"skip(2; range(5)) → 2, 3, 4" ()))
  | "replace" | "sub" -> (
      match (arg1, arg2) with
      | Literal (String _pattern), Literal (String _replacement) ->
          Ok (Fn2 (Replace, arg1, arg2))
      | Literal (String _), _ ->
          Error
            (require_string_literal ~fn_name:"replace" ~what:"replacement"
               ~example:{|replace("l"; "L") replaces first match|})
      | _, _ ->
          Error
            (require_string_literal ~fn_name:"replace" ~what:"pattern"
               ~example:{|replace("l"; "L") replaces first match|}))
  | "replace_all" | "gsub" -> (
      match (arg1, arg2) with
      | Literal (String _pattern), Literal (String _replacement) ->
          Ok (Fn2 (Replace_all, arg1, arg2))
      | Literal (String _), _ ->
          Error
            (require_string_literal ~fn_name:"replace_all" ~what:"replacement"
               ~example:{|replace_all("l"; "L") replaces all matches|})
      | _, _ ->
          Error
            (require_string_literal ~fn_name:"replace_all" ~what:"pattern"
               ~example:{|replace_all("l"; "L") replaces all matches|}))
  | "any" -> Ok (Fn2 (Any_gen, arg1, arg2))
  | "all" -> Ok (Fn2 (All_gen, arg1, arg2))
  | "set_path" -> Ok (Fn2 (Setpath, arg1, arg2))
  | "nth" -> Ok (Fn2 (Nth, arg1, arg2))
  | "raise" -> Ok (Fn2 (Raise, arg1, arg2))
  | "assert" -> Ok (Fn2 (Assert_msg, arg1, arg2))
  | "atan2" | "atan" -> Ok (Fn2 (Atan2, arg1, arg2))
  | "copysign" -> Ok (Fn2 (Copysign, arg1, arg2))
  | "ldexp" -> Ok (Fn2 (Ldexp, arg1, arg2))
  | "fdim" -> Ok (Fn2 (Fdim, arg1, arg2))
  | "remainder" | "drem" -> Ok (Fn2 (Remainder, arg1, arg2))
  | "scalbn" | "scalbln" -> Ok (Fn2 (Scalbn, arg1, arg2))
  | "pow" -> Ok (Fn2 (Pow2, arg1, arg2))
  (* Not implemented *)
  | "strftime" -> Error (not_implemented "strftime")
  | "strptime" -> Error (not_implemented "strptime")
  | "splits" ->
      Error
        (Query_error.not_implemented ~suggestion:"use `split` instead" "splits")
  | "sql" -> Error (not_implemented "sql")
  | "dateadd" | "datesub" -> Error (not_implemented "date arithmetic")
  | "modulemeta" -> Error (not_implemented "modulemeta")
  (* Default: generic function application *)
  | _ -> Ok (Apply (name, [ arg1; arg2 ]))

let compile_regex (pattern : string) :
    (Ast.compiled_regex, Query_error.t) result =
  try Ok { Ast.pattern; regex = Str.regexp pattern }
  with _ -> Error (Query_error.invalid_regex ~pattern)

let make_pattern_fn (fn : Ast.fn1_pattern) (pattern : string) :
    (Ast.expression, Query_error.t) result =
  match compile_regex pattern with
  | Ok compiled -> Ok (Ast.Fn1 (With_pattern (fn, compiled)))
  | Error e -> Error e

let make_separator_fn (fn : Ast.fn1_separator) (sep : string) : Ast.expression =
  Ast.Fn1 (With_separator (fn, sep))

let make_expr_fn (fn : Ast.fn1_expr) (expr : Ast.expression) : Ast.expression =
  Ast.Fn1 (With_expr (fn, expr))

let map_unary_fn (name : string) (arg : Ast.expression) :
    (Ast.expression, Query_error.t) result =
  let open Ast in
  match name with
  (* Array/iteration functions *)
  | "filter" -> Ok (make_expr_fn Map (make_expr_fn Select arg))
  | "map" -> Ok (make_expr_fn Map arg)
  | "map_values" -> Ok (make_expr_fn Map_values arg)
  | "flat_map" -> Ok (make_expr_fn Flat_map arg)
  | "select" -> Ok (make_expr_fn Select arg)
  | "sort_by" -> Ok (make_expr_fn Sort_by arg)
  | "min_by" -> Ok (make_expr_fn Min_by arg)
  | "max_by" -> Ok (make_expr_fn Max_by arg)
  | "group_by" -> Ok (make_expr_fn Group_by arg)
  | "unique_by" -> Ok (make_expr_fn Unique_by arg)
  | "find" -> Ok (make_expr_fn Find arg)
  | "some" -> Ok (make_expr_fn Some_ arg)
  | "path" -> Ok (make_expr_fn Path arg)
  | "any" -> Ok (make_expr_fn Any_cond arg)
  | "all" -> Ok (make_expr_fn All_cond arg)
  | "walk" -> Ok (make_expr_fn Walk arg)
  (* Object functions *)
  | "has" -> Ok (make_expr_fn Has arg)
  | "in" -> Ok (make_expr_fn In arg)
  | "with_entries" -> Ok (make_expr_fn With_entries arg)
  (* String functions - separator-based *)
  | "split" -> (
      match arg with
      | Literal (String sep) -> Ok (make_separator_fn Split sep)
      | _ ->
          Error
            (require_string_literal ~fn_name:"split" ~what:"separator"
               ~example:{|split(",") splits "a,b,c" into ["a", "b", "c"]|}))
  | "join" -> (
      match arg with
      | Literal (String sep) -> Ok (make_separator_fn Join sep)
      | _ ->
          Error
            (require_string_literal ~fn_name:"join" ~what:"separator"
               ~example:{|join(",") joins ["a", "b"] into "a,b"|}))
  (* String functions - expression-based *)
  | "starts_with" -> Ok (make_expr_fn Starts_with arg)
  | "startswith" ->
      Error
        (Query_error.deprecated ~old_name:"startswith" ~new_name:"starts_with")
  | "ends_with" -> Ok (make_expr_fn Ends_with arg)
  | "endswith" ->
      Error (Query_error.deprecated ~old_name:"endswith" ~new_name:"ends_with")
  | "index" -> Ok (make_expr_fn Index_of arg)
  | "last_index" | "rindex" -> Ok (make_expr_fn Last_index_of arg)
  | "indices" | "find_indices" -> Ok (make_expr_fn Indices arg)
  | "inside" -> Ok (make_expr_fn Inside arg)
  | "trim_start" -> Ok (make_expr_fn Trim_start arg)
  | "trim_end" -> Ok (make_expr_fn Trim_end arg)
  | "contains" -> Ok (make_expr_fn Contains arg)
  | "binary_search" | "bsearch" -> Ok (make_expr_fn Binary_search arg)
  (* Regex functions - pattern-based, compiled at parse time *)
  | "test" -> (
      match arg with
      | Literal (String pattern) -> make_pattern_fn Test pattern
      | _ ->
          Error
            (require_string_literal ~fn_name:"test" ~what:"regex pattern"
               ~example:{|test("^hello") checks if string starts with "hello"|})
      )
  | "match" -> (
      match arg with
      | Literal (String pattern) -> make_pattern_fn Match pattern
      | _ ->
          Error
            (require_string_literal ~fn_name:"match" ~what:"regex pattern"
               ~example:
                 {|match("[0-9]+") returns match object with offset, captures|})
      )
  | "scan" -> (
      match arg with
      | Literal (String pattern) -> make_pattern_fn Scan pattern
      | _ ->
          Error
            (require_string_literal ~fn_name:"scan" ~what:"regex pattern"
               ~example:{|scan("[0-9]+") yields all numeric matches|}))
  | "capture" -> (
      match arg with
      | Literal (String pattern) -> make_pattern_fn Capture pattern
      | _ ->
          Error
            (require_string_literal ~fn_name:"capture" ~what:"regex pattern"
               ~example:{|capture("(?<name>\\w+)") returns {name: ...}|}))
  (* Iteration/limiting functions *)
  | "first" -> Ok (make_expr_fn First_expr arg)
  | "last" -> Ok (make_expr_fn Last_expr arg)
  | "nth" -> Ok (make_expr_fn Nth_array arg)
  | "recurse" -> Ok (make_expr_fn Recurse_expr arg)
  | "combinations" -> Ok (make_expr_fn Combinations_n arg)
  | "repeat" -> Ok (make_expr_fn Repeat arg)
  | "add" -> Ok (make_expr_fn Add_expr arg)
  | "is_empty" -> Ok (make_expr_fn Is_empty_expr arg)
  | "flatten" -> Ok (make_expr_fn Flatten_n arg)
  | "transpose" -> Ok (make_expr_fn Transpose_expr arg)
  (* Path functions *)
  | "delete_paths" -> Ok (make_expr_fn Delpaths arg)
  | "delete" -> Ok (make_expr_fn Delete arg)
  | "pick" -> Ok (make_expr_fn Pick arg)
  | "get_path" -> Ok (make_expr_fn Getpath arg)
  | "paths" -> Ok (make_expr_fn Paths_filter arg)
  (* Custom functions *)
  | "pluck" -> Ok (make_expr_fn Pluck arg)
  | "partition" -> Ok (make_expr_fn Partition arg)
  | "find_all" -> Ok (make_expr_fn Find_all arg)
  | "find_first" -> Ok (make_expr_fn Find_first arg)
  | "paths_to" -> Ok (make_expr_fn Paths_to arg)
  (* Control flow *)
  | "assert" -> Ok (make_expr_fn Assert_simple arg)
  | "try" -> Ok (Try (arg, None, None))
  | "debug" -> Ok (make_expr_fn Debug_msg arg)
  | "error" -> Ok (make_expr_fn Error_msg arg)
  | "halt_error" -> (
      match arg with
      | Literal (Int _ | Int64 _ | Big_int _ | Float _) ->
          Ok (make_expr_fn Halt_error_n arg)
      | _ ->
          Error
            (Query_error.requires_number_literal ~fn_name:"halt_error"
               ~what:"requires a number literal exit code"
               ~example:"halt_error(1) terminates with exit code 1" ()))
  (* is_valid(expr) -> try (expr | true) catch false *)
  | "is_valid" ->
      Ok
        (Try (Pipe (arg, Literal (Bool true)), Some (Literal (Bool false)), None))
  (* Not implemented *)
  | "format" -> Error (not_implemented "format")
  | "strftime" -> Error (not_implemented "strftime")
  | "strptime" -> Error (not_implemented "strptime")
  | "todateiso8601" | "fromdateiso8601" ->
      Error (not_implemented "ISO date functions")
  | "localtime" | "gmtime" -> Error (not_implemented "time zone functions")
  | "mktime" -> Error (not_implemented "mktime")
  | "tojsonstream" | "fromjsonstream" | "truncate_stream" ->
      Error (not_implemented "JSON stream functions")
  | "splits" ->
      Error
        (Query_error.not_implemented ~suggestion:"use `split` instead" "splits")
  | "tojson" | "fromjson" ->
      Error
        (Query_error.not_implemented
           ~suggestion:"use `to_string` (input is already JSON)"
           "tojson/fromjson")
  | "ascii" -> Error (not_implemented "ascii")
  | "modulemeta" -> Error (not_implemented "modulemeta")
  | "input" | "inputs" ->
      Error
        (Query_error.not_implemented
           ~description:"query-json reads all input upfront" "input/inputs")
  | "env" ->
      Error
        (Query_error.unsupported ~fn_name:"env"
           ~message:"with argument is not supported"
           ~suggestion:"use `$ENV.name` or `env.name` instead" ())
  | "builtins" -> Error (not_implemented "builtins")
  | "limit" ->
      Error
        (Query_error.requires_number_literal ~fn_name:"limit"
           ~what:"first argument must be a number literal"
           ~example:"limit(3; range(10))" ())
  | "until" | "while" ->
      let example =
        if name = "while" then "[while(. < 100; . * 2)]"
        else "[until(. > 100; . * 2)]"
      in
      Error
        (Query_error.missing_argument ~fn_name:name
           ~message:(Printf.sprintf "`%s` requires two arguments" name)
           ~usage:"condition and update expressions"
           ~description:"Loop construct" ~example ())
  (* Default: generic function application *)
  | _ -> Ok (Apply (name, [ arg ]))

(* Map 0-argument function/identifier names to AST nodes *)
let map_nullary_fn (name : string) : (Ast.expression, Query_error.t) result =
  let open Ast in
  match name with
  (* Basic values *)
  | "empty" -> Ok (Fn0 Empty)
  | "null" -> Ok (Literal Null)
  | "true" -> Ok (Literal (Bool true))
  | "false" -> Ok (Literal (Bool false))
  | "nan" -> Ok (Fn0 Nan)
  | "not" -> Ok (Fn0 Not)
  | "break" -> Ok (Fn0 Break)
  | "env" -> Ok (Fn0 Env)
  (* Object functions *)
  | "keys" -> Ok (Fn0 Keys)
  | "to_entries" -> Ok (Fn0 To_entries)
  | "from_entries" -> Ok (Fn0 From_entries)
  (* Array functions *)
  | "head" -> Ok (Fn0 First)
  | "tail" -> Ok (Fn0 Last)
  | "length" -> Ok (Fn0 Length)
  | "byte_length" -> Ok (Fn0 Byte_length)
  | "type" -> Ok (Fn0 Type)
  | "sort" -> Ok (Fn0 Sort)
  | "unique" -> Ok (Fn0 Unique)
  | "reverse" -> Ok (Fn0 Reverse)
  | "min" -> Ok (Fn0 Min)
  | "max" -> Ok (Fn0 Max)
  | "any" -> Ok (Fn0 Any)
  | "all" -> Ok (Fn0 All)
  | "first" -> Ok (Fn0 First)
  | "last" -> Ok (Fn0 Last)
  | "combinations" -> Ok (Fn0 Combinations)
  | "transpose" -> Ok (Fn0 Transpose)
  | "flatten" -> Ok (Fn0 Flatten)
  | "add" -> Ok (Fn0 Add)
  (* String functions *)
  | "tostring" ->
      Error (Query_error.deprecated ~old_name:"tostring" ~new_name:"to_string")
  | "to_string" -> Ok (Fn0 To_string)
  | "tonumber" ->
      Error (Query_error.deprecated ~old_name:"tonumber" ~new_name:"to_number")
  | "to_number" -> Ok (Fn0 To_number)
  | "to_codepoints" | "explode" -> Ok (Fn0 To_codepoints)
  | "from_codepoints" | "implode" -> Ok (Fn0 From_codepoints)
  | "to_uppercase" -> Ok (Fn0 To_uppercase)
  | "to_lowercase" -> Ok (Fn0 To_lowercase)
  | "trim" -> Ok (Fn0 Trim)
  | "trim_left" ->
      Error (Query_error.deprecated ~old_name:"trim_left" ~new_name:"trim")
  | "left_trim" ->
      Error (Query_error.deprecated ~old_name:"left_trim" ~new_name:"trim")
  | "trim_right" ->
      Error (Query_error.deprecated ~old_name:"trim_right" ~new_name:"trim")
  | "right_trim" ->
      Error (Query_error.deprecated ~old_name:"right_trim" ~new_name:"trim")
  (* Math functions *)
  | "floor" -> Ok (Fn0 Floor)
  | "sqrt" -> Ok (Fn0 Sqrt)
  | "abs" -> Ok (Fn0 Abs)
  | "sin" -> Ok (Fn0 Sin)
  | "cos" -> Ok (Fn0 Cos)
  | "tan" -> Ok (Fn0 Tan)
  | "asin" -> Ok (Fn0 Asin)
  | "acos" -> Ok (Fn0 Acos)
  | "atan" -> Ok (Fn0 Atan)
  | "log" -> Ok (Fn0 Log)
  | "log10" -> Ok (Fn0 Log10)
  | "exp" -> Ok (Fn0 Exp)
  | "pow" -> Ok (Fn0 Pow)
  | "ceil" -> Ok (Fn0 Ceil)
  | "round" -> Ok (Fn0 Round)
  | "infinite" -> Ok (Fn0 Infinite)
  | "now" -> Ok (Fn0 Now)
  | "sinh" -> Ok (Fn0 Sinh)
  | "cosh" -> Ok (Fn0 Cosh)
  | "tanh" -> Ok (Fn0 Tanh)
  | "asinh" -> Ok (Fn0 Asinh)
  | "acosh" -> Ok (Fn0 Acosh)
  | "atanh" -> Ok (Fn0 Atanh)
  | "is_normal" -> Ok (Fn0 Is_normal)
  | "isnormal" ->
      Error (Query_error.deprecated ~old_name:"isnormal" ~new_name:"is_normal")
  | "truncate" | "trunc" -> Ok (Fn0 Truncate)
  | "fabs" -> Error (Query_error.deprecated ~old_name:"fabs" ~new_name:"abs")
  | "cube_root" | "cbrt" -> Ok (Fn0 Cube_root)
  | "expm1" -> Ok (Fn0 Expm1)
  | "exp2" -> Ok (Fn0 Exp2)
  | "log1p" -> Ok (Fn0 Log1p)
  | "log2" -> Ok (Fn0 Log2)
  | "nearbyint" | "rint" -> Ok (Fn0 Nearbyint)
  | "logb" -> Ok (Fn0 Logb)
  | "isnan" -> Ok (Fn0 Is_nan)
  (* Recursion *)
  | "recurse" -> Ok (Fn0 Recurse)
  | "recurse_down" -> Ok (Fn0 Recurse_down)
  (* Path functions *)
  | "paths" -> Ok (Fn0 Paths)
  | "leaf_paths" -> Ok (Fn0 Leaf_paths)
  (* Control flow *)
  | "error" -> Ok (make_expr_fn Error_msg Identity)
  | "halt" -> Ok (Fn0 Halt)
  | "halt_error" -> Ok (make_expr_fn Halt_error_n (Literal (Int 5)))
  (* Type selectors *)
  | "numbers" -> Ok (Fn0 Numbers)
  | "strings" -> Ok (Fn0 Strings)
  | "objects" -> Ok (Fn0 Objects)
  | "arrays" -> Ok (Fn0 Arrays)
  | "booleans" -> Ok (Fn0 Booleans)
  | "nulls" -> Ok (Fn0 Nulls)
  | "iterables" -> Ok (Fn0 Iterables)
  | "values" -> Ok (Fn0 Values)
  | "scalars" -> Ok (Fn0 Scalars)
  (* Debug/IO *)
  | "debug" -> Ok (Fn0 Debug)
  | "stderr" -> Ok (Fn0 Stderr)
  (* Custom functions *)
  | "is_empty" -> Ok (Fn0 Is_empty)
  | "is_blank" -> Ok (Fn0 Is_blank)
  | "descend" -> Ok (Fn0 Descend)
  | "dive" -> Ok (Fn0 Dive)
  (* Time functions *)
  | "localtime" -> Ok (Fn0 Localtime)
  | "gmtime" -> Ok (Fn0 Gmtime)
  | "mktime" -> Ok (Fn0 Mktime)
  (* is_valid without argument: try (. | true) catch false *)
  | "is_valid" ->
      Ok
        (Try
           ( Pipe (Identity, Literal (Bool true)),
             Some (Literal (Bool false)),
             None ))
  | "builtins" -> Ok (Fn0 Builtins)
  (* Not implemented *)
  | "strftime" | "strptime" -> Error (not_implemented "time formatting")
  | "modulemeta" -> Error (not_implemented "modulemeta")
  | "tojsonstream" | "fromjsonstream" | "truncate_stream" ->
      Error (not_implemented "JSON stream functions")
  | "tojson" | "fromjson" ->
      Error
        (Query_error.not_implemented
           ~suggestion:"use `to_string` (input is already JSON)"
           "tojson/fromjson")
  | "input_filename" | "input_line_number" ->
      Error (not_implemented "input metadata")
  (* Default: check registry for functions that require arguments *)
  | _ -> (
      match find_function name with
      | Some f when f.arity <> No_args -> Error (error_for_missing_arg name)
      | _ -> Ok (Apply (name, [])))
