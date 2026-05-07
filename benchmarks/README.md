# Benchmark Results

**Date:** 22 November 2025
**query-json version:** 0.5.52
**jq version:** jq-1.8.1
**System:** MacBook Pro (2020) with 1.4 GHz Quad-Core i5, 16GB RAM

> NOTE: query-json version 0.6.x supports compatibility with jq, and those benchmarks are designed to not cause any behavioral difference. We can't ensure further versions starting from v1 to follow that rule.

## Summary

query-json consistently outperforms jq across most file sizes and operations, with performance improvements ranging from **1.5x to 4.5x faster** depending on the file size and operation.

## Running Benchmarks

```bash
# Run all benchmarks (compares with jq only)
./benchmarks/bench.sh

# Compare with multiple tools
BENCH_JQ=1 BENCH_FAQ=1 BENCH_FX=1 ./benchmarks/bench.sh

# Quick run with fewer iterations
MIN_RUNS=3 WARMUP=1 ./benchmarks/bench.sh
```

The benchmark suite uses [hyperfine](https://github.com/sharkdp/hyperfine) for accurate, statistical benchmarking with warmup runs and multiple iterations.

## GC Pressure / OCaml Compactor Benchmark

`bench_gc_pressure` is an in-process benchmark for comparing OCaml runtime GC and compaction behavior. It is intended for testing runtime branches such as [`new_compactor`](https://github.com/sadiqj/ocaml/tree/new_compactor), where CLI wall-clock benchmarks hide the compactor signal behind process startup, parsing, and I/O noise.

```bash
# Default: benchmarks/big.json, 8 iterations per scenario
dune exec benchmarks/bench_gc_pressure.exe

# Larger heap pressure; reduce iterations for huge.json
dune exec benchmarks/bench_gc_pressure.exe -- --file benchmarks/huge.json --iterations 3
```

The benchmark reports Markdown tables with:

- Work time before explicit GC cleanup.
- `Gc.full_major ()` time after the workload.
- `Gc.compact ()` time after the full major collection.
- Allocation and promotion deltas from `Gc.quick_stat`.
- Heap, free-space, fragment, and RSS snapshots before and after compaction.

The most useful comparison workflow is to run the same command under two opam switches and diff the tables:

```bash
opam switch set 5.4.0
dune exec benchmarks/bench_gc_pressure.exe -- --file benchmarks/big.json --iterations 8 > /tmp/query-json-gc-5.4.md

opam switch set new-compactor
dune clean
dune exec benchmarks/bench_gc_pressure.exe -- --file benchmarks/big.json --iterations 8 > /tmp/query-json-gc-new-compactor.md
```

See [`gc-pressure-baseline.md`](./gc-pressure-baseline.md) for one local OCaml 5.4.0 baseline and [`gc-pressure-ocaml-5.5-beta1.md`](./gc-pressure-ocaml-5.5-beta1.md) for a local OCaml 5.5.0 beta1 run.

## Detailed Results

### Small File Tests (1.3KB)

| Operation | query-json | jq | Speedup |
|-----------|------------|----------|---------|
| Identity (`.`) | 0.005s | 0.012s | **2.4x faster** |
| Select field (`.first.id`) | 0.004s | 0.012s | **3.0x faster** |
| Nested map (`.second.store.books \| map(.price + 10)`) | 0.004s | 0.012s | **3.0x faster** |

### Medium File Tests (104KB)

| Operation | query-json | jq | Speedup |
|-----------|------------|----------|---------|
| Identity (`.`) | 0.014s | 0.027s | **1.9x faster** |
| Map identity (`map(.)`) | 0.014s | 0.029s | **2.1x faster** |
| Map field access (`map(.time)`) | 0.008s | 0.023s | **2.9x faster** |
| Length (`length`) | 0.004s | 0.018s | **4.5x faster** |

### Big File Tests (575KB)

| Operation | query-json | jq | Speedup |
|-----------|------------|----------|---------|
| Identity (`.`) | 0.045s | 0.074s | **1.6x faster** |
| Map identity (`map(.)`) | 0.045s | 0.077s | **1.7x faster** |
| Keys (`keys`) | 0.056s | 0.054s | **~same** |
| Length (`length`) | 0.012s | 0.040s | **3.3x faster** |
| First element (`.[0]`) | 0.012s | 0.039s | **3.3x faster** |

### Huge File Tests (97MB)

| Operation | query-json | jq | Speedup |
|-----------|------------|----------|---------|
| Keys (`keys`) | 1.270s | 2.233s | **1.8x faster** |
| Identity (`.`) | 7.312s | 10.764s | **1.5x faster** |

## Analysis

### Performance Characteristics

1. **Small Files (< 10KB):** query-json maintains 2.4-3x advantage
   - Fast parsing and execution
   - Low startup overhead

2. **Medium Files (100-500KB):** Strong performance advantage (2-4.5x faster)
   - Simple operations like `length` show largest gains (4.5x)
   - Map operations remain 2-3x faster

3. **Large Files (> 500KB):** Consistent advantage (1.6-3.3x faster)
   - **Notable:** `keys` operation is essentially tied (0.056s vs 0.054s)
   - Other operations maintain 1.6-3.3x speedup

4. **Huge Files (> 50MB):** Solid performance gain (1.5-1.8x faster)
   - Both tools handle streaming well
   - query-json maintains consistent advantage

### Key Observations

- **query-json outperforms jq** in almost all scenarios
- **One exception:** `keys` on big.json is nearly tied (56ms vs 54ms)
- **Simple operations** like `length`, `.[0]` show the largest speedups (3-4x)
- **Complex operations** like `map(.)` maintain good speedups (1.7-2x)
- **Streaming large files** maintains consistent advantage (1.5x)

### Performance Wins

**query-json's strongest advantages:**
- `length` on medium file: **4.5x faster**
- `length` and `.[0]` on big file: **3.3x faster**
- `map(.time)` on medium file: **2.9x faster**
- `.first.id` on small file: **3.0x faster**

**Areas to investigate:**
- `keys` operation on big file is essentially tied - might be an opportunity for optimization

## Why is query-json faster?

There are several reasons why query-json achieves better performance than jq:

### 1. Native Compilation

query-json is compiled to native code with OCaml, which produces highly optimized machine code. The OCaml compiler is particularly good at optimizing functional code patterns.

### 2. Simpler Runtime Model

Unlike jq, query-json doesn't support modules neither tests. While this reduces flexibility, it eliminates the need for:
- A complex linker to resolve modules
- Runtime function compilation and binding

### 3. Architecture Differences

- **jq**: Uses a stack-based interpreter with backtracking support
- **query-json**: Uses piped recursive operations that are tail-recursive

The OCaml compiler can optimize tail-recursive functions very effectively, often transforming them into tight loops.

### 4. Parser Performance

query-json uses [Menhir](http://gallium.inria.fr/~fpottier/menhir/), an LR(1) parser generator that has been proven to be very fast for creating high-performance parsers and compilers and a forked version of [yojson](https://opam.ocaml.org/packages/yojson/), an optimized parsing and printing library for the JSON format.

## Benchmarking Other Tools

The benchmark suite supports comparing against other JSON processing tools:

- **jq**: The standard JSON processor (enabled by default)
- **faq**: Format Agnostic jQ, written in Go ([jzelinskie/faq](https://github.com/jzelinskie/faq))
- **fx**: Terminal JSON viewer, written in JavaScript ([antonmedv/fx](https://github.com/antonmedv/fx))
- **jet**: JSON query tool, written in Clojure

Enable them with environment variables:

```bash
BENCH_FAQ=1 BENCH_FX=1 BENCH_JET=1 ./benchmarks/bench.sh
```

## Conclusion

query-json maintains a strong performance advantage over jq across nearly all tested scenarios, showing consistent 1.5-4.5x speedups.

For JSON processing tasks where performance matters, query-json is a compelling alternative to jq, offering significantly faster execution times while maintaining a familiar query syntax.

## Resources

- [jq Internals: the interpreter](https://github.com/stedolan/jq/wiki/Internals:-the-interpreter)
- [jq Internals: backtracking](https://github.com/stedolan/jq/wiki/Internals:-backtracking)
- [jq Internals: the linker](https://github.com/stedolan/jq/wiki/Internals:-the-linker)
- [jq Internals: the stack](https://github.com/stedolan/jq/wiki/Internals:-the-stack)
- [Hyperfine benchmarking tool](https://github.com/sharkdp/hyperfine)

---

**Want to see other jq-like tools benchmarked?** Please open an issue! If the queries match 1-to-1 with jq, we can easily add them to the comparison.
