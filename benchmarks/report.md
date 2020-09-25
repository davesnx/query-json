# Benchmark Report
The benchmarks run on a 13" MacBook Pro (2020) with a 1.4 GHz Quad-Core i5 and 16GB 2133MHz RAM.

This benchmark consists twoo different steps, the boot time and a timer on a few operations over different (json) file sizes.

Executing `$ ./benchmarks/hyper.sh` runs hyperfile.
Executing `$ ./benchmarks/run.sh` runs the timers.

## Output

`$ ./benchmarks/hyper.sh`

| Command | Mean [ms] | Min [ms] | Max [ms] | Relative |
|:---|---:|---:|---:|---:|
| `query-json . esy.json` | 7.9 ± 0.4 | 7.3 | 11.3 | 1.00 |
| `jq . esy.json` | 27.6 ± 0.5 | 26.8 | 29.0 | 3.50 ± 0.21 |
| `faq . esy.json` | 55.3 ± 1.1 | 53.7 | 60.0 | 7.00 ± 0.42 |
| `fx esy.json .` | 64.5 ± 2.7 | 62.2 | 72.7 | 8.16 ± 0.58 |

---

## Running [run.sh](./run.sh)

```bash
query-json: 0.5.8
jq: jq-1.6
faq: 0.0.6
fx: 20.0.2
```

### Select an attribute (`.first.id`) on a small (4kb) JSON file
```bash
query-json        0.00 real         0.00 user         0.00 sys
jq                0.02 real         0.02 user         0.00 sys
faq               0.05 real         0.05 user         0.00 sys
fx                0.06 real         0.04 user         0.01 sys
```

### Select an attribute (`.`) on a medium (132k) JSON file
```bash
query-json        0.02 real         0.01 user         0.00 sys
jq                0.04 real         0.03 user         0.00 sys
faq               0.07 real         0.08 user         0.00 sys
fx                0.11 real         0.12 user         0.02 sys
```
### Map an attribute (`map(.)`) on a big JSON (604k) file
```bash
query-json        0.07 real         0.06 user         0.00 sys
jq                0.08 real         0.07 user         0.00 sys
faq               0.12 real         0.14 user         0.01 sys
fx                0.17 real         0.20 user         0.02 sys
```

### Simple operation (`.second.store.books | map(.price + 10)`) on a small (4kb) JSON file
```bash
query-json        0.00 real         0.00 user         0.00 sys
jq                0.02 real         0.02 user         0.00 sys
faq               0.06 real         0.04 user         0.01 sys
```

### Simple operation (`map(.time)`) on a medium (132k) JSON file
```bash
query-json        0.01 real         0.00 user         0.00 sys
jq                0.03 real         0.03 user         0.00 sys
faq               0.07 real         0.07 user         0.00 sys
fx                0.08 real         0.08 user         0.01 sys
```

### Simple operation (`map(select(.base.Attack > 100)) | map(.name.english)`) an attribute on a big JSON (604k) file
```bash
query-json        0.01 real         0.01 user         0.00 sys
jq                0.05 real         0.05 user         0.00 sys
faq               0.10 real         0.09 user         0.01 sys
```

### Simple operation (`keys`) an attribute on a huge JSON (110M) file
```bash
query-json        2.17 real         2.04 user         0.12 sys
jq                2.47 real         2.25 user         0.21 sys
faq               6.22 real         6.79 user         0.56 sys
fx                6.80 real        10.38 user         0.54 sys
```

## Explanation

There are a few good asumtions about why **query-json** is faster, there are just speculations since I didn't profile any of the tools listed here, neither query-json.

Thoughts about jq:

The feature that I think penalizes a lot jq is "def functions", the capacity of define any function that can be available during run-time.

This creates a few layers, one of the difference is the interpreter and the linker, the responsible for getting all the builtin functions and compile them have them ready to use at runtime.

The other pain point is the architecture of the operations on jq, since it's a stack based meanwhile query-json it's a piped recursive operations, and I think OCaml compiler optimizes the piped operations since are tail-recursive.

Aside from the code, the OCaml stack, menhir has been proved to be really fast when creating those kind of compilers.

I will dig more into performance in [here](https://github.com/davesnx/query-json/issues/7) and try to profile both tools in order to improve mine.

#### Resources
[jq Internals: the interpreter](https://github.com/stedolan/jq/wiki/Internals:-the-interpreter)
[jq Internals: backtracking](https://github.com/stedolan/jq/wiki/Internals:-backtracking)
[jq Internals: the linker](https://github.com/stedolan/jq/wiki/Internals:-the-linker)
[jq Internals: thestack](https://github.com/stedolan/jq/wiki/Internals:-the-stack)

#### faq - Format Agnostic jQ
Written in go
https://github.com/jzelinskie/faq

#### fx - Command-line tool and terminal JSON viewer 🔥
Written in JavaScript
https://github.com/antonmedv/fx

## Please open an issue if you want to see here any jq-like tool
If the queries match 1-to-1 to jq would be cool, otherwise could you add some examples.