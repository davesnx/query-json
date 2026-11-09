# OxCaml Benchmark Report

Benchmarks run with OxCaml 5.2.0+ox optimizations:
- Unboxed float operations (`float#`) in Operators module
- `[@zero_alloc]` annotations on arithmetic helpers
- Local allocations for regex captures
- Optimized slice function with local ref

===================================
query-json performance benchmarks
===================================

query-json version: 0.6.1
jq version: jq-1.7
Date: Mon Dec 15 08:33:53 PM GMT 2025

===================================
Small File Tests (1.3KB)
===================================

### Identity
Query: .
File: small.json

Benchmark 1: query-json '.' benchmarks/small.json
  Time (mean ± σ):       3.5 ms ±   0.6 ms    [User: 1.8 ms, System: 1.7 ms]
  Range (min … max):     2.2 ms …   5.8 ms    546 runs
 
  Warning: Command took less than 5 ms to complete. Note that the results might be inaccurate because hyperfine can not calibrate the shell startup time much more precise than this limit. You can try to use the `-N`/`--shell=none` option to disable the shell completely.
 
Benchmark 2: jq '.' benchmarks/small.json
  Time (mean ± σ):       1.6 ms ±   0.2 ms    [User: 1.3 ms, System: 0.4 ms]
  Range (min … max):     1.1 ms …   2.8 ms    1243 runs
 
  Warning: Command took less than 5 ms to complete. Note that the results might be inaccurate because hyperfine can not calibrate the shell startup time much more precise than this limit. You can try to use the `-N`/`--shell=none` option to disable the shell completely.
 
Summary
  'jq '.' benchmarks/small.json' ran
    2.24 ± 0.45 times faster than 'query-json '.' benchmarks/small.json'

### Select field
Query: .first.id
File: small.json

Benchmark 1: query-json '.first.id' benchmarks/small.json
  Time (mean ± σ):       3.6 ms ±   0.7 ms    [User: 1.7 ms, System: 1.9 ms]
  Range (min … max):     2.1 ms …   5.9 ms    624 runs
 
  Warning: Command took less than 5 ms to complete. Note that the results might be inaccurate because hyperfine can not calibrate the shell startup time much more precise than this limit. You can try to use the `-N`/`--shell=none` option to disable the shell completely.
 
Benchmark 2: jq '.first.id' benchmarks/small.json
  Time (mean ± σ):       1.6 ms ±   0.2 ms    [User: 1.3 ms, System: 0.3 ms]
  Range (min … max):     1.1 ms …   2.9 ms    1223 runs
 
  Warning: Command took less than 5 ms to complete. Note that the results might be inaccurate because hyperfine can not calibrate the shell startup time much more precise than this limit. You can try to use the `-N`/`--shell=none` option to disable the shell completely.
 
Summary
  'jq '.first.id' benchmarks/small.json' ran
    2.28 ± 0.53 times faster than 'query-json '.first.id' benchmarks/small.json'

### Nested access with map
Query: .second.store.books | map(.price + 10)
File: small.json

Benchmark 1: query-json '.second.store.books | map(.price + 10)' benchmarks/small.json
  Time (mean ± σ):       3.5 ms ±   0.6 ms    [User: 1.6 ms, System: 1.9 ms]
  Range (min … max):     2.1 ms …   5.7 ms    606 runs
 
  Warning: Command took less than 5 ms to complete. Note that the results might be inaccurate because hyperfine can not calibrate the shell startup time much more precise than this limit. You can try to use the `-N`/`--shell=none` option to disable the shell completely.
 
Benchmark 2: jq '.second.store.books | map(.price + 10)' benchmarks/small.json
  Time (mean ± σ):       1.6 ms ±   0.2 ms    [User: 1.4 ms, System: 0.3 ms]
  Range (min … max):     1.2 ms …   2.9 ms    1085 runs
 
  Warning: Command took less than 5 ms to complete. Note that the results might be inaccurate because hyperfine can not calibrate the shell startup time much more precise than this limit. You can try to use the `-N`/`--shell=none` option to disable the shell completely.
  Warning: Statistical outliers were detected. Consider re-running this benchmark on a quiet PC without any interferences from other programs. It might help to use the '--warmup' or '--prepare' options.
 
