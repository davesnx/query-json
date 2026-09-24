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

## Compare prepared execution and one-shot library calls

Run the in-process execution benchmark with the project's opam dependencies installed:

```bash
make bench-execution

# Override the default operation counts for a longer run.
opam exec -- dune exec --root . --profile=release benchmarks/bench_execution.exe -- \
  --iterations 10000 --warmup 1000 --samples 7
```

If no opam switch is selected, prefix either command with `OPAMSWITCH=<switch-name>`.
Use the same compiler, release profile, GC settings, and idle machine when comparing runs.
The output records the OCaml version, word size, OS type, key GC settings, queries, and operation counts. It prints prepared-execution and one-shot library tables for the same workloads, then prepared-sink, input-inclusive, and first-result comparisons. Run from the repository root so the first-result table can read `benchmarks/big.json`.

### Prepared execution

For this table, each workload parses its query and JSON once and calls `Execution.prepare` once.
Before any timing, the benchmark requires the expected backend, checks the interpreter result against a fixed expected result, and compares the complete prepared result with `Interpreter.execute`.
Structural equality checks result order, nested values, and numeric constructors, rather than only a checksum or result count.
A mismatch, error, halt, or wrong backend stops the run with a nonzero exit status.

| Workload | Expected backend | Input and result | Prepared operations/sample | One-shot operations/sample |
|---|---|---|---:|---:|
| `deep_scalar_chain` | Compiled | Nested field/index chain returning `42` | 100,000 | 5,000 |
| `scalar_predicate` | Compiled | Integer arithmetic, comparison, and boolean predicate returning `true` | 50,000 | 5,000 |
| `iterator_select_field` | Compiled | 128 objects, mixed passing/failing predicates, 25 ordered integer results | 2,000 | 2,000 |
| `map_transform` | Compiled | 128 objects transformed into one array of 128 integers | 2,000 | 2,000 |
| `fallback_length` | Interpreted | `.root.groups \| length` returning `2`. Unsupported `length` forces whole-query fallback. | 100,000 | 5,000 |

Both tables use 1,000 warmup operations per path and workload, then five paired samples with alternating path order.
`--iterations` overrides the per-workload operation counts in both tables. `--warmup` and `--samples` override their respective defaults. All counts must be positive.
Each operation executes the whole query and materializes its full result list.
The timed loop calls an opaque function and stores each opaque result in a shared sink so the compiler cannot remove the work.
Full result checks also run after warmup and at each sample endpoint, outside timing.

The table reports median elapsed nanoseconds per operation and median allocated bytes per operation for prepared `Execution.execute` (`E`) and `Interpreter.execute` (`I`).
`Time delta` and `Alloc delta` are `(E / I - 1) * 100`. Positive values show a regression in that run.
There is no performance pass/fail threshold.

### One-shot library calls

The second table measures the work that `Core.run` performs on each call:

- Candidate (`C`) calls the real `Core.run`: parse the query, prepare an execution plan, execute it, render every result, and join the strings with newlines.
- Reference (`R`) follows the former `Core.run` path: call `Core.parse`, call `Interpreter.execute`, render every result with `Json.to_string_pretty`, and join the strings with newlines. It does not prepare a plan.

Both paths use `debug=false`, `colorize=false`, `verbose=false`, `raw=false`, and `summarize=false`.
They receive the same already parsed `Json.t` used by the prepared comparison. **JSON parsing, process startup, and stdout are excluded.** Query parsing, per-call preparation on the candidate path, execution, and rendering are included.
The default one-shot counts are capped at 5,000 operations per sample to limit run time.

Before either table is timed, the benchmark compares complete `Ok string` or `Error string` results, including whitespace and error text.
For each workload, the reference string must also equal the rendered fixed expected result.
Two additional untimed checks compare parse and runtime errors and require an `Error` result.
The benchmark repeats complete result checks after warmup and at each sample endpoint, outside timing.
A mismatch stops the run with a nonzero exit status.

The one-shot table reports median `C ns/op`, `R ns/op`, `C B/op`, and `R B/op`.
Its deltas are `(C / R - 1) * 100`, with positive values showing regressions and no performance threshold.
Use this table to assess preparation cost on the library call path. Prepared-plan gains alone do not show whether one-shot calls improve.

### Prepared result sink

The third table runs `.[]` over 16,384 integers, from 1 through 16,384, using one prepared compiled plan and one input built before timing:

- Fold (`F`) calls `Execution.fold` into an integer checksum of 134,225,920.
- List (`L`) calls `Execution.execute` and keeps its complete result list. It does not compute a checksum during timing.

