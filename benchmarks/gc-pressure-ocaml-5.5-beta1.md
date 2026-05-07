# query-json GC Pressure Baseline: OCaml 5.5.0 Beta1

This is a local run using the latest OCaml 5.5 compiler available in the current opam repository. There was no final `ocaml-base-compiler.5.5.0` package available at collection time, so this uses `ocaml-base-compiler.5.5.0~beta1`.

- Date: 2026-05-07
- OCaml version: `5.5.0~beta1`
- Switch: `query-json-ocaml-5.5-beta1`
- Command: `opam exec --switch=query-json-ocaml-5.5-beta1 -- dune exec --build-dir _build-ocaml55 benchmarks/bench_gc_pressure.exe`
- File: `benchmarks/big.json`
- File size: `574908 bytes`
- Iterations per scenario: `8`

| Scenario | Work s | Full major ms | Compact ms | Alloc MiB | Promoted MiB | Major GCs | Heap work MiB | Heap major MiB | Heap compact MiB | Free major MiB | Free compact MiB | Fragments major | Fragments compact | RSS work MiB | RSS compact MiB | Observed |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `parse_drop` | 0.043 | 0.730 | 0.459 | 22.4 | 12.8 | 7 | 5.6 | 1.3 | 1.2 | 0.7 | 0.6 | 325 | 317 | 13.0 | 8.3 | 12944 |
| `parse_render_drop` | 0.068 | 0.174 | 0.396 | 39.8 | 18.5 | 31 | 4.3 | 1.3 | 1.2 | 0.7 | 0.6 | 325 | 317 | 12.7 | 8.4 | 4599264 |
| `retained_filter_query` | 0.009 | 1.143 | 1.584 | 16.0 | 2.4 | 2 | 4.2 | 3.6 | 3.5 | 0.7 | 0.6 | 617 | 609 | 11.6 | 11.6 | 4098 |
| `retained_group_by` | 0.009 | 1.222 | 1.548 | 8.0 | 2.7 | 2 | 4.4 | 3.6 | 3.5 | 0.7 | 0.6 | 617 | 609 | 11.9 | 11.6 | 1762 |
| `retained_render` | 0.027 | 1.341 | 1.555 | 18.4 | 2.3 | 9 | 8.6 | 3.6 | 3.5 | 0.6 | 0.6 | 613 | 609 | 17.2 | 11.7 | 4600882 |
| `retained_some_parses` | 0.046 | 2.810 | 3.731 | 22.4 | 14.3 | 7 | 10.7 | 6.0 | 5.8 | 0.8 | 0.6 | 929 | 905 | 18.7 | 15.5 | 12944 |

## Quick Comparison Against Local OCaml 5.4.0 Baseline

| Scenario | 5.4 compact ms | 5.5 beta1 compact ms | Delta |
|---|---:|---:|---:|
| `parse_drop` | 0.476 | 0.459 | -3.6% |
| `parse_render_drop` | 0.689 | 0.396 | -42.5% |
| `retained_filter_query` | 1.555 | 1.584 | +1.9% |
| `retained_group_by` | 1.626 | 1.548 | -4.8% |
| `retained_render` | 1.464 | 1.555 | +6.2% |
| `retained_some_parses` | 3.564 | 3.731 | +4.7% |

The 5.5 beta1 run is broadly similar to the 5.4.0 baseline on this workload. The strongest local improvement is `parse_render_drop`, but this single run should be treated as directional rather than statistically stable.
