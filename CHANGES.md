# Unreleased

## 0.6.1

- Make sure cmdliner is >= 1.1.0
- Make sure ocaml 5.3.0

## 0.6.0

- [bench] Create a minimum benchmark against jq 1.8
- [cli] Add --raw-output
- [core] **BREAKING:** Requires OCaml 5.0+ (uses effect handlers for control flow)
- [core] Add `try(expr)` and `try(expr; handler)` for error handling
- [core] Add `break` for loop exit (via Break effect)
- [core] Add `limit(n; expr)` to limit generator output
- [core] Add `error(msg)` for custom errors
- [core] Add `halt` / `halt_error(code)` for program termination
- [core] Add `isempty(expr)` to check empty streams
- [core] Add `match(regex)` for pattern matching with captures
- [core] Add `scan(regex)` to find all matches
- [core] Add `capture(regex)` to extract capture groups
- [core] Add `sub(regex; replacement)` for single replacement
- [core] Add `gsub(regex; replacement)` for global replacement
- [core] Add `del(path)` to delete keys/indices
- [core] Add `getpath(path_array)` for path navigation
- [core] Add `setpath(path_array; value)` for path updates
- [core] Add `paths` to enumerate all paths
- [core] Add `paths(filter)` for filtered path enumeration
- [core] Add trig functions: `sin`, `cos`, `tan`, `asin`, `acos`, `atan`
- [core] Add `log`, `log10`, `exp` for logarithms/exponentials
- [core] Add `ceil`, `round` for rounding
- [core] Add `pow` for power operations
- [core] Add `infinite` - infinite generator (use with `limit`!)
- [core] Add `now` for current Unix timestamp
- [core] Support [.[] | {...}]
- [core] Support |=
- [core] Support //
- [core] Add `nan` and `is_nan` functions for NaN handling
- [core] Add `transpose` function for matrix transposition
- [core] Add `flat_map` function for mapping and flattening
- [core] Add `find` function for finding first matching element
- [core] Add `some` function for checking if some elements match a condition
- [core] Add `any(condition)` and `all(condition)` with conditions
- [core] Add `recurse_down` for depth-first recursion
- [core] Add `test(pattern)` for regex pattern matching using Str module
- [core] Add `path(expr)` for JSON pointer path tracking
- [core] Add variable support with `$variable` syntax
- [core] Add full `reduce` with variables: `reduce EXPR as $VAR (INIT; UPDATE)`
- [cli] Remove --kind

## 0.5.52

- Remove melange-webapi
- Make development work in 5.3.0

## 0.5.51

- Enable 32 bits but disable for bytecode

## 0.5.50

- Disable project for 4.13 and 32bits

## 0.5.49

- Update lowerbound for ocaml and menhir

## 0.5.48

- Fix auto publish
- Remove lib app, melange-emit website and output.css from package

## 0.5.42

- Add verbose flag support for deprecation warnings
- Implement type function
- Implement floor function
- Implement sqrt function
- Implement to_number/tonumber with deprecation warning
- Implement to_string/tostring with deprecation warning
- Implement min and max functions
- Implement flatten and flatten(n) functions
- Implement sort, unique, any, and all functions
- Implement starts_with/startswith/startwith and ends_with/endswith/endwith with deprecation warnings
- Implement to_entries and from_entries functions
- Implement contains, explode, and implode functions
- Implement modulo (%) operator
- Implement sort_by, min_by, max_by, and unique_by functions
- Implement index and rindex string functions
- Implement group_by function
- Implement while and until control flow
- Implement recurse with parameters
- Implement walk function
- Add cram tests for deprecation warnings (test/warnings.t)

## 0.5.24

- Fix #36: Implement indexes correctly (https://github.com/davesnx/query-json/issues/36)

## 0.5.23

- Refactor to use Safe.from_string
- Support integers bigger than 63bit
- Functorize Chalk
- Fix loading dependencies
- Remove weird characters from output errors
- Update dependencies
- Put name in dune-project
- Cleanup parser
- Turn all tokens as _case
- More expressive on the ast/compiler
- Update ocamlformat-mlx
- Fix Windows build (disable website build on Windows as mlx isn't supported)
- Specify node running tailwind
- Remove flatten
- Add new builtins
- Add array/obj iterator support
- Add optional expression
- Add new functions and more tests
- Fix range
- Add iterator base
- Remove prerelease, fix deprecation warning
- Slices are now supported
- Refactor iters into matches

## 0.5.13

- Fix: Index can't make out of bounds and crash

## 0.5.12

- Refactor: Rename json to payload and input to json
- Fix: Don't check for the payload until there's a query
- Update documentation and logo
- Web: Finish header and UI improvements
- CI: Enable windows/mac builds
- CI: Disable send to coveralls
- Fix: Remove control characters from error
- Feat: Allow to share URL with query/json
- Fix: Adapt to multiple outputs
- Feat: Add monaco editor
- Feat: Add styled-ppx

## 0.5.10

- Bring query-json closer to jq
- Package return (was pure), bind, lift2 and collect in a Results local module
- Update the README file

## 0.5.9

- Refactor: Rename stuff
- Feat: Add reason -> jsoo -> js -> bs
- Feat: Add www with webpack
- Feat: Add web in BS
- Feat: Improve stdin without kind inline
- Refactor: Move web to Js
- Fix: Remove warnings of shadowing Some
- Feat: Add web executable
- Add more benchmarks
- Setup jsoo with dune

## 0.5.8

- CI: Remove -rf flags from rf
- CI: Fix snapshot folder
- Refactor: Add recurse as a token
- Fix #19
- CI: Enable global cache and dependency cache
- Fix: Remove warnings regarding openness shadowing Some
- Feat: Add key with numbers work fine

## 0.5.7

- Enable Windows build
- Add snapshot test
- Enable e2e in windows under a different invocation of bats

## 0.5.6

- Feat: Add documentation on empty cmd

## 0.5.5

- Feat: Improve messages and fix stdin active waiting

## 0.5.0

- Feat: Add reading from stdin
- Test: Add test coverage with bisect_ppx
- Test: Add stdin test
- Fix: Add a few error messages
- Fix typos in README.md
- Rename to query-json
- Feat: Improve quality of errors
- Feat: Colorized output and --no-color
- Fix: Keys
- Feat: Add error message clean
- Fix: Key optional
- Feat: Support json parsing
- Feat: Add all functions
- Feat: Add all identifier fns
- Feat: Add formatting into errors
- Feat: Improved compiled errors
- Feat: Improved parser/lexer errors
- Add logo

## 0.2.5

- Publish 0.2.5
- Add performance benchmarks
- Improve documentation

## 0.2.0

- CI: Make q available on CI
- Add testing coverage
- Add LICENCE

## 0.1.5

- Distro: Remove extension exe for binary

## 0.1.2

- Initial release
