# Complex jq Programs Collection

A collection of 10 real-world jq programs that go beyond simple expressions, demonstrating advanced features like custom functions, recursion, reduce, foreach, and complex data transformations.

---

## 1. Send More Money Puzzle Solver

Solves the classic verbal arithmetic puzzle where SEND + MORE = MONEY, where each letter represents a unique digit.

```jq
def send_more_money:
  def choose(m;n;used): ([range(m;n+1)] - used)[];
  def num(a;b;c;d): 1000*a + 100*b + 10*c + d;
  def num(a;b;c;d;e): 10*num(a;b;c;d) + e;
  first(
    1 as $m
    | 0 as $o
| choose(8;9;[]) as $s
    | choose(2;9;[$s]) as $e
    | choose(2;9;[$s;$e]) as $n
    | choose(2;9;[$s;$e;$n]) as $d
    | choose(2;9;[$s;$e;$n;$d]) as $r
    | choose(2;9;[$s;$e;$n;$d;$r]) as $y
    | select(num($s;$e;$n;$d) + num($m;$o;$r;$e) == num($m;$o;$n;$e;$y))
    | {
        send: num($s;$e;$n;$d),
        more: num($m;$o;$r;$e),
        money: num($m;$o;$n;$e;$y),
        solution: {s:$s, e:$e, n:$n, d:$d, m:$m, o:$o, r:$r, y:$y}
      }
  );

send_more_money
```

