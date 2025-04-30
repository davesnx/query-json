<p>
  <br>
  <br>
  <img width="250" alt="query-json logo" src="docs/dark-logo.svg#gh-light-mode-only" />
  <img width="250" alt="query-json logo" src="docs/white-logo.svg#gh-dark-mode-only" />
  <br>
  <br>
</p>

**query-json** is a [faster](#Performance), simpler and more portable implementation of the [jq language](https://github.com/stedolan/jq/wiki/jq-Language-Description) in OCaml distributed as a binary, but also distributed as a JavaScript package via [js_of_ocaml](https://github.com/ocsigen/js_of_ocaml).

**query-json** allows you to write small programs to operate on top of json files with a concise syntax.

[![asciicast](https://asciinema.org/a/b6g6ar2cQSAEAyn5qe7ptr98Q.svg)](https://asciinema.org/a/b6g6ar2cQSAEAyn5qe7ptr98Q)

## Purpose

It was created with mostly two reasons in mind, learning and having fun

- **Learn how to write a programming language with the OCaml stack** using `menhir`, `sedlex` and friends and try to make great error messages.
- **Create a CLI tool in OCaml** and being able to distribute it to twoo different platforms: as a binary (for performance) and as a JavaScript library (for portability).

## What it brings

- **Great Performance**: Fast, small footprint and minimum runtime. Check [Performance section](#Performance) for a longer explanation, but it can be 2x to 5x faster than jq.
- **Delightful errors**:
  - Better errors when json types and operation don't match:
    ```bash
    $ query-json '.esy.release.wat' esy.json
    Error:  Trying to ".wat" on an object, that don't have the field "wat":
    { "bin": ... }
    ```
  - `debug` prints the tokens and the AST.
  - `verbose` flag, prints each operation in each state and it's intermediate states. _(Work in progress...)_
- **Improved API**: made small adjustments to the buildin operations. Some examples are:
  - All methods are snake_case instead of alltoghetercase
  - Added `filter(p)` as an alias for `map(select(p))`
  - Supports comments in JSONs
- **Small**: Lexer, Parser and Compiler are just 300 LOC and most of the commands that I use on my day to day are implemented in only 140 LOC.

## Installation

### Using a bash script

Check the content of [scripts/install.sh](./scripts/install.sh) before running anything in your local. [Friends don't let friends curl | bash](https://sysdig.com/blog/friends-dont-let-friends-curl-bash).
```bash
curl -sfL https://raw.githubusercontent.com/davesnx/query-json/master/scripts/install.sh | bash
```

### Using npm

```bash
npm install --global @davesnx/query-json
```

### Download zip files from [GitHub](https://github.com/davesnx/query-json/releases)

## Usage

I recommend to write the query in single-quotes inside the terminal, since writting JSON requires double-quotes for accessing properties.

> NOTE: I have aliased query-json to "q" for short, you can set it in your dotfiles with `alias q="query-json"`.

#### query a json file
```bash
query-json '.' pokemons.json
```

#### query from stdin
```bash
cat pokemons.json | query-json '.'
query-json '.' <<< '{ "bulvasur": { "id": 1, "power": 20 } }'
```

#### query a json inlined
```bash
query-json --kind=inline '.' '{ "bulvasur": { "id": 1, "power": 20 } }'
```

#### query without colors
```bash
query-json '.' pokemons.json --no-colors
```

## Performance

[This report](./benchmarks/report.md) is not an exhaustive performance report of both tools, it's a overview for the percieved performance of the user. I don't profile each tool and try to see what are the bootlenecks, since I assume that both tools have the penalty of parsing a JSON file.

Aside from that, **query-json** doesn't have feature parity with **jq** which is ok at this point, but **jq** contains a ton of functionality that query-json misses. Adding the missing operations on **query-json** won't affect the performance of it, that could not be true for features like "modules", "functions" or "tests".

The report shows that **query-json** is between 2x and 5x faster than **jq** in all operations tested and same speed (~1.1x) with huge files (> 100M).

## Currently supported feature set

| Badge | Meaning             |
| ----- | ------------------- |
| ✅    | Implemented         |
| ⚠️    | Not implemented yet |
| 🔴    | Won't implement     |

##### Based on jq 1.6

#### [CLI: Invoking jq](https://stedolan.github.io/jq/manual/v1.6/#Invokingjq)
  - `--version` ✅
  - `--kind`. This is different than jq ✅
    - `--kind=file` and the 2nd argument can be a json file
    - `--kind=inline` and the 2nd argument can be a json as a string
  - `--no-color`. This disables colors ✅
  - ...rest ⚠️

#### [Basic filters](https://stedolan.github.io/jq/manual/v1.6/#Basicfilters)
  - Identity: `.` ✅
  - Object Identifier-Index: `.foo`, `.foo.bar` ✅
  - Optional Object Identifier-Index: `.foo?` ✅
  - Generic Object Index: `.[<string>]` ✅
  - Array Index: `.[2]` ✅
  - Pipe: `|` ✅
  - Array/String Slice: `.[10:15]` ⚠️
  - Array/Object Value Iterator: `.[]` ⚠️
  - Comma: `,` ✅
  - Parenthesis: `()` ✅️

#### [Types and Values](https://stedolan.github.io/jq/manual/v1.6/#TypesandValues) ⚠️

#### [Builtin operators and functions](https://stedolan.github.io/jq/manual/v1.6/#Builtinoperatorsandfunctions)

  - Addition: `+` ✅
  - Subtraction: `-` ✅
  - Multiplication, division, modulo: `*`, `/`, and `%` ✅
  - `length` ✅
  - `keys` ✅
  - `map` ✅
  - `select` ✅
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

Contributions are what make the open source community such an amazing place to be, learn, inspire, and create. Any contributions you make are greatly appreciated. If you have any questions just contact me [@twitter](https://twitter.com/davesnx) or email dsnxmoreno at gmail dot com.

### Support

I usually hang out at [discord.gg/reasonml](https://discord.com/channels/235176658175262720/235176658175262720) or [x.com/davesnx](https://x.com/davesnx) so feel free to ask anything.

### Setup

Requirements: [opam](https://opam.ocaml.org)

```bash
git clone https://github.com/davesnx/query-json
cd query-json
make init # creates opam switch, installs ocaml deps and npm deps
```

Core query-json setup
```bash
make dev-core # compiles query-json only
```

All packages setup
```bash
make dev # compiles all opam packages
make test # runs unit tests and snapshots tests
dune exec query-json # Run binary
```

Running the playground
```bash
# In different terminals
make dev # Runs bundler
make web-dev # Runs bundler
```
