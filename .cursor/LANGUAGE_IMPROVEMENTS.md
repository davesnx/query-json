Following the plan: let's implement 5 now. Keep adding tests for features in @test/Test_runtime.ml and @test/Test_errors.ml. Also, the parser @source/Parser.mly should have 0 conflicts, so @source/Parser.conflicts should not exist (it should raise an issue if the file exists, conceptually)!

Also, add any problem with the design of the language in the document @.cursor/LANGUAGE_IMPROVEMENTS.md

# query-json Language Improvements

This document outlines planned language design improvements over jq, making query-json **safer**, **more consistent**, and **easier to reason about**.

## Design Principles

1. **Strict by default** — Errors should be explicit, not silent
2. **Inspectable errors** — Programmatic error handling should be possible
3. **Context-rich** — Errors should show what went wrong and where
4. **Consistent** — Naming and behavior should be predictable
5. **Modern syntax** — Use familiar patterns from modern languages
6. **No jq compatibility** — We render helpful errors for jq operations to teach users the new syntax

---

## Table of Contents

1. [Core Safety](#1-core-safety)
2. [Error Handling](#2-error-handling)
3. [Operators](#3-operators)
4. [Syntax Improvements](#4-syntax-improvements)
5. [Naming Conventions](#5-naming-conventions)
6. [New Functions & Helpers](#6-new-functions--helpers)
7. [Behavior Changes](#7-behavior-changes)
8. [Tooling & Developer Experience](#8-tooling--developer-experience)
9. [Design Decisions](#9-design-decisions)

---

## 1. Core Safety

### 1.1 Strict Member Access

**Problem in jq:**
```bash
echo '{}' | jq '.foo.bar.baz'  # Returns null silently
echo '[1,2]' | jq '.[5]'       # Returns null silently
```

**query-json solution:**
Member access fails by default when the key/index doesn't exist:
```bash
echo '{}' | query-json '.foo'
# Error:  Key 'foo' not found in object
#    {}
# Hint:   Use .foo? for optional access
```

Use `?` for opt-in leniency:
```bash
echo '{}' | query-json '.foo?'   # Returns null
echo '[1,2]' | query-json '.[5]?'  # Returns null
```

The `?` suffix works on any expression:
```bash
echo '{}' | query-json '.foo.bar.baz?'   # null (entire chain is optional)
echo '{}' | query-json '(.foo?).bar'     # Error: null has no field 'bar'
```

---

### 1.2 No Implicit Type Coercion

**Problem in jq:**
```bash
echo '{"a": "foo"}' | jq '.a + null'   # "foo" (null disappears!)
echo '{"a": []}' | jq '.a + null'      # [] (null disappears!)
echo 'null' | jq '. + "x"'             # "x" (null becomes empty string!)
```

**query-json solution:**
All type mismatches fail explicitly:
```bash
echo '{"a": "foo"}' | query-json '.a + null'
# Error:   Cannot add null to string "foo"
# Hint:    Use .a + (.b ?? "") for explicit null handling
```

---

### 1.3 No Cross-Type Comparisons

**Problem in jq:**
jq has an arbitrary total ordering: `null < false < true < numbers < strings < arrays < objects`

This hides bugs:
```bash
echo '{}' | jq '"5" < 10'  # true (compares by type order, not value!)
```

**query-json solution:**
Cross-type comparisons are errors:
```bash
echo '{}' | query-json '"5" < 10'
# Error:   Cannot compare string "5" with number 10
# Hint:    Use to_number for conversion
```

---

### 1.4 Strict Built-in Functions

All functions that can fail are strict by default:

| Function | Strict (default) | Optional (`?`) |
|----------|------------------|----------------|
| `first` | Error on empty array | `first?` returns null |
| `last` | Error on empty array | `last?` returns null |
| `nth(n)` | Error if out of bounds | `nth?(n)` returns null |
| `get_path(p)` | Error if path missing | `get_path?(p)` returns null |

---

## 2. Error Handling

### 2.1 Structured Errors

**Problem in jq:**
`try-catch` gives you a string error message with no structure:
```bash
echo '{}' | jq 'try .foo catch .'
# "null (null) has no object key \"foo\""
```

**query-json solution:**
Errors are structured JSON objects with full context:
```bash
echo '{}' | query-json 'try .foo catch $error'
```

`$error` structure:
```json
{
  "kind": "key_not_found",
  "message": "Key 'foo' not found in object",
  "path": ".foo",
  "details": {
    "key": "foo",
    "available_keys": []
  },
  "value": {},
  "suggestion": "The object is empty. Use .foo? for optional access."
}
```

**Error kinds:**
- `key_not_found` - accessing missing object key
- `index_out_of_bounds` - array index out of range
- `null_access` - attempting operation on null
- `type_mismatch` - wrong type for operation
- `validation_error` - user-raised validation error
- `user_error` - raised with `error()`

---

### 2.2 Stack Traces

Each error includes a stack trace (when the `--trace` flag is set) with operation and input value:
```bash
echo '{"a":{"b":{}}}' | query-json --trace '.a.b.c'
# Error: Key 'c' not found
# at .c on {}
# Hint: The object is empty
```

---

### 2.3 `try` Always Requires `catch`

**Problem in jq:**
`try expr` without `catch` silently returns nothing on error, hiding failures:
```bash
echo '{}' | jq 'try .foo'  # Returns nothing (empty output!)
```

**query-json solution:**
`try` always requires `catch`:
```bash
# Error: 'try' requires 'catch' clause
echo '{}' | query-json 'try .foo'

# Correct usage:
echo '{}' | query-json 'try .foo catch null'
echo '{}' | query-json 'try .foo catch $error'
```

If you want to suppress errors, use `?` instead:
```bash
echo '{}' | query-json '.foo?'  # Returns null
```

---

### 2.4 `raise` for Custom Errors

```
fn validate ->
  if type != "object" then
    raise("validation_error", "Expected object, got \(type)")
  elif .name == null then
    raise("validation_error", "Missing required field: name")
  else
    .
  end

try (.data | validate) catch $error |
  if $error.kind == "validation_error" then
    {valid: false, reason: $error.message}
  else
    raise  # re-raise unexpected errors
  end
```

---

### 2.5 `finally` for Cleanup

```
try
  .data | expensive_transform
catch $error
  log_error($error) | null
finally
  cleanup_resources
```

---

## 3. Operators

### 3.1 Null-Coalescing Operator (`??`)

**Problem in jq:**
The `//` operator triggers on both `null` AND `false`:
```bash
echo '{"active": false}' | jq '.active // true'  # true (wrong!)
```

**query-json solution:**
Add `??` operator that only triggers on `null`:
```
.foo ?? "default"           # Only if .foo is null
.settings.theme ?? "dark"   # Only if theme is null
.active ?? true             # false stays false!
```

---

### 3.2 Remove `//` Operator

With `??` available, `//` is removed entirely. It was confusing and error-prone.

If you need "falsy coalescing" (trigger on null OR false), be explicit:
```
if .value == null or .value == false then "default" else .value end
```

---

### 3.3 Update Operator

**Problem in jq:**
```jq
.foo |= . + 1   # update: . is .foo
.foo = . + 1    # assign: . is the parent!
```

This is a major source of confusion.

**query-json solution:**
Use `update()` function for clarity:
```
update(.foo, . + 1)      # . inside update refers to .foo
update(.items[], . * 2)  # update each item
```

The `=` operator works as expected for assignment:
```
.foo = 42                # simple assignment
.foo = .bar + 1          # . refers to the root
```

---

## 4. Syntax Improvements

### 4.1 Comments

Comments use `#` (same as jq):
```
# This is a comment
.foo | map(. + 1)  # inline comment
```

---

### 4.2 Template Literals

**Problem in jq:**
String interpolation uses awkward backslash-parentheses:
```bash
echo '{"name":"world"}' | jq '"Hello, \(.name)!"'
```

**query-json solution:**
Modern template literal syntax:
```
`Hello, ${.name}!`
`The sum is ${.a + .b}`
`Item ${$i} of ${$total}`
```

---

### 4.3 Pattern Matching with `match`

**Problem in jq:**
Type-based branching is verbose:
```jq
if type == "array" then
  map(. * 2)
elif type == "object" then
  .value
elif type == "number" then
  . * 2
else
  error("unexpected type")
end
```

**query-json solution:**
```
match type {
  "array"  -> map(. * 2)
  "object" -> .value
  "number" -> . * 2
  _        -> error("unexpected type")
}
```

No trailing commas. Each arm is `pattern -> expression`.

---

### 4.4 Destructuring

**Problem in jq:**
Repeated field access is verbose:
```jq
.user | "\(.name) <\(.email)>"
```

**query-json solution:**
```
.user | {name, email} -> `${name} <${email}>`
```

Also works in other contexts:
```
# With renaming
.user | {name, email: mail} -> `${name} <${mail}>`

# With nested destructuring
.user | {name, address: {city, country}} -> `${name} lives in ${city}, ${country}`
```

---

### 4.5 Spread Operator for Objects

```
{
  ...defaults
  ...config
  override: "value"
}
```

Cleaner than jq's `+` with confusing precedence.

---

### 4.6 Field Shorthand in Object Construction

**Problem in jq:**
```jq
{name: .name, age: .age, email: .email}
```

**query-json solution:**
```
{.name, .age, .email}
```

---

### 4.7 Improved `reduce` Syntax

**Problem in jq:**
Bizarre syntax with semicolons and implicit accumulator:
```jq
reduce .[] as $x (0; . + $x)
```

**query-json solution:**
Named accumulator with clearer syntax:
```
reduce(.[], 0, fn(acc, x) -> acc + x)
```

Or with piped input:
```
.[] | fold(0, fn(acc, x) -> acc + x)
```

Both are equivalent. `reduce` takes an iterable, `fold` operates on an already-iterating stream.

---

### 4.8 Use `fn` instead of `def`

**Problem in jq:**
`def` is verbose and the syntax is inconsistent with modern languages:
```jq
def double: . * 2;
def add(x): . + x;
def add(x; y): x + y;  # Semicolons for multiple args?!
```

**query-json solution:**
Use `fn` with consistent, modern syntax:
```
fn double -> . * 2
fn add(x) -> . + x
fn add(x, y) -> x + y  # Commas, like every other language
```

**Benefits:**
- `fn` is shorter and more recognizable (Rust, Elixir, etc.)
- Commas for argument separation (universal convention)
- `->` clearly indicates the function body
- Consistent with lambda/arrow function syntax in other contexts

---

### 4.9 Commas for All Function Arguments

**Problem in jq:**
Some functions use semicolons as argument separators:
```jq
reduce .[] as $x (0; . + $x)      # semicolon between init and update
limit(3; .items[])                # semicolon between n and expr
until(. > 10; . * 2)              # semicolon between cond and update
if cond then a elif b then c end  # no separator, different syntax entirely
```

This is inconsistent and confusing.

**query-json solution:**
All functions use commas for arguments, no exceptions:
```
reduce(.[], 0, fn(acc, x) -> acc + x)
limit(3, .items[])
until(. > 10, . * 2)
range(0, 10)
range(0, 10, 2)  # with step
```

**Parentheses for disambiguation:**
When an argument expression contains a comma, wrap it in parentheses:
```
# Array construction as argument - needs parens
limit(3, ([.a, .b]))

# Object construction - needs parens
map(({name: .n, age: .a}))

# Without parens, these would be ambiguous:
limit(3, [.a, .b])   # Error: limit takes 2 arguments, got 3
map({name: .n, age: .a})  # Error: unexpected comma
```

---

## 5. Naming Conventions

### 5.1 Consistent `snake_case`

**Problem in jq:**
Inconsistent naming throughout:
```
# All smushed together
tostring tonumber toarray toobject
getpath setpath delpaths
startswith endswith ltrimstr rtrimstr
isnan isinfinite isnormal isfinite
ascii_downcase ascii_upcase   # Wait, these have underscores!

# Inconsistent plural/singular
keys    # plural, returns array
length  # singular
type    # singular
first   # singular
values  # plural
```

**query-json solution:**
All built-ins use `snake_case` with clear, descriptive names:

| jq name | query-json name | Category |
|---------|-----------------|----------|
| `tostring` | `to_string` | Conversion |
| `tonumber` | `to_number` | Conversion |
| `getpath` | `get_path` | Path ops |
| `setpath` | `set_path` | Path ops |
| `delpaths` | `delete_paths` | Path ops |
| `startswith` | `starts_with` | String ops |
| `endswith` | `ends_with` | String ops |
| `ltrimstr` | `trim_start` | String ops |
| `rtrimstr` | `trim_end` | String ops |
| `isnan` | `is_nan` | Type checks |
| `isinfinite` | `is_infinite` | Type checks |
| `ascii_downcase` | `to_lowercase` | String ops |
| `ascii_upcase` | `to_uppercase` | String ops |
| `tojson` | `to_json` | Serialization |
| `fromjson` | `from_json` | Serialization |
| `indices` | `find_indices` | Search |
| `@base64` | `to_base64` | Encoding |
| `@base64d` | `from_base64` | Encoding |
| `@uri` | `to_uri` | Encoding |
| `@csv` | `to_csv` | Encoding |
| `@tsv` | `to_tsv` | Encoding |
| `@html` | `to_html` | Encoding |

jq names render helpful errors to teach users the new functions.

---

## 6. New Functions & Helpers

> **✅ IMPLEMENTED** - All functions in section 6.1, 6.3, and 6.4 are now implemented.

### 6.1 Collection Helpers

| Function | Description | Example |
|----------|-------------|---------|
| `pluck(key)` | Extract key from array of objects | `[{a:1},{a:2}] \| pluck(.a)` → `[1,2]` |
| `compact` | Remove null values from array | `[1,null,2] \| compact` → `[1,2]` |
| `partition(cond)` | Split into `[matching, non-matching]` | `[1,2,3] \| partition(. > 1)` → `[[2,3],[1]]` |
| `is_empty` | Check if array/string/object is empty | `[] \| is_empty` → `true` |
| `is_blank` | Check if null, empty, or whitespace | `"  " \| is_blank` → `true` |

**Implementation notes:**
- `pluck(key)` gracefully handles missing keys by returning `null` for items where the key doesn't exist
- `is_empty` also works on objects: `{} | is_empty` → `true`
- `is_blank` treats `null`, empty arrays/objects/strings, and whitespace-only strings as blank

---

---

### 6.3 `debug` for Debugging

Side-effect for debugging that doesn't affect the pipeline:
```
.foo | debug("at foo") | .bar
# Prints:  [debug] at foo: <value of .foo>
# Returns: .bar
```

Can also be used without a message:
```
.foo | debug | .bar
# Prints:  [debug] <value of .foo>
# Returns: .bar
```

---

### 6.4 `assert` for Invariants

```
.items
  | assert(length > 0; "items cannot be empty")
  | map(process)
```

> **Note:** Currently uses semicolon (`;`) for multiple arguments per jq syntax. Section 4.9 proposes switching to commas.

Fails with structured error if assertion fails:
- Error kind: `assertion_error`
- Includes the input value in error context
- Suggestion: "Check the condition in your assert() call"

---

## 7. Behavior Changes

### 7.1 `group_by` Returns Objects

**Problem in jq:**
`group_by` returns nested arrays—you lose the key:
```bash
echo '[{"a":1,"b":2},{"a":1,"b":3}]' | jq 'group_by(.a)'
# [[{"a":1,"b":2},{"a":1,"b":3}]]  — where's the key?!
```

**query-json solution:**
```
group_by(.a)
# {"1": [{"a":1,"b":2},{"a":1,"b":3}]}  — key is preserved as string
```

**Note:** Keys are always converted to strings (JSON object key constraint).

---

### 7.2 Deep Traversal with `descend`

**Problem in jq:**
The `..` (recursive descent) operator is cryptic and its behavior is hard to predict:
```bash
echo '{"a":{"b":1}}' | jq '.. | numbers'  # What does this even do?
```

**query-json solution:**
Replace `..` with explicit `descend` function:
```
descend   # yields all nested values (breadth-first, level by level)
dive      # yields all nested values (depth-first, plunge deep immediately)

# Examples:
{"a":{"b":1}} | descend | select(type == "number")  # 1
{"a":[1,2]}   | descend | numbers                    # 1, 2
```

For common patterns, use specialized functions:
```
find_all(condition)     # find all values matching condition at any depth
find_first(condition)   # find first match
paths_to(condition)     # get paths to all matches
```

Example:
```
{"users":[{"name":"alice"},{"name":"bob"}]} | find_all(.name?)
# ["alice", "bob"]
```

---

## 8. Tooling & Developer Experience

### 8.1 Discoverable Function Groups

```bash
query-json --help string
# String functions:
#   split, join, trim, trim_start, trim_end,
#   starts_with, ends_with, contains,
#   to_lowercase, to_uppercase, length

query-json --help array
# Array functions:
#   map, select, sort, sort_by, group_by,
#   first, last, nth, reverse, flatten, ...
```

---

### 8.2 REPL with Auto-completion

An interactive mode that renders an entire TUI fullscreen with:

- Available keys at current position
- Banner at the bottom with possible operations (if you are in a string, render "to_number" | "to_uppercase" | ..., if you are in an array render "map" | "reduce" | ...)
- Type of current value
- Real time resolving the query to the right
- Shortcuts to save current state of the output, shortcuts to copy the query, etc.

```bash
query-json --repl data.json
> .user.<TAB>
  name    email    age    address
> .user.address.<TAB>
  street    city    zip
```
```
+---------------------+----------------------+
| filter              | result               |
|                     |                      |
|                     |                      |
|                     |                      |
|          1          |          2           |
|                     |                      |
|                     |                      |
|---------------------+----------------------|
| input json file     | help banner          |
|                     |                      |
|                     |                      |
|                     |                      |
+---------------------+----------------------+
```

---

### 8.3 Profile Mode

```bash
query-json --profile '.items | map(expensive) | sort_by(.x)' data.json
# Profiling results:
#   map(expensive): 450ms (892 items processed)
#   sort_by(.x):     23ms
#   total:          473ms
```

---

## 9. Design Decisions

### 9.1 Open Questions

**Array slicing with out-of-bounds indices:**
```
[1,2,3] | .[5:10]   # Error? Or empty array []?
[1,2,3] | .[-10:2]  # Error? Or [1,2]?
```

**Decision needed:** Should slicing be strict (error on invalid bounds) or lenient (clamp to valid range)?

Proposal: Slicing is lenient (matches Python behavior), individual access is strict.

---

**Recursive structures:**
```
fn factorial -> if . <= 1 then 1 else . * ((. - 1) | factorial) end
```

Should work, but needs explicit testing for stack overflow handling.

---

**Comma vs semicolon for function arguments (Section 4.9):**

The document proposes using commas for all function arguments, but the current implementation still uses semicolons for backward compatibility with jq-like syntax:
```
# Current (jq-compatible):
assert(. > 0; "must be positive")
reduce .[] as $x (0; . + $x)

# Proposed (section 4.9):
assert(. > 0, "must be positive")
reduce(.[], 0, fn(acc, x) -> acc + x)
```

**Decision needed:** When should we migrate to comma-separated arguments? This is a breaking change that affects all multi-argument functions.

---

**Deep traversal semantics (Section 7.2):**

The traversal functions have specific behaviors:

- `find_all(expr)`: Supports two modes:
  - Boolean condition mode: `find_all(. > 5)` returns values where condition is true
  - Selector mode: `find_all(.name?)` returns all non-null results of the expression
  - Errors during evaluation are treated as non-matches (silently skipped)

- `find_first(expr)`: Uses **depth-first** traversal (not breadth-first) because it's more intuitive for document traversal - you find the first match as you'd read the JSON structure top-to-bottom.

- `paths_to(expr)`: Returns paths to all values where the expression evaluates to `true` (or non-null for selector expressions).

- `descend` vs `dive`:
  - `descend` uses breadth-first (all siblings before children) - like walking down stairs
  - `dive` uses pre-order depth-first (visit node, then children left-to-right) - like diving into water

---

### 9.2 Explicitly Not Supported

- **Modules/imports** — Not implemented. Single-file queries only.
- **SQL-style operators** (`$__loc__`, `INDEX`, `IN`, `JOIN`) — Removed. Use explicit functions.

---

### 9.3 Environment Access

Environment variables require explicit opt-in for security:

```bash
# Without flag: error
echo '{}' | query-json '$ENV.HOME'
# Error: Environment access is disabled
# Hint:  Use --allow-env to enable $ENV and env

# With flag: works
echo '{}' | query-json --allow-env '$ENV.HOME'
# "/home/user"

# Access all environment variables
echo '{}' | query-json --allow-env 'env'
# {"HOME": "/home/user", "PATH": "...", ...}

# Access specific variable
echo '{}' | query-json --allow-env 'env.PATH | split(":")'
# ["/usr/bin", "/bin", ...]
```

This prevents accidental leakage of sensitive environment variables (API keys, tokens, etc.) when running untrusted queries.