Summary
  'jq '.second.store.books | map(.price + 10)' benchmarks/small.json' ran
    2.13 ± 0.47 times faster than 'query-json '.second.store.books | map(.price + 10)' benchmarks/small.json'

===================================
Medium File Tests (104KB)
===================================

### Identity
Query: .
File: medium.json

Benchmark 1: query-json '.' benchmarks/medium.json
  Time (mean ± σ):      11.4 ms ±   1.0 ms    [User: 6.8 ms, System: 4.6 ms]
  Range (min … max):     8.9 ms …  13.7 ms    209 runs
 
Benchmark 2: jq '.' benchmarks/medium.json
  Time (mean ± σ):       5.5 ms ±   0.3 ms    [User: 4.5 ms, System: 1.1 ms]
  Range (min … max):     5.0 ms …   6.6 ms    459 runs
 
Summary
  'jq '.' benchmarks/medium.json' ran
    2.05 ± 0.21 times faster than 'query-json '.' benchmarks/medium.json'

### Map identity
Query: map(.)
File: medium.json

Benchmark 1: query-json 'map(.)' benchmarks/medium.json
  Time (mean ± σ):      11.8 ms ±   1.0 ms    [User: 7.1 ms, System: 4.7 ms]
  Range (min … max):     9.5 ms …  15.2 ms    230 runs
 
Benchmark 2: jq 'map(.)' benchmarks/medium.json
  Time (mean ± σ):       6.1 ms ±   0.4 ms    [User: 5.0 ms, System: 1.1 ms]
  Range (min … max):     5.4 ms …   8.5 ms    433 runs
 
Summary
  'jq 'map(.)' benchmarks/medium.json' ran
    1.95 ± 0.20 times faster than 'query-json 'map(.)' benchmarks/medium.json'

### Map with field access
Query: map(.time)
File: medium.json

Benchmark 1: query-json 'map(.time)' benchmarks/medium.json
  Time (mean ± σ):       6.8 ms ±   0.9 ms    [User: 3.7 ms, System: 3.1 ms]
  Range (min … max):     4.9 ms …  10.1 ms    348 runs
 
  Warning: Command took less than 5 ms to complete. Note that the results might be inaccurate because hyperfine can not calibrate the shell startup time much more precise than this limit. You can try to use the `-N`/`--shell=none` option to disable the shell completely.
 
Benchmark 2: jq 'map(.time)' benchmarks/medium.json
  Time (mean ± σ):       5.1 ms ±   0.3 ms    [User: 4.1 ms, System: 1.0 ms]
  Range (min … max):     4.6 ms …   6.3 ms    493 runs
 
  Warning: Command took less than 5 ms to complete. Note that the results might be inaccurate because hyperfine can not calibrate the shell startup time much more precise than this limit. You can try to use the `-N`/`--shell=none` option to disable the shell completely.
 
Summary
  'jq 'map(.time)' benchmarks/medium.json' ran
    1.34 ± 0.20 times faster than 'query-json 'map(.time)' benchmarks/medium.json'

### Length
Query: length
File: medium.json

Benchmark 1: query-json 'length' benchmarks/medium.json
  Time (mean ± σ):       4.5 ms ±   0.6 ms    [User: 2.6 ms, System: 2.0 ms]
  Range (min … max):     3.3 ms …   6.3 ms    475 runs
 
  Warning: Command took less than 5 ms to complete. Note that the results might be inaccurate because hyperfine can not calibrate the shell startup time much more precise than this limit. You can try to use the `-N`/`--shell=none` option to disable the shell completely.
 
