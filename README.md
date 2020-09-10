<p>
  <br>
  <br>
  <img width="500" alt="query-json logo" src="docs/logo.svg" />
  <br>
  <br>
  <br>
  <a href="https://github.com/davesnx/query-json/actions"><img src="https://github.com/davesnx/query-json/workflows/Build%20master/badge.svg" /></a>
</p>

---

**query-json (q)** is a simplified re-implementation of the [jq language](https://github.com/stedolan/jq/wiki/jq-Language-Description) in [Reason Native](https://reasonml.github.io/docs/en/native) and compiled to native thanks to OCaml. q, allows you to write small programs to operate on top of json files in a cute syntax.

```bash
q ".store.books | filter(.price > 10)" stores.json
```

This would access to `"store"` field, access to `"books"` field, (since it's an array) it will run a filter on each item and if `"price"` field is lower than 10 will keep that item on the list, and finally print the resultant list.

```
[
  {
    "title": "War and Peace",
    "author": "Leo Tolstoy",
    "price": 12.0
  },
  {
    "title": "Lolita",
    "author": "Vladimir Nabokov",
    "price": 13.0
  }
]
```

## It brings

- **Great Performance**: Fast, small footprint and minimum run-time.
- **Delightful errors**:
  - Better errors when json "shapes" and operations don't match.
  - `verbose` flag, prints each operation in each state and it's intermediate states.
  - `debug` prints the tokens and the AST.
- **Improved API**: made small adjustments to the buildin operations. For example, all methods are snake_case instead of alltoghetercase, changed select to filter, and other details.
- **Small**: Lexer, Parser and Compiler are just 300 LOC and most of all the commands that I use on my day to day, are implemented in only 140 LOC.

## Installation

### Using a bash script

```
curl -sfL https://raw.githubusercontent.com/davesnx/query-json/master/scripts/install.sh | bash
```

### Using npm

```
npm install --global @davesnx/query-json
```

### Using yarn

```
yarn global add @davesnx/query-json
```

<!-- TODO: ## Benchmarks: -->

## Purpose

The purpose of this project were mostly 2.

- Learn how to write a lexer/parser/compiler with the OCaml stack using menhir and sedlex while trying to create a compiler with great error messages and possibly recoverability (currently _work in progress_).
- Create a CLI tool in Reason Native and being able to distribute it as a binary, enjoy it's performance and try further with cross-compilation.

## Currently supported feature set:

| Badge | Meaning             |
| ----- | ------------------- |
| ✅    | Implemented         |
| ⚠️    | Not implemented yet |
| 🔴    | Won't implement     |

##### Based on jq 1.6

#### [CLI: Invoking jq](https://stedolan.github.io/jq/manual/v1.6/#Invokingjq)

- `--version` ✅
- `--kind` ✅: This is different than jq.
  - `--kind=file` and the 2nd argument can be a json file
  - `--kind=inline` and the 2nd argument can be a json as a string
- ...rest ⚠️

#### [Basic filters](https://stedolan.github.io/jq/manual/v1.6/#Basicfilters)

- Identity: `.` ✅
- Object Identifier-Index: `.foo`, `.foo.bar` ✅
- Optional Object Identifier-Index: `.foo?` ✅
- Generic Object Index: `.[<string>]` ✅
- Array Index: `.[2]` ✅
- Pipe: `|` ✅
- Array/String Slice: `.[10:15]` ⚠️
- Array/Object Value Iterator: `.[]` 🔴
- Comma: `,` ⚠️
- Parenthesis: `()` ⚠️

#### [Types and Values](https://stedolan.github.io/jq/manual/v1.6/#TypesandValues) ⚠️

#### [Builtin operators and functions](https://stedolan.github.io/jq/manual/v1.6/#Builtinoperatorsandfunctions)

- Addition: `+` ✅
- Subtraction: `-` ✅
- Multiplication, division, modulo: `*`, `/`, and `%` ✅
- `length` ✅
- `keys` ✅
- `map` ✅
- `select` it's renamed to `filter` and operates differently. Filter is an alias to `map(select())`. ✅
- `has(key)` ⚠️
- `in` ⚠️
- `path(path_expression)` ⚠️
- `to_entries`, `from_entries`, `with_entries` ⚠️
- `any`, `any(condition)`, `any(generator; condition)` ⚠️
- `all`, `all(condition)`, `all(generator; condition)` ⚠️
- `flatten` ✅
- `range(upto)`, `range(from;upto)` `range(from;upto;by)` ⚠️
- `floor`, `sqrt` ⚠️
- `tonumber`, `tostring` ⚠️
- `type` ⚠️
- `infinite`, `nan`, `isinfinite`, `isnan`, `isfinite`, `isnormal` ⚠️
- `sort`, `sort_by(path_expression)` ✅
- `group_by(path_expression)` ⚠️
- `min, max, min_by(path_exp), max_by(path_exp)` ⚠️
- `unique, unique_by(path_exp)` ⚠️
- `reverse` ⚠️
- `contains(element)` ⚠️
- `index(s), rindex(s)` ⚠️
- `startswith(str)`, `endswith(str)` ⚠️
- `explode`, `implode` ⚠️
- `split(str)`, `join(str)` ⚠️
- `while(cond; update)`, `until(cond; next)` ⚠️
- `recurse(f)`, `recurse`, `recurse(f; condition)`, `recurse_down` ⚠️
- `walk(f)` ⚠️
- `transpose(f)` ⚠️
- Format strings and escaping: `@text`, `@csv`, etc.. 🔴

#### [Conditionals and Comparisons](https://stedolan.github.io/jq/manual/v1.6/#ConditionalsandComparisons)

- `==`, `!=` ✅
- `if-then-else` ⚠️
- `>`, `>=`, `<=`, `<` ✅
- `and`, `or`, `not` ⚠️
- `break` 🔴

#### [Regular expressions (PCRE)](https://stedolan.github.io/jq/manual/v1.6/#RegularexpressionsPCRE) ⚠️

#### [Advanced features](https://stedolan.github.io/jq/manual/v1.6/#Advancedfeatures) ⚠️

#### [Assignment](https://stedolan.github.io/jq/manual/v1.6/#Assignment) ⚠️

#### [Modules](https://stedolan.github.io/jq/manual/v1.6/#Modules) ⚠️

## Contributing

Contributions are what make the open source community such an amazing place to be learn, inspire, and create. Any contributions you make are greatly appreciated. If you have any questions just contact me [@twitter](https://twitter.com/davesnx) or email (dsnxmoreno@gmail.com).

### Support

I usually hang out at (discord.gg/reasonml)[https://discord.com/channels/235176658175262720/235176658175262720] or (reasonml.chat)[https://reasonml.chat] so feel free to ask anything there.

### Setup

Requirements: [esy](https://esy.sh)

```bash
git clone https://github.com/davesnx/query-json
cd query-json
esy # installs everything
esy test # runs unit-tests with [rely](https://reason-native.com/docs/rely/), defined under test.
esy q # Run binary
```

## Acknowledgements

Thanks to [@EduardoRFS](https://github.com/EduardoRFS). Thanks to all the authors of dependencies that this project relies (menhir, sedlex, yojson). Thanks to the OCaml and Reason Native team.
