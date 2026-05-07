# query-json GC Pressure Baseline

This is a local baseline from the stock OCaml runtime. Treat the absolute numbers as machine-specific; the table is mainly useful as a shape check for comparing another runtime, such as OCaml's `new_compactor` branch, with the same command.

- Date: 2026-05-07
- OCaml version: `5.4.0`
- Command: `dune exec benchmarks/bench_gc_pressure.exe`
- File: `benchmarks/big.json`
- File size: `574908 bytes`
- Iterations per scenario: `8`

| Scenario | Work s | Full major ms | Compact ms | Alloc MiB | Promoted MiB | Major GCs | Heap work MiB | Heap major MiB | Heap compact MiB | Free major MiB | Free compact MiB | Fragments major | Fragments compact | RSS work MiB | RSS compact MiB | Observed |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `parse_drop` | 0.040 | 0.270 | 0.476 | 22.4 | 12.0 | 15 | 3.4 | 1.3 | 1.2 | 0.7 | 0.6 | 334 | 327 | 13.0 | 9.1 | 12944 |
| `parse_render_drop` | 0.064 | 0.635 | 0.689 | 38.8 | 18.6 | 23 | 6.8 | 1.3 | 1.2 | 0.7 | 0.6 | 334 | 327 | 17.8 | 9.1 | 4599264 |
| `retained_filter_query` | 0.009 | 1.168 | 1.555 | 16.0 | 2.4 | 3 | 4.2 | 3.6 | 3.5 | 0.7 | 0.6 | 626 | 619 | 12.3 | 12.2 | 4098 |
| `retained_group_by` | 0.008 | 1.242 | 1.626 | 8.0 | 2.7 | 3 | 4.5 | 3.6 | 3.5 | 0.7 | 0.6 | 626 | 619 | 12.6 | 12.2 | 1762 |
| `retained_render` | 0.028 | 1.436 | 1.464 | 19.3 | 2.3 | 9 | 11.2 | 3.6 | 3.5 | 0.6 | 0.6 | 622 | 619 | 20.6 | 13.1 | 4600882 |
| `retained_some_parses` | 0.043 | 3.202 | 3.564 | 22.5 | 14.3 | 12 | 10.8 | 6.0 | 5.8 | 0.8 | 0.6 | 934 | 915 | 19.5 | 14.1 | 12944 |

## Scenarios

- `parse_drop`: repeatedly parse JSON and drop each tree.
- `parse_render_drop`: parse JSON, pretty-print it, then drop both values.
- `retained_filter_query`: keep the parsed JSON live while running filter/map queries.
- `retained_group_by`: keep the parsed JSON live while repeatedly grouping results.
- `retained_render`: keep the parsed JSON live while repeatedly pretty-printing it.
- `retained_some_parses`: parse repeatedly, retaining a few trees to fragment live data.
