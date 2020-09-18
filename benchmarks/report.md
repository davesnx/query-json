## Benchmark Report
The benchmarks run on a 13" MacBook Pro (2020) with a 1.4 GHz Quad-Core i5 and 16GB 2133MHz RAM.

Based on query-json 0.2.1

# Using [hyperfine](https://github.com/sharkdp/hyperfine)

`$ hyperfine --warmup 10 'query-json . esy.json' 'jq . esy.json'`
### Benchmark #1: query-json . esy.json
```
Time  (mean ± σ):      6.7 ms ±   0.2 ms    [User: 3.4 ms, System: 2.2 ms]
Range (min … max):     6.3 ms …   7.6 ms    291 runs
```
### Benchmark #2: jq . esy.json
```
Time  (mean ± σ):     28.0 ms ±   1.3 ms    [User: 25.6 ms, System: 1.3 ms]
Range (min … max):    26.8 ms …  36.5 ms    94 runs
```

## Summary
'query-json . esy.json' **ran 4.15 ± 0.23 times** faster than 'jq . esy.json'

# Using a handmade script: [./run.sh](./run.sh)
Times are given in CPU time (seconds), wall-clock times may deviate by ± 0.1s.

`$ ./benchmarks/run.sh`
### Select an attribute on a small (4kb) JSON file
```
jq          0.03 real         0.02 user         0.00 sys
query-json  0.00 real         0.00 user         0.00 sys
```
### Select an attribute on a medium (132k) JSON file
```
jq          0.04 real         0.03 user         0.00 sys
query-json  0.02 real         0.01 user         0.00 sys
```
### Select an attribute on a big JSON (604k) file
```
jq          0.08 real         0.07 user         0.00 sys
query-json  0.06 real         0.05 user         0.00 sys
```

### Simple operation on a small (4kb) JSON file
```
jq          0.02 real         0.02 user         0.00 sys
query-json  0.00 real         0.00 user         0.00 sys
```
### Simple operation on a medium (132k) JSON file
```
jq          0.03 real         0.03 user         0.00 sys
query-json  0.01 real         0.00 user         0.00 sys
```
### Simple operation an attribute on a big JSON (604k) file
```
jq          0.05 real         0.05 user         0.00 sys
query-json  0.01 real         0.01 user         0.00 sys
```
### Simple operation an attribute on a huge JSON (110M) file
```
jq          2.58 real         2.33 user         0.23 sys
query-json  2.23 real         2.09 user         0.13 sys
```

## Explanation

There are a few good asumtions about why **query-json** is faster, there are just speculations since I didn't profile neither jq, neither query-json.

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