This comparison isolates final result-list allocation on a large output stream. Both paths still include the compiled iterator's work and allocation. Fold includes the scalar callback. **Parsing, plan preparation, input generation, rendering, and stdout are excluded.** The input remains a complete in-memory JSON array. This is not a streaming JSON parser or a peak-memory measurement.

Before timing, the benchmark requires the compiled backend, checks the full collected list against the fixture, and checks the fold checksum. It repeats these checks after warmup and each sample, outside timing. Unexpected values, errors, halts, or checksums stop the run. The checksum is a consumption check, not a full proof of fold result order.

This workload defaults to 100 operations per sample and 10 warmup operations per path. `--iterations` and `--warmup` can reduce these counts, but this table caps them at 100 and 10. It uses the requested `--samples` count, with alternating path order and the same timer and allocation counters as the other tables.

The table reports median `F ns/op`, `L ns/op`, `F B/op`, and `L B/op`. Deltas are `(F / L - 1) * 100`. Negative values mean less time or allocation for fold. There is no performance threshold.

### Input-inclusive selective reader

The fourth table compares two paths from the same generated JSON string to the complete rendered result:

- Candidate (`C`) calls `Core.run_input` with a `Core.String` source.
- Reference (`R`) calls `Json.parse_string`, then the existing `Core.run` on the parsed value.

Both timed paths include query parsing, JSON parsing and validation, preparation, execution, and rendering. Both use `debug=false`, `colorize=false`, `verbose=false`, `raw=false`, and `summarize=false`. Payload generation and result checks are outside timing.

Each valid object has a small `"keep":{"value":42}` member and a `discard` member containing 64 nested arrays of 256 integers, from 0 through 16,383. The early and late payloads contain the same members in opposite order. The output records their byte length.

| Workload | Query | Position and expected result |
|---|---|---|
| `input_early_keep` | `.keep.value` | `keep` first, before the large discarded member. Returns `42`. |
| `input_late_keep` | `.keep.value` | `keep` last, after the large discarded member. Returns `42`. |
| `input_full_fallback` | `length` | Early payload with a full-input interpreted query. Returns `2`. |

**Every input byte is validated.** Selection only avoids retaining or materializing discarded containers after an early matched root key. The late-selected case must parse the large member before finding `keep`, so it exposes the position-dependent cost. The fallback control requires the complete object. The source String itself remains retained in all cases. Allocated bytes per operation measure allocation volume, not retained memory or peak RSS.

Before timing, the benchmark checks each backend, requires the reference to equal the rendered fixed expected result, and compares the exact candidate and reference `Ok string` or `Error string` results. It repeats exact result checks after each path's warmup and at every sample endpoint. These checks are outside timing. A mismatch stops the run.

Each case defaults to 100 operations per sample and 10 warmup operations per path. `--iterations` and `--warmup` can reduce these counts, but this table caps them at 100 and 10. It uses the requested sample count, alternating path order, and the existing timer and allocation counters.

The table reports median `C ns/op`, `R ns/op`, `C B/op`, and `R B/op`. Deltas are `(C / R - 1) * 100`. Compare the early and late rows to report position effects, and use the fallback row to assess full-input overhead. There is no hard performance pass threshold.

### First rendered result

The `event_member_first` row reads `benchmarks/big.json` before timing and wraps its array as `{"rows":<array>,"tail":0}`. The query is `.rows[] | .id`. It compares the first emitted result of `Core.run_input_iter` (`S`) with the complete return of `Core.run_input` (`A`), both on the same retained `Core.String` source.

Before timing, the benchmark requires a compiled plan and a `Member_items ("rows", ...)` cut through `Execution.For_test.stream_cut`. It collects the iterator's complete rendered output array and the atomic call's rendered string, requires their joined forms to match, and requires the first output to be `1`.

Each paired sample makes one fresh call per path and alternates their order. `--samples` sets the number of pairs. `--warmup` is capped at three calls per path. `--iterations` does not apply to this table. Immediately before each call, the benchmark runs `Gc.full_major ()`, reads `Gc.allocated_bytes ()`, and reads `Unix.gettimeofday ()`. For `S`, the first emit callback records elapsed nanoseconds and allocated bytes before it checks the result, then the call continues to EOF and checks every rendered output, its order, and the final count against the expected array. For `A`, the measurement stops when `Core.run_input` returns, and the result is checked against the expected string. An error or mismatch fails the run.

The measurement includes query parsing and preparation, JSON parsing, execution, and rendering. `S` measures time to the first complete child; `A` parses, validates, executes, and renders the complete document before returning. Fixture load and generation, process startup, stdout, and result checks are excluded. The source string and expected output remain retained. This measures library call latency, not the first byte observed from a CLI process.