Benchmark 2: jq 'length' benchmarks/medium.json
  Time (mean ± σ):       3.8 ms ±   0.3 ms    [User: 3.0 ms, System: 0.9 ms]
  Range (min … max):     3.2 ms …   5.8 ms    622 runs
 
  Warning: Command took less than 5 ms to complete. Note that the results might be inaccurate because hyperfine can not calibrate the shell startup time much more precise than this limit. You can try to use the `-N`/`--shell=none` option to disable the shell completely.
 
Summary
  'jq 'length' benchmarks/medium.json' ran
    1.18 ± 0.19 times faster than 'query-json 'length' benchmarks/medium.json'

===================================
Big File Tests (575KB)
===================================

### Identity
Query: .
File: big.json

Benchmark 1: query-json '.' benchmarks/big.json
  Time (mean ± σ):      31.0 ms ±   1.8 ms    [User: 24.6 ms, System: 6.4 ms]
  Range (min … max):    27.5 ms …  38.4 ms    105 runs
 
Benchmark 2: jq '.' benchmarks/big.json
  Time (mean ± σ):      16.6 ms ±   0.6 ms    [User: 15.2 ms, System: 1.5 ms]
  Range (min … max):    15.6 ms …  20.4 ms    167 runs
 
Summary
  'jq '.' benchmarks/big.json' ran
    1.86 ± 0.12 times faster than 'query-json '.' benchmarks/big.json'

### Map identity
Query: map(.)
File: big.json

Benchmark 1: query-json 'map(.)' benchmarks/big.json
  Time (mean ± σ):      31.3 ms ±   1.7 ms    [User: 24.1 ms, System: 7.2 ms]
  Range (min … max):    27.6 ms …  36.8 ms    89 runs
 
Benchmark 2: jq 'map(.)' benchmarks/big.json
  Time (mean ± σ):      16.9 ms ±   0.6 ms    [User: 15.4 ms, System: 1.5 ms]
  Range (min … max):    15.9 ms …  22.8 ms    169 runs
 
  Warning: Statistical outliers were detected. Consider re-running this benchmark on a quiet PC without any interferences from other programs. It might help to use the '--warmup' or '--prepare' options.
 
Summary
  'jq 'map(.)' benchmarks/big.json' ran
    1.85 ± 0.12 times faster than 'query-json 'map(.)' benchmarks/big.json'

### Keys
Query: keys
File: big.json

Benchmark 1: query-json 'keys' benchmarks/big.json
  Time (mean ± σ):      15.8 ms ±   1.2 ms    [User: 10.1 ms, System: 5.7 ms]
  Range (min … max):    13.2 ms …  20.7 ms    170 runs
 
Benchmark 2: jq 'keys' benchmarks/big.json
  Time (mean ± σ):       9.6 ms ±   0.6 ms    [User: 8.1 ms, System: 1.5 ms]
  Range (min … max):     8.7 ms …  14.3 ms    314 runs
 
Summary
  'jq 'keys' benchmarks/big.json' ran
    1.65 ± 0.16 times faster than 'query-json 'keys' benchmarks/big.json'

### Length
Query: length
File: big.json

Benchmark 1: query-json 'length' benchmarks/big.json
  Time (mean ± σ):       8.8 ms ±   0.6 ms    [User: 6.4 ms, System: 2.5 ms]
  Range (min … max):     7.5 ms …  10.8 ms    290 runs
 
Benchmark 2: jq 'length' benchmarks/big.json
  Time (mean ± σ):       9.6 ms ±   0.4 ms    [User: 8.2 ms, System: 1.5 ms]
  Range (min … max):     8.7 ms …  10.7 ms    311 runs
 
Summary
  'query-json 'length' benchmarks/big.json' ran
    1.08 ± 0.08 times faster than 'jq 'length' benchmarks/big.json'

### First element
Query: .[0]
File: big.json

Benchmark 1: query-json '.[0]' benchmarks/big.json
  Time (mean ± σ):       9.1 ms ±   0.7 ms    [User: 6.3 ms, System: 2.8 ms]
  Range (min … max):     7.5 ms …  11.3 ms    312 runs
 