*Source: [Wikipedia - jq programming language](https://en.wikipedia.org/wiki/Jq_%28programming_language%29)*

---

## 2. Integer to Arbitrary Base Conversion

Converts an integer to any base between 2 and 36, using nested function definitions and recursion.

```jq
def tobase($b):
  def digit: "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"[.:.+1];
  def mod: . % $b;
  def div: ((. - mod) / $b);
  def digits: recurse(select(. >= $b) | div) | mod;
  select(2 <= $b and $b <= 36)
  | [digits | digit] | reverse | add;

# Usage: 255 | tobase(16) => "FF"
# Usage: 42 | tobase(2) => "101010"
```

*Source: [Wikipedia - jq programming language](https://en.wikipedia.org/wiki/Jq_%28programming_language%29)*

---

## 3. Flatten Nested JSON to Dot-Notation Keys

Transforms arbitrarily nested JSON into a flat object with dot-separated keys.

```jq
def flatten_json:
  . as $data
  | [path(.. | select(type != "object" and type != "array"))] as $paths
  | reduce $paths[] as $path (
      {};
      . + {($path | map(tostring) | join(".")): ($data | getpath($path))}
    );

# Alternative using tostream:
def flatten_stream:
  reduce (tostream | select(length == 2) | .[0] |= [join(".")]) as [$p, $v] (
    {};
    setpath($p; $v)
  );

flatten_json
```

**Example Input:**
```json
{
  "one": {
    "start-string": "foo",
    "integer-number": 101
  },
  "two": [
    {"nested": {"value": 42}}
  ]
}
```

**Output:**
```json
{
  "one.start-string": "foo",
  "one.integer-number": 101,
  "two.0.nested.value": 42
}
```

*Source: [Stack Overflow](https://stackoverflow.com/questions/37540717/flatten-nested-json-using-jq)*

---

## 4. Cumulative Sum with Foreach

Calculates running totals across multiple fields in an array of records.

```jq
def cumulative_sums:
  [foreach .[] as $row (
    {nbrMembers: 0, nbrWallets: 0, nbrTransactions: 0};
    {
      nbrMembers: (.nbrMembers + ($row.nbrMembers // 0)),
      nbrWallets: (.nbrWallets + ($row.nbrWallets // 0)),
      nbrTransactions: (.nbrTransactions + ($row.nbrTransactions // 0))
    };
    $row + {
      cumulative_nbrMembers: .nbrMembers,
      cumulative_nbrWallets: .nbrWallets,
      cumulative_nbrTransactions: .nbrTransactions
    }
  )];

cumulative_sums
```

**Example Input:**
```json
[
  {"date": "2020-01-01", "nbrMembers": 5, "nbrWallets": 10},
  {"date": "2020-01-02", "nbrMembers": 3, "nbrWallets": 7},
  {"date": "2020-01-03", "nbrMembers": 8, "nbrWallets": 2}
]
```

*Source: [Stack Overflow](https://stackoverflow.com/questions/64146079/multiple-statements-with-jq-cumulate-multiple-fields)*

---

## 5. Walk-Based Deep Key Filter

Filters a complex nested JSON structure to keep only specific keys at any depth level.

```jq
def filter_keys($allowed_keys):
  walk(
    if type == "object" then
      with_entries(
        select(.key | IN($allowed_keys[]))
      )
    else
      .
    end
  );

def filter_keys_regex($pattern):
  walk(
    if type == "object" then
      with_entries(
        select(.key | test($pattern))
      )
    else
      .
    end
  );

# Keep only id, name, and image fields at any level
filter_keys(["id", "name", "image", "children"])
```

**Example Input:**
```json
{
  "id": 1,
  "name": "root",
  "secret": "hidden",
  "children": [
    {
      "id": 2,
      "name": "child",
      "password": "secret123",
      "image": "child.png"
    }
  ]
}
```

*Source: [Stack Overflow](https://stackoverflow.com/questions/66332143/filter-keys-on-various-levels-from-large-complex-nested-json)*

---

## 6. Explode Nested Arrays with Cross Product

Expands nested arrays into flat records, producing a cross-product of all nested elements.

```jq
def explode_nested:
  . as $root
  | $root.r1 as $r1
  | $root.r2 as $r2
  | $root.r3 as $r3
  | $root.ver as $ver
  | $root.noa1[]
  | . as $noa1
  | .noa2[]
  | . as $noa2
  | {
      r1: $r1,
      r2: $r2,
      r3: $r3,
      ver: $ver,
      col1: $noa1.col1,
      aon: ($noa2.aon[]? // null),
      col10: $noa2.obj.col10?,
      col11: $noa2.obj.col11?,
      aos: ($noa2.obj.aos[]? // null)
    };

[explode_nested]
```

**Example Input:**
```json
{
  "r1": "ex",
  "r2": "of",
  "r3": "da",
  "ver": 1,
  "noa1": [
    {
      "col1": 380,
      "noa2": [
        {"aon": [123, 456], "obj": {"col10": "foo", "col11": "bar", "aos": ["A", "B"]}},
        {"aon": [789], "obj": {"col10": "baz", "col11": "qux"}}
      ]
    }
  ]
}
```

*Source: [Stack Overflow](https://stackoverflow.com/questions/74103310/explode-complex-json-object-with-objects-and-arrays-with-jq)*

---

## 7. JSON to CSV with Dynamic Headers

Converts an array of JSON objects to CSV format, automatically extracting headers from the first object.

```jq
def to_csv:
  def escape_csv:
    tostring
    | gsub("\""; "\"\"")
    | if test("[,\"\n\r]") then "\"" + . + "\"" else . end;

  def row_to_csv:
    map(escape_csv) | join(",");

  (.[0] | keys_unsorted) as $headers
  | [$headers] + [.[] | [.[$headers[]]]]
  | map(row_to_csv)
  | join("\n");

# For nested structures, flatten first then convert
def nested_to_csv:
  def flatten_object:
    . as $obj
    | reduce (keys_unsorted[]) as $k (
        {};
        if ($obj[$k] | type) == "object" then
          . + ($obj[$k] | flatten_object | with_entries(.key = $k + "." + .key))
        elif ($obj[$k] | type) == "array" then
          . + {($k): ($obj[$k] | @json)}
        else
          . + {($k): $obj[$k]}
        end
      );
  map(flatten_object) | to_csv;

to_csv
```

**Example Input:**
```json
[
  {"name": "Alice", "age": 30, "city": "NYC"},
  {"name": "Bob", "age": 25, "city": "LA"},
  {"name": "Carol", "age": 35, "city": "Chicago"}
]
```

*Source: [jq Manual](https://jqlang.org/manual/)*

---

## 8. Deep Object Diff

Compares two JSON objects and returns the differences, showing added, removed, and changed fields.

```jq
def diff($a; $b):
  def paths_and_values:
    . as $root
    | [path(.. | select(type != "object" and type != "array"))]
    | map({path: ., value: ($root | getpath(.))});

  ($a | paths_and_values) as $a_paths
  | ($b | paths_and_values) as $b_paths
  | ($a_paths | map(.path | tojson)) as $a_keys
  | ($b_paths | map(.path | tojson)) as $b_keys
  | {
      added: [
        $b_paths[]
        | select((.path | tojson) | IN($a_keys[]) | not)
        | {path: .path, value: .value}
      ],
      removed: [
        $a_paths[]
        | select((.path | tojson) | IN($b_keys[]) | not)
        | {path: .path, value: .value}
      ],
      changed: [
        $a_paths[]
        | . as $ap
        | select((.path | tojson) | IN($b_keys[]))
        | ($b | getpath($ap.path)) as $new_val
        | select($ap.value != $new_val)
        | {path: $ap.path, old: $ap.value, new: $new_val}
      ]
    }
  | if (.added | length) == 0 and (.removed | length) == 0 and (.changed | length) == 0 then
      {equal: true}
    else
      . + {equal: false}
    end;

# Usage: diff(input1; input2)
```

*Source: Community contribution*

---

## 9. Group, Aggregate, and Pivot

Groups records by a key, aggregates values, and pivots the data into a summary table.

```jq
def group_and_aggregate($group_key; $value_key):
  group_by(.[$group_key])
  | map({
      key: .[0][$group_key],
      count: length,
      sum: (map(.[$value_key] // 0) | add),
      avg: ((map(.[$value_key] // 0) | add) / length),
      min: (map(.[$value_key]) | min),
      max: (map(.[$value_key]) | max),
      values: map(.[$value_key])
    });

def pivot($row_key; $col_key; $val_key):
  group_by(.[$row_key])
  | map(
      .[0][$row_key] as $rk
      | reduce .[] as $item (
          {($row_key): $rk};
          . + {($item[$col_key] | tostring): $item[$val_key]}
        )
    );

# Usage example:
# Input: [{"region": "East", "product": "A", "sales": 100}, ...]
# group_and_aggregate("region"; "sales")
# pivot("region"; "product"; "sales")
```

**Example Input:**
```json
[
  {"region": "East", "product": "Widget", "sales": 100},
  {"region": "East", "product": "Gadget", "sales": 150},
  {"region": "West", "product": "Widget", "sales": 200},
  {"region": "West", "product": "Gadget", "sales": 75}
]
```

*Source: Various jq cookbook examples*

---

## 10. Recursive Schema Extraction

Analyzes a JSON document and extracts its schema, including types and nested structures.

```jq
def extract_schema:
  def type_of:
    type as $t
    | if $t == "array" then
        if length == 0 then "array<empty>"
        else "array<" + (.[0] | type_of) + ">"
        end
      elif $t == "object" then "object"
      elif $t == "null" then "null"
      else $t
      end;

  def schema_of:
    type as $t
    | if $t == "object" then
        reduce (to_entries[]) as $e (
          {};
          . + {($e.key): ($e.value | schema_of)}
        )
      elif $t == "array" then
        if length == 0 then {_type: "array", _items: "unknown"}
        else {
          _type: "array",
          _items: (
            [.[] | schema_of]
            | group_by(.)
            | map(.[0])
            | if length == 1 then .[0]
              else {_oneOf: .}
              end
          )
        }
        end
      else
        {_type: type_of}
      end;

  schema_of
  | walk(
      if type == "object" and has("_type") and (.keys | length) == 1 then
        ._type
      else
        .
      end
    );

extract_schema
```

**Example Input:**
```json
{
  "users": [
    {"id": 1, "name": "Alice", "active": true},
    {"id": 2, "name": "Bob", "active": false}
  ],
  "metadata": {
    "version": "1.0",
    "count": 2
  }
}
```

**Output:**
```json
{
  "users": {
    "_type": "array",
    "_items": {
      "id": "number",
      "name": "string",
      "active": "boolean"
    }
  },
  "metadata": {
    "version": "string",
    "count": "number"
  }
}
```

*Source: Community contribution*

---

## Bonus: FizzBuzz in jq

Classic FizzBuzz implemented in jq, demonstrating conditionals and string interpolation.

```jq
def fizzbuzz:
  range(1; 101)
  | if . % 15 == 0 then "FizzBuzz"
    elif . % 3 == 0 then "Fizz"
    elif . % 5 == 0 then "Buzz"
    else . | tostring
    end;

[fizzbuzz]
```

*Source: Programming interview classic*