The row reports medians for `S first ns`, `A complete ns`, `S first B`, and `A complete B`, followed by time delta, allocation delta, and samples. Deltas are `(S / A - 1) * 100`. **B is allocation volume to the reported endpoint, not peak RSS or total allocation through EOF.** There is no performance threshold.

### Measure observed CLI peak RSS on Linux

Use a separate fresh-process measurement for peak RSS. Run this procedure from the repository root on Linux with GNU `/usr/bin/time`. Build once, create the wrapped fixture once, then alternate the two CLI modes across repeated pairs:

```bash
opam exec --switch=query-json-ocaml-5.5-beta1 -- \
  dune build --root . --profile=release cli/cli.exe

binary="$PWD/_build/default/cli/cli.exe"
results=$(mktemp -d)
{
  printf '{"rows":'
  cat benchmarks/big.json
  printf ',"tail":0}'
} > "$results/member.json"

"$binary" --no-color '.rows[] | .id' "$results/member.json" > "$results/default.out"
"$binary" --no-color --stream-output '.rows[] | .id' "$results/member.json" > "$results/ready.out"
cmp "$results/default.out" "$results/ready.out" || exit 1

for pair in 1 2 3 4 5 6 7 8 9 10; do
  if [ $((pair % 2)) -eq 1 ]; then
    modes='ready default'
  else
    modes='default ready'
  fi
  for mode in $modes; do
    if [ "$mode" = ready ]; then
      /usr/bin/time -v -o "$results/$pair-$mode.time" \
        "$binary" --no-color --stream-output '.rows[] | .id' "$results/member.json" > /dev/null || exit 1
    else
      /usr/bin/time -v -o "$results/$pair-$mode.time" \
        "$binary" --no-color '.rows[] | .id' "$results/member.json" > /dev/null || exit 1
    fi
  done
done
printf 'Reports: %s\n' "$results"
```

Read `Maximum resident set size (kbytes)` from each report. Calculate a median separately for each mode across all ten runs. For an even count, average the two middle sorted values. Keep the individual values and report their range. Repeat the paired series on an idle machine before drawing conclusions. Record the fixture byte count, platform, OCaml version, build profile, GC settings, and commands with the results.

Each timed command starts a fresh CLI process, reads the same file, and sends stdout to `/dev/null`. These measurements include startup, parsing, execution, rendering, and output handling. Default mode collects output atomically. Ready mode flushes each output, so this comparison also includes different result collection and output handling costs. It does not isolate only the underlying streaming-versus-atomic execution path.

Report these values as **observed max RSS for this fixture/platform**. They do not establish bounded or constant memory. Complete children, retained member prefixes, runtime heap sizing, and rendering can affect RSS. This procedure is separate from the allocation-volume and first-callback table. It has no pass/fail threshold.

### Measurement limits

- The prepared-execution and prepared-sink tables exclude query parsing, preparation, and rendering. The one-shot, input-inclusive, and first-result tables include them. The input-inclusive and first-result tables include JSON parsing. First-result timing ends at the first callback for the streamed path (`S`), before result checks; for the atomic path (`A`) it ends when the call returns, after full validation, execution, and rendering. All tables exclude fixture generation, result checks, startup, and stdout. None measures end-to-end CLI latency.
- Allocation uses the difference between `Gc.allocated_bytes` readings. It includes minor- and major-heap allocations without counting promotion twice. It is allocation volume, not retained memory or peak RSS.
- `Gc.full_major ()` runs before each sample, outside timing. Collections triggered during execution remain in the measurement. The loop, sink store, and small fixed timer/counter overhead are included and are not subtracted.
- Elapsed time uses `Unix.gettimeofday`, matching the existing parser benchmark without adding dependencies. This wall clock can change. Non-positive durations fail the run, but positive clock jumps and scheduling noise can still distort results. Nanoseconds are converted from seconds, not clock resolution. The first-result table measures one call per sample rather than a batch.
- Medians and alternating order reduce noise but do not supply confidence intervals. Repeat runs before drawing conclusions, especially for small fallback differences. CPU frequency, system load, compiler version, and GC settings affect results.
- These deterministic fixtures time successful integer/boolean execution and fallback paths. Error checks are untimed. They do not measure errors, effects, halt behavior, large numbers, arbitrary JSON shapes, every supported query, peak streaming memory, or other rendering options. Use the execution tests for broader correctness coverage.
- The one-shot reference copies the former `Core.run` behavior. Review it if parsing, error handling, or rendering changes. The candidate calls `Core.run` directly so its measured preparation cost cannot drift from that library entry point.

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
