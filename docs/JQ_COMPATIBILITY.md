# jq Compatibility Guide

This guide helps jq users migrate to query-json, and understand the query-json language design.

While query-json implements most of jq's functionality, v1 introduces intentional improvements to the language that break strict compatibility with jq.

## Contents

- [Easier to Learn](#easier-to-learn)
  - [Interactive REPL with autocomplete](#interactive-repl-with-autocomplete)
  - [Helpful error messages](#helpful-error-messages)
  - [Built-in function reference](#built-in-function-reference)
- [Stricter null handling](#stricter-null-handling)
- [Syntax Changes](#syntax-changes)
  - [`fn` for user-defined functions](#fn-for-user-defined-functions)
  - [Snake_case naming](#snake_case-naming)
  - [Clearer naming](#clearer-naming)
- [Behavioral Differences](#behavioral-differences)
  - [`group_by` returns an object](#group_by-returns-an-object)
  - [`infinite` is a generator](#infinite-is-a-generator)
  - [`keys` preserves insertion order](#keys-preserves-insertion-order)
  - [`unique` preserves insertion order](#unique-preserves-insertion-order)
- [Optional Access on Functions](#optional-access-on-functions)
- [Feature Parity](#feature-parity)
  - [Fully Supported](#fully-supported)
  - [Core Functions](#core-functions)
  - [Not Implemented](#not-implemented)
- [Additional Features](#additional-features-in-query-json)
- [Video Demos](#video-demos)
  - [Available Demos](#available-demos)
  - [Generating Videos](#generating-videos)

---

## Easier to Learn

One of jq's biggest pain points is discoverability—you need to constantly reference the manual. query-json is designed to be learnable without leaving your terminal.

### Interactive REPL with autocomplete

The REPL provides context-aware autocomplete—it knows what functions work with your current data type:

```bash
query-json --repl data.json
```

- Type `.` and see all keys in your JSON
- Type `|` and see functions that work with the current output type
- Press `Tab` to complete, `Enter` to apply
- See function descriptions and examples inline

### Helpful error messages

When something goes wrong, query-json tells you *why* and *how to fix it*. Every error includes context and often a hint for how to resolve it.

#### Missing key with suggestions

```
error[key_not_found]: key `naem` not found
  --> .naem
      ^^^^

  in: {"name": "Alice", "age": 30}
  available keys: name, age
  hint: use `.naem?` for optional access
```

jq just says: `jq: error: null (null) has no keys`

#### Type mismatch with context

```
error[type_mismatch]: cannot apply `length` to number
  --> .age | length
            ^^^^^^

  expected: string, array, or object
  found: number
  in: 30
```

jq says: `jq: error: number (30) has no length`

#### Index out of bounds

```
error[index_out_of_bounds]: index `10` out of bounds (length: 3)
  --> .[10]
      ^^^^

  hint: use `.[10]?` for optional access
```

jq silently returns `null` (which can hide bugs!)

#### Missing function argument

```
error[missing_argument]: `map` requires an argument
  --> .users | map
              ^^^

  note: usage: `map(expr)`
  note: Transform each element
  example: [1, 2, 3] | map(. * 2) → [2, 4, 6]
```

jq says: `jq: error: map/0 is not defined`

#### Null access

```
error[null_access]: cannot access key `name` on null
  --> .missing.name
              ^^^^^

  hint: check if value exists before accessing
```

jq silently returns `null`

#### Deprecated function with migration hint

```
error[deprecated]: `tostring` is deprecated
  hint: use `to_string` instead
```

#### Parse errors with location

```
error[parse_error]: unexpected token `}`
  --> {name: .foo}
            ^

  expected: string literal for object key
```

jq says: `jq: error: syntax error, unexpected '}'`

### Built-in function reference

Browse all available functions by category, with descriptions and examples:

```bash
# List all categories
query-json --functions

# Available help categories:
#   string   - String manipulation functions
#   array    - Array manipulation functions
#   object   - Object manipulation functions
#   path     - Path and traversal functions
#   math     - Mathematical functions
#   type     - Type checking and conversion functions
#   control  - Control flow and iteration functions
#   ...

# Get detailed help for a category
query-json --functions string

# String manipulation functions
#
#   split - Split string by separator
#     "a,b,c" | split(",") → ["a", "b", "c"]
#   join - Join array elements with separator
#     ["a", "b"] | join(",") → "a,b"
#   ...
```

---

## Stricter null handling

query-json is stricter about null operations. This catches bugs early instead of silently propagating null values through your pipeline.

### Null arithmetic

```bash
# jq allows this (and silently coerces null to 0)
echo 'null' | jq '. + 1'
# Output: 1

# query-json raises an error
echo 'null' | query-json '. + 1'
# Error: Cannot add number to null
```

### Null key access

```bash
# jq silently returns null
echo '{"a": null}' | jq '.a.b.c'
# Output: null

# query-json tells you what happened
echo '{"a": null}' | query-json '.a.b'
# error[null_access]: cannot access key `b` on null
#   hint: check if value exists before accessing
```

### Use optional access when null is expected

If you *want* null propagation, use the `?` operator:

```bash
# Optional access - returns null without error
query-json '.missing?' '{"name": "Alice"}'
# Output: null

query-json '.a.b?' '{"a": null}'
# Output: null
```

### Try-catch for error handling

For more complex error handling, use `try-catch` (same syntax as jq):

```bash
# jq
jq 'try .foo.bar catch "not found"'

# query-json (same syntax)
query-json 'try .foo.bar catch "not found"'
```

---

## Syntax Changes

### `fn` for user-defined functions

jq uses `def` to define functions, but query-json uses `fn` mostly because you're defining a *function*, not a *definition*:

```bash
# jq
jq         'def double: . * 2; [1,2,3] | map(double)'

# query-json
query-json 'fn double: . * 2; [1,2,3] | map(double)'
```

### Snake_case naming

jq uses compressed names like `tostring` and `startswith`. query-json uses `snake_case` for readability—words are separated by underscores, making them easier to read and type:

| Category | jq | query-json |
|----------|-----|------------|
| **Type conversion** | | |
| | `tostring` | `to_string` |
| | `tonumber` | `to_number` |
| **String predicates** | | |
| | `startswith(s)` | `starts_with(s)` |
| | `endswith(s)` | `ends_with(s)` |
| **Type checking** | | |
| | `isnan` | `is_nan` |
| | `isinfinite` | `is_infinite` |
| | `isnormal` | `is_normal` |
| **Emptiness checks** | | |
| | `isempty(expr)` | `is_empty(expr)` |
| **Path operations** | | |
| | `getpath(path)` | `get_path(path)` |
| | `setpath(path; value)` | `set_path(path; value)` |
| | `delpaths(paths)` | `delete_paths(paths)` |
| **Array searching** | | |
| | `indices(s)` | `find_indices(s)` |

### Clearer naming

Some jq names are cryptic. query-json uses names that are self-explanatory and easy to autocomplete:

| jq | query-json | Why it's better |
|----|------------|-----------------|
| `..` | `descend` | Readable name instead of cryptic operator |
| `ltrimstr(s)` | `trim_start(s)` | `trim_` triggers autocomplete; "l" for "left" is cryptic |
| `rtrimstr(s)` | `trim_end(s)` | "r" for "right" is not obvious |
| `ascii_upcase` | `to_uppercase` | Not just ASCII, and clearer intent |
| `ascii_downcase` | `to_lowercase` | Not just ASCII, and clearer intent |
| `utf8bytelength` | `byte_length` | Shorter, and UTF-8 is implied |

Example:

```bash
# jq
jq '.name | ascii_upcase | startswith("JOHN")'

# query-json
query-json '.name | to_uppercase | starts_with("JOHN")'
```

---

## Behavioral Differences

### `group_by` returns an object

In jq, `group_by` returns an array of arrays. In query-json, it returns an object with keys being the grouped values:

```bash
# jq
echo '[{"x":1},{"x":2},{"x":1}]' | jq 'group_by(.x)'
# Output: [[{"x":1},{"x":1}],[{"x":2}]]

# query-json
echo '[{"x":1},{"x":2},{"x":1}]' | query-json 'group_by(.x)'
# Output: {"1":[{"x":1},{"x":1}],"2":[{"x":2}]}
```

This makes it easier to access groups by key and is more intuitive for most use cases.

Migrating from jq's `group_by`:

```bash
# jq - get items grouped by category
jq 'group_by(.category) | map({key: .[0].category, items: .})'

# query-json - already returns an object!
query-json 'group_by(.category)'

# To get the same structure as jq:
query-json 'group_by(.category) | to_entries | map({key, items: .value})'
```

### `infinite` is a generator

In jq, `infinite` represents IEEE infinity. In query-json, `infinite` is a generator that produces 0, 1, 2, ... forever:

```bash
# query-json
query-json '[limit(5; infinite)]' <<< 'null'
# Output: [0, 1, 2, 3, 4]
```

Use `limit` to constrain the output, or use it with `first`/`nth`.

### `keys` preserves insertion order

In jq, `keys` returns sorted keys, and `keys_unsorted` preserves insertion order. In query-json, `keys` preserves insertion order (the more common need). Use `keys | sort` if you need sorted keys:

```bash
# jq
echo '{"b":1, "a":2}' | jq 'keys'
# Output: ["a", "b"]  (sorted)

# query-json
echo '{"b":1, "a":2}' | query-json 'keys'
# Output: ["b", "a"]  (insertion order)

# query-json: if you need sorted keys
echo '{"b":1, "a":2}' | query-json 'keys | sort'
# Output: ["a", "b"]
```

### `unique` preserves insertion order

In jq, `unique` sorts the result. In query-json, `unique` preserves insertion order (keeping the first occurrence of each value):

```bash
# jq sorts the result
echo '[3, 1, 2, 1, 3, 2]' | jq 'unique'
# Output: [1, 2, 3]

# query-json preserves order
echo '[3, 1, 2, 1, 3, 2]' | query-json 'unique'
# Output: [3, 1, 2]

# query-json: if you need sorted unique values
echo '[3, 1, 2, 1, 3, 2]' | query-json 'unique | sort'
# Output: [1, 2, 3]
```

---

## Optional Access on Functions

In jq, the `?` operator only works on field access (`.foo?`) and indexing (`.[0]?`). In query-json, `?` works on any expression, including function calls:

```bash
# Optional nullary functions
query-json 'first?' '[]'        # null (instead of error)
query-json 'keys?' '123'        # null (instead of error)

# Optional function calls
query-json 'first?(empty)' 'null'    # null
query-json 'nth(10)?' '[1,2,3]'      # null

# Both syntaxes work
query-json 'first?(range(3))' 'null' # 0
query-json 'first(range(3))?' 'null' # 0
```

This makes error handling more consistent. Can use `?` in places that aren't sure about your data, and you want `null` instead of an error.

---

## Feature Parity

### Fully Supported

- **Basic filters**: `.`, `.foo`, `.foo.bar`, `.[]`, `.[0]`, `.[2:5]`, `.foo?`
- **Operators**: `+`, `-`, `*`, `/`, `%`, `==`, `!=`, `<`, `>`, `<=`, `>=`, `and`, `or`, `not`
- **Pipes and composition**: `|`, `,`, `??` (alternative)
- **Conditionals**: `if-then-else-end`, `if-then-elif-else-end`
- **Variables**: `. as $x | ...`, `$ENV.VAR`
- **String interpolation**: `"Hello \(.name)"`
- **Try-catch**: `try expr`, `try expr catch handler`
- **Reduce**: `reduce .[] as $x (init; update)`
- **Foreach**: `foreach .[] as $x (init; update; extract)`
- **User functions**: `fn name: body;`, `fn name(args): body;`

These work exactly like jq:

### Core Functions

| Category | Functions |
|----------|-----------|
| **Array** | `map`, `select`, `sort`, `sort_by`, `unique`, `unique_by`, `group_by`, `reverse`, `flatten`, `first`, `last`, `nth`, `add`, `min`, `max`, `min_by`, `max_by`, `any`, `all`, `contains`, `inside`, `index`, `rindex`, `indices`, `transpose`, `combinations`, `bsearch` |
| **Object** | `keys`, `has`, `in`, `to_entries`, `from_entries`, `with_entries`, `del`, `pick` |
| **String** | `split`, `join`, `trim`, `trim_start`, `trim_end`, `starts_with`, `ends_with`, `to_uppercase`, `to_lowercase`, `length`, `explode`, `implode` |
| **Regex** | `test`, `match`, `scan`, `capture`, `sub`, `gsub` |
| **Math** | `abs`, `floor`, `ceil`, `round`, `sqrt`, `log`, `log10`, `exp`, `pow`, `sin`, `cos`, `tan`, `asin`, `acos`, `atan` |
| **Type** | `type`, `to_string`, `to_number`, `numbers`, `strings`, `booleans`, `nulls`, `arrays`, `objects`, `iterables`, `scalars`, `values` |
| **Path** | `path`, `paths`, `leaf_paths`, `get_path`, `set_path`, `del`, `delete_paths`, `recurse`, `walk` |
| **Control** | `empty`, `error`, `range`, `limit`, `skip`, `first`, `last`, `nth`, `while`, `until`, `repeat` |

### Not Implemented

The following jq features are not available in query-json:

| Feature | Notes |
|---------|-------|
| **Modules** | `import`, `include`, `modulemeta` |
| **Format strings** | `@text`, `@json`, `@csv`, `@tsv`, `@base64`, `@uri`, `@html` |
| **Streaming** | `--stream`, `truncate_stream`, `fromstream`, `tostream` |
| **Date/time** | `strftime`, `strptime`, `now` returns Unix timestamp but formatting is limited |
| **SQL-style** | `INDEX`, `IN`, `GROUP_BY` (SQL-style operators) |
| **I/O** | `input`, `inputs`, `debug` message customization |
| **Comments in queries** | `# comment` syntax in queries |

---

## Additional Features in query-json

query-json includes some functions not found in jq:

| Function | Description | Example |
|----------|-------------|---------|
| `filter(expr)` | Alias for `map(select(expr))` | `filter(.active)` |
| `flat_map(expr)` | Map and flatten in one step | `flat_map(.items)` |
| `find(expr)` | Find first matching element | `find(.id == 1)` |
| `some(expr)` | Check if any element matches | `some(.price > 100)` |
| `pluck(expr)` | Extract field from array of objects | `pluck(.name)` |
| `partition(expr)` | Split into matching/non-matching | `partition(.active)` |
| `is_empty` | Check if empty (no args) | `[] \| is_empty` |
| `is_blank` | Check if null, empty, or whitespace | `"  " \| is_blank` |
| `dive` | Depth-first traversal | `[dive \| strings]` |
| `find_all(expr)` | Find all matching at any depth | `find_all(type=="number")` |
| `paths_to(expr)` | Get paths to all matching values | `paths_to(type=="string")` |

---

## Video Demos

All the examples in this guide have corresponding VHS tape demos. You can find them in [`docs/jq-compat-demos/`](./jq-compat-demos/) and generate the videos using [VHS](https://github.com/charmbracelet/vhs).

### Available Demos

| Demo | Description | Tape File |
|------|-------------|-----------|
| **Error Messages** | Helpful error messages with context and hints | [`00-error-messages.tape`](./jq-compat-demos/00-error-messages.tape) |
| **Null Handling** | Stricter null handling catches bugs early | [`01-stricter-null-handling.tape`](./jq-compat-demos/01-stricter-null-handling.tape) |
| **fn vs def** | `fn` keyword for user-defined functions | [`02-fn-vs-def.tape`](./jq-compat-demos/02-fn-vs-def.tape) |
| **Snake_case** | Readable `snake_case` function names | [`03-snake-case-naming.tape`](./jq-compat-demos/03-snake-case-naming.tape) |
| **Clearer Naming** | Self-explanatory function names | [`04-clearer-naming.tape`](./jq-compat-demos/04-clearer-naming.tape) |
| **group_by** | Returns object instead of array of arrays | [`05-group-by-behavior.tape`](./jq-compat-demos/05-group-by-behavior.tape) |
| **keys** | Preserves insertion order | [`06-keys-insertion-order.tape`](./jq-compat-demos/06-keys-insertion-order.tape) |
| **unique** | Preserves insertion order | [`07-unique-insertion-order.tape`](./jq-compat-demos/07-unique-insertion-order.tape) |
| **infinite** | Generator producing 0, 1, 2, ... | [`08-infinite-generator.tape`](./jq-compat-demos/08-infinite-generator.tape) |
| **Optional Functions** | `?` works on function calls | [`09-optional-access-functions.tape`](./jq-compat-demos/09-optional-access-functions.tape) |
| **Additional Features** | Features unique to query-json | [`10-additional-features.tape`](./jq-compat-demos/10-additional-features.tape) |
| **All Demos** | Complete overview of all differences | [`all-demos.tape`](./jq-compat-demos/all-demos.tape) |

### Generating Videos

To generate all demo videos:

```bash
# Generate all demos
for tape in docs/jq-compat-demos/*.tape; do
  vhs "$tape"
done

# Or generate a specific demo
vhs docs/jq-compat-demos/all-demos.tape
```

The generated `.mp4` files will be placed in `docs/jq-compat-demos/`.
