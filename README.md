<p>
  <br>
  <br>
  <img width="250" alt="query-json logo" src="docs/dark-logo.svg#gh-light-mode-only" />
  <img width="250" alt="query-json logo" src="docs/white-logo.svg#gh-dark-mode-only" />
  <br>
  <br>
</p>

A fast, friendly and portable JSON query language for the command line.

**query-json** lets you slice, filter, and transform JSON data with a concise, expressive syntax. It started as a jq-compatible implementation, but evolved into something better: faster execution, better error messages, and a modernized language design.

## Why?

### Fast

Native binary compiled with OCaml. Consistently **2-4x faster than jq** across file sizes and operations.

| File Size | Speed vs jq |
|-----------|-------------|
| < 10KB    | 2.4-3x faster |
| 100-500KB | 2-4.5x faster |
| > 500KB   | 1.6-3.3x faster |

[See detailed benchmarks](./benchmarks/README.md)

### Easier to Learn

Designed to be learnable without leaving your terminal:

- **Interactive REPL** with context-aware autocomplete—type `.` to see keys, `|` to see functions
- **Helpful error messages** that tell you *why* something failed and *how to fix it*
- **Built-in function reference**: `query-json --functions` lists all functions by category

```bash
$ query-json ".naem" <<< '{"name": "Alice", "age": 30}'
error[key_not_found]: key `naem` not found
  --> .naem
      ^^^^

  in: {"name": "Alice", "age": 30}
  available keys: name, age
  hint: use `.naem?` for optional access
```

Compare to jq
```bash
$ jq ".naem" <<< '{"name": "Alice", "age": 30}'
null
```

<img src="docs/repl-demo.gif" alt="query-json interactive REPL demo" />

More demos:

- [Basic CLI demo](./docs/cli-basic.gif)
- [Advanced CLI demo](./docs/cli-advanced.gif)
- [query-json vs jq demo](./docs/comparison.gif)
- [jq compatibility demo bundle](./docs/jq-compat-demos/all-demos.gif)

### Portable

Written in OCaml, it compiles to both native code and JavaScript. Use the same query language:
- As a **CLI tool** on macOS, Linux, and Windows
- In the **browser** via our [online playground](https://query-json.pages.dev)
- As a **Node.js library**: `npm install @davesnx/query-json`

### jq, but better

We love jq's core ideas, but most of their design is arcane and forced the be backwards compatible. We looked into it with fresh eyes and came up with some improvements:

- **[Consistent style](./docs/JQ_COMPATIBILITY.md#snake_case-naming)**: All functions use `snake_case`
- **[Stricter nulls](./docs/JQ_COMPATIBILITY.md#stricter-null-handling)**: Errors on null access instead of silently propagating (use `.foo?` for optional)
- **[Optional access everywhere](./docs/JQ_COMPATIBILITY.md#optional-access-on-functions)**: `first?`, `last?`, `keys?` and even `first?(expr)` work as expected
- **[Readable names](./docs/JQ_COMPATIBILITY.md#clearer-naming)**: `to_uppercase` instead of `ascii_upcase`, `starts_with` instead of `startswith`
- **[Saner defaults](./docs/JQ_COMPATIBILITY.md#behavioral-differences)**: `group_by` returns an object (not nested arrays), `keys`/`unique` preserve insertion order
- **[Extra functions](./docs/JQ_COMPATIBILITY.md#additional-features-in-query-json)**: `filter`, `flat_map`, `find`, `pluck`, `compact`, `partition` and more
- **[`fn` for user defined functions](./docs/JQ_COMPATIBILITY.md#fn-for-user-defined-functions)**: `fn` keyword instead of `def`

The old jq names still work but show deprecation warnings. See the full [jq Compatibility Guide](./docs/JQ_COMPATIBILITY.md) for details.

## Installation

### Using the install script

Check the content of [scripts/install.sh](./scripts/install.sh) before running anything in your local. [Friends don't let friends curl | bash](https://sysdig.com/blog/friends-dont-let-friends-curl-bash).
```bash
curl -sfL https://query-json.page.dev/install.sh | bash
```

### Using npm

```bash
npm install --global @davesnx/query-json
```

### Download from GitHub

Pre-built binaries for macOS, Linux, and Windows are available on the [releases page](https://github.com/davesnx/query-json/releases).

## Quick Start

### Query a file

```bash
query-json '.store.books[0].title' bookstore.json
```

### Query from stdin

```bash
curl -s https://api.github.com/users/ocaml | query-json '{name: .name, description: .bio, img: .avatar_url}'
```

### Query inline JSON

```bash
query-json '.users | length' '{"users": [1, 2, 3]}'
```

### Common operations

```bash
# Get all keys from an object
query-json 'keys' config.json

# Filter array elements
query-json '.items | map(select(.price > 100))' products.json

# Transform data
query-json '.users | map({name, email})' users.json

# Group and count
query-json 'group_by(.category) | map_values(length)' items.json

# String operations
query-json '.title | to_lowercase | split(" ") | first' article.json
```

## Documentation

- **[Try it online](https://query-json.pages.dev)** - Interactive playground
- **[Function Reference](https://query-json.pages.dev/functions)** - Complete list of built-in functions
- **[jq Compatibility Guide](./docs/JQ_COMPATIBILITY.md)** - Migration guide for jq users

## CLI Options

```
query-json [OPTIONS] <QUERY> [FILE]

Arguments:
  <QUERY>    The query to run
  [FILE]     JSON file to query (reads from stdin if omitted)

Options:
  -r, --raw-output    Output strings without quotes
  --no-color          Disable colored output
  --repl              Start interactive REPL mode
  -v, --verbose       Show verbose output including deprecation warnings
  --debug             Print lexer tokens and AST
  --version           Print version
  --help              Print help
```

## Contributing

Contributions are welcome! See the [development setup](#development) below to get started.

### Development

Requirements: [opam](https://opam.ocaml.org)

```bash
git clone https://github.com/davesnx/query-json
cd query-json
make init       # Create opam switch and install dependencies
make dev-core   # Build query-json
make test       # Run tests
```

### Running the playground locally

```bash
# Terminal 1: Build and watch
make dev

# Terminal 2: Start web server
make web-dev
```

## Support

- Twitter/X: [@davesnx](https://x.com/davesnx)
- Discord: [discord.gg/reasonml](https://discord.com/channels/235176658175262720/235176658175262720)
- Email: dsnxmoreno at gmail dot com

## License

MIT