Benchmark 2: jq '.[0]' benchmarks/big.json
  Time (mean ± σ):      10.3 ms ±   1.1 ms    [User: 8.3 ms, System: 2.0 ms]
  Range (min … max):     8.8 ms …  17.1 ms    293 runs
 
Summary
  'query-json '.[0]' benchmarks/big.json' ran
    1.13 ± 0.15 times faster than 'jq '.[0]' benchmarks/big.json'

### Filter and map
Query: filter(.base."Attack" > 100) | map(.name.english)
File: big.json

Benchmark 1: query-json 'filter(.base."Attack" > 100) | map(.name.english)' benchmarks/big.json
  Time (mean ± σ):      10.6 ms ±   0.9 ms    [User: 7.3 ms, System: 3.3 ms]
  Range (min … max):     8.3 ms …  15.6 ms    284 runs
 
Benchmark 2: jq 'map(select(.base.Attack > 100)) | map(.name.english)' benchmarks/big.json
  Time (mean ± σ):      10.5 ms ±   0.6 ms    [User: 8.9 ms, System: 1.6 ms]
  Range (min … max):     9.5 ms …  13.1 ms    272 runs
 
Summary
  'jq 'map(select(.base.Attack > 100)) | map(.name.english)' benchmarks/big.json' ran
    1.01 ± 0.11 times faster than 'query-json 'filter(.base."Attack" > 100) | map(.name.english)' benchmarks/big.json'

===================================
Huge File Tests (97MB)
===================================

### Keys
Query: keys
File: huge.json

Benchmark 1: query-json 'keys' benchmarks/huge.json
  Time (mean ± σ):      1.152 s ±  0.014 s    [User: 1.063 s, System: 0.088 s]
  Range (min … max):    1.132 s …  1.170 s    10 runs
 
Benchmark 2: jq 'keys' benchmarks/huge.json
  Time (mean ± σ):      1.188 s ±  0.038 s    [User: 1.063 s, System: 0.125 s]
  Range (min … max):    1.147 s …  1.283 s    10 runs
 
Summary
  'query-json 'keys' benchmarks/huge.json' ran
    1.03 ± 0.04 times faster than 'jq 'keys' benchmarks/huge.json'

### Identity (streaming)
Query: .
File: huge.json

Benchmark 1: query-json '.' benchmarks/huge.json
  Time (mean ± σ):      4.208 s ±  0.117 s    [User: 3.739 s, System: 0.468 s]
  Range (min … max):    4.017 s …  4.390 s    10 runs
 
Benchmark 2: jq '.' benchmarks/huge.json
  Time (mean ± σ):      2.746 s ±  0.049 s    [User: 2.584 s, System: 0.161 s]
  Range (min … max):    2.709 s …  2.878 s    10 runs
 
  Warning: Statistical outliers were detected. Consider re-running this benchmark on a quiet PC without any interferences from other programs. It might help to use the '--warmup' or '--prepare' options.
 
Summary
  'jq '.' benchmarks/huge.json' ran
    1.53 ± 0.05 times faster than 'query-json '.' benchmarks/huge.json'

===================================
Stdin Piping Tests (575KB)
===================================

### Pipe JSON to stdin
Query: .
File: big.json

Benchmark 1: cat benchmarks/big.json | query-json '.'
  Time (mean ± σ):      31.8 ms ±   2.6 ms    [User: 25.6 ms, System: 7.3 ms]
  Range (min … max):    28.9 ms …  46.3 ms    100 runs
 
Benchmark 2: cat benchmarks/big.json | jq '.'
  Time (mean ± σ):      16.8 ms ±   0.4 ms    [User: 16.1 ms, System: 1.9 ms]
  Range (min … max):    15.7 ms …  19.3 ms    163 runs
 
Summary
  'cat benchmarks/big.json | jq '.'' ran
    1.89 ± 0.16 times faster than 'cat benchmarks/big.json | query-json '.''

===================================
Benchmark Complete!
===================================
