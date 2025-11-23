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

- **Great Performance**: Fast, small footprint and minimum runtime. Consistently 1.5x to 4.5x faster than jq depending on file size and operation. See [Performance section](#Performance) for detailed benchmarks.
- **Delightful errors**:
  - Better errors when json types and operation don't match:
    ```bash
    $ query-json '.esy.release.wat' esy.json
    Error:  Trying to ".wat" on an object, that don't have the field "wat":
    { "bin": ... }
    ```
  - `debug` prints the tokens and the AST.
  - `verbose` flag, prints each operation in each state and it's intermediate states. _(Work in progress...)_
- **Improved API**: Snake_case function names, helpful aliases, and convenient additions. See [jq Compatibility](#jq-compatibility) for details.
- **Small**: Lexer, Parser and Interpreter are just 1300 LOC

## jq compatibility

query-json implements most of jq 1.8's functionality with some intentional improvements:

### Improvements

**Better naming** - snake_case instead of alllowercase:
- `to_number` / `to_string` (instead of `tonumber` / `tostring`)
- `starts_with` / `ends_with` (instead of `startswith` / `endswith`)
- `is_nan` (instead of `isnan`)

> The old names still work but show deprecation warnings with `--verbose` or `-v` flag.

**Extra conveniences:**
- `filter(expr)` - alias for `map(select(expr))`
- `flat_map(expr)` - map and flatten in one operation
- `find(expr)` - find first matching element
- `some(expr)` - check if at least one element matches
- `unique` - accepts both `unique` and `uniq` (jq only has `uniq`)
- **JSON comments** - supports comments in JSON input

### Implemented features

- All basic filters (`.`, `.foo`, `.[]`, `.[0]`, `.[1:3]`, etc.)
- Operators (`+`, `-`, `*`, `/`, `%`, `==`, `!=`, `<`, `>`, `<=`, `>=`, `and`, `or`, `not`)
- Conditionals (`if-then-else`)
- Pipes (`|`), comma (`,`), alternative (`//`)
- Core functions (`map`, `select`, `length`, `keys`, `has`, `in`, `add`, `reverse`, etc.)
- Array operations (`sort`, `sort_by`, `unique`, `unique_by`, `group_by`, `flatten`, `min`, `max`, etc.)
- String operations (`split`, `join`, `startswith`, `endswith`, `contains`, `explode`, `implode`)
- Type operations (`type`, `to_number`, `to_string`)
- Math functions (`abs`, `floor`, `sqrt`, `ceil`, `round`, `sin`, `cos`, `tan`, `log`, `exp`, etc.)
- Object operations (`to_entries`, `from_entries`, `with_entries`)
- Path operations (`path`, `paths`, `getpath`, `setpath`, `del`)
- Control flow (`while`, `until`, `recurse`, `walk`, `limit`, `try-catch`, `reduce`)
- Regex support (`test`, `match`, `scan`, `capture`, `sub`, `gsub`)

### Not supported

User-defined functions (`def`), modules (`import`, `include`), format strings (`@text`, `@csv`, `@base64`), and running tests (`--run-tests`).

For a complete reference, see the [jq manual](https://jqlang.org/manual/).

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
query-json '.' '{ "bulvasur": { "id": 1, "power": 20 } }'
```

#### query without colors
```bash
query-json '.' pokemons.json --no-colors
```

#### query with raw output (strings without quotes)
```bash
query-json -r '.name' pokemon.json
# Output: Pikachu
# Instead of: "Pikachu"
```

#### More examples

Check out [docs/examples.md](./docs/examples.md) for a walkthrough of common use cases.

## Performance

query-json consistently outperforms jq 1.8.1 across most file sizes and operations, with performance improvements ranging from **1.5x to 4.5x faster** depending on the file size and operation:

- **Small files (< 10KB):** 2.4-3x faster
- **Medium files (100-500KB):** 2-4.5x faster
- **Large files (> 500KB):** 1.6-3.3x faster
- **Huge files (> 50MB):** 1.5-1.8x faster

### Why is query-json faster?

1. **Native compilation**: Compiled to optimized [machine code with OCaml](https://ocaml.org/manual/5.4/native.html)
2. **Simpler runtime**: Implementing a focused subset allows for optimization decisions not possible with jq's full feature set. The biggest missing pieces that might affect performance:
  - **User-defined functions** (`def`) - intentional tradeoff for better performance
  - **Modules** (`import`, `include`) - not implemented
  - **Format strings** (`@text`, `@csv`, `@base64`, etc.) - not implemented
  - **Running tests** - `--run-tests`
3. **Tail-recursive architecture**: OCaml optimizes piped recursive operations into tight loops
4. **Fast parser**: Uses [Menhir](http://gallium.inria.fr/~fpottier/menhir/), a high-performance LR(1) parser generator

**For detailed benchmarks and methodology**, see [benchmarks/README.md](./benchmarks/README.md).

## Contributing

Contributions are what make the open source community such an amazing place to be, learn, inspire, and create. Any contributions you make are greatly appreciated. If you have any questions just contact me on [x](https://x.com/davesnx) or email dsnxmoreno at gmail dot com.

### Support

I usually hang out at [discord.gg/reasonml](https://discord.com/channels/235176658175262720/235176658175262720) feel free to DM.

### Setup

Requirements: [opam](https://opam.ocaml.org)

```bash
git clone https://github.com/davesnx/query-json
cd query-json
make init # creates opam switch, installs ocaml deps and npm deps
make dev-core # compiles query-json "core" only
make test # runs unit tests and snapshots tests
dune exec query-json # Run binary
```

Running the playground
```bash
# In different terminals
make dev # compiles all packages "query-json" "query-json-js" and "query-json-playground", and runs the bundler
make web-dev # Runs bundler and the web server
```
