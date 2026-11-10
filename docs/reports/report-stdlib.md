===================================
query-json performance benchmarks
===================================

query-json version: 0.6.1
jq version: jq-1.7
Date: Mon Dec 15 08:54:58 PM GMT 2025

===================================
Small File Tests (1.3KB)
===================================

### Identity
Query: .
File: small.json

Benchmark 1: query-json '.' benchmarks/small.json
  Time (mean ± σ):       1.6 ms ±   0.6 ms    [User: 1.2 ms, System: 0.5 ms]
  Range (min … max):     0.9 ms …   4.0 ms    1486 runs
 
  Warning: Command took less than 5 ms to complete. Note that the results might be inaccurate because hyperfine can not calibrate the shell startup time much more precise than this limit. You can try to use the `-N`/`--shell=none` option to disable the shell completely.
 
Benchmark 2: jq '.' benchmarks/small.json
  Time (mean ± σ):       1.5 ms ±   0.3 ms    [User: 1.3 ms, System: 0.3 ms]
  Range (min … max):     1.1 ms …   3.0 ms    1364 runs
 
  Warning: Command took less than 5 ms to complete. Note that the results might be inaccurate because hyperfine can not calibrate the shell startup time much more precise than this limit. You can try to use the `-N`/`--shell=none` option to disable the shell completely.
  Warning: Statistical outliers were detected. Consider re-running this benchmark on a quiet PC without any interferences from other programs. It might help to use the '--warmup' or '--prepare' options.
 
Summary
  'jq '.' benchmarks/small.json' ran
    1.06 ± 0.43 times faster than 'query-json '.' benchmarks/small.json'

### Select field
Query: .first.id
File: small.json

Benchmark 1: query-json '.first.id' benchmarks/small.json
  Time (mean ± σ):       1.4 ms ±   0.3 ms    [User: 1.1 ms, System: 0.3 ms]
  Range (min … max):     1.0 ms …   5.3 ms    1845 runs
 
  Warning: Command took less than 5 ms to complete. Note that the results might be inaccurate because hyperfine can not calibrate the shell startup time much more precise than this limit. You can try to use the `-N`/`--shell=none` option to disable the shell completely.
  Warning: Statistical outliers were detected. Consider re-running this benchmark on a quiet PC without any interferences from other programs. It might help to use the '--warmup' or '--prepare' options.
 
Benchmark 2: jq '.first.id' benchmarks/small.json
  Time (mean ± σ):       1.7 ms ±   0.3 ms    [User: 1.4 ms, System: 0.3 ms]
  Range (min … max):     1.4 ms …   4.2 ms    1195 runs
 
  Warning: Command took less than 5 ms to complete. Note that the results might be inaccurate because hyperfine can not calibrate the shell startup time much more precise than this limit. You can try to use the `-N`/`--shell=none` option to disable the shell completely.
  Warning: Statistical outliers were detected. Consider re-running this benchmark on a quiet PC without any interferences from other programs. It might help to use the '--warmup' or '--prepare' options.
 
Summary
  'query-json '.first.id' benchmarks/small.json' ran
    1.24 ± 0.33 times faster than 'jq '.first.id' benchmarks/small.json'

### Nested access with map
Query: .second.store.books | map(.price + 10)
File: small.json

Benchmark 1: query-json '.second.store.books | map(.price + 10)' benchmarks/small.json
  Time (mean ± σ):       1.4 ms ±   0.3 ms    [User: 1.1 ms, System: 0.3 ms]
  Range (min … max):     0.9 ms …   3.6 ms    1461 runs
 
  Warning: Command took less than 5 ms to complete. Note that the results might be inaccurate because hyperfine can not calibrate the shell startup time much more precise than this limit. You can try to use the `-N`/`--shell=none` option to disable the shell completely.
  Warning: Statistical outliers were detected. Consider re-running this benchmark on a quiet PC without any interferences from other programs. It might help to use the '--warmup' or '--prepare' options.
 
Benchmark 2: jq '.second.store.books | map(.price + 10)' benchmarks/small.json
  Time (mean ± σ):       1.6 ms ±   0.3 ms    [User: 1.3 ms, System: 0.3 ms]
  Range (min … max):     1.2 ms …   3.4 ms    1485 runs
 
  Warning: Command took less than 5 ms to complete. Note that the results might be inaccurate because hyperfine can not calibrate the shell startup time much more precise than this limit. You can try to use the `-N`/`--shell=none` option to disable the shell completely.
  Warning: Statistical outliers were detected. Consider re-running this benchmark on a quiet PC without any interferences from other programs. It might help to use the '--warmup' or '--prepare' options.
 
Summary
  'query-json '.second.store.books | map(.price + 10)' benchmarks/small.json' ran
    1.14 ± 0.31 times faster than 'jq '.second.store.books | map(.price + 10)' benchmarks/small.json'

===================================
Medium File Tests (104KB)
===================================

### Identity
Query: .
File: medium.json

Benchmark 1: query-json '.' benchmarks/medium.json
  Time (mean ± σ):       8.3 ms ±   0.9 ms    [User: 5.5 ms, System: 2.8 ms]
  Range (min … max):     6.8 ms …  14.0 ms    340 runs
 
Benchmark 2: jq '.' benchmarks/medium.json
  Time (mean ± σ):       5.5 ms ±   0.4 ms    [User: 4.7 ms, System: 0.9 ms]
  Range (min … max):     5.0 ms …   7.0 ms    512 runs
 
  Warning: Command took less than 5 ms to complete. Note that the results might be inaccurate because hyperfine can not calibrate the shell startup time much more precise than this limit. You can try to use the `-N`/`--shell=none` option to disable the shell completely.
 
Summary
  'jq '.' benchmarks/medium.json' ran
    1.51 ± 0.20 times faster than 'query-json '.' benchmarks/medium.json'

### Map identity
Query: map(.)
File: medium.json

Benchmark 1: query-json 'map(.)' benchmarks/medium.json
  Time (mean ± σ):       8.7 ms ±   0.8 ms    [User: 5.7 ms, System: 3.0 ms]
  Range (min … max):     7.1 ms …  11.4 ms    317 runs
 
Benchmark 2: jq 'map(.)' benchmarks/medium.json
  Time (mean ± σ):       6.0 ms ±   0.4 ms    [User: 5.0 ms, System: 1.0 ms]
  Range (min … max):     5.5 ms …   8.1 ms    462 runs
 
Summary
  'jq 'map(.)' benchmarks/medium.json' ran
    1.45 ± 0.17 times faster than 'query-json 'map(.)' benchmarks/medium.json'

### Map with field access
Query: map(.time)
File: medium.json

Benchmark 1: query-json 'map(.time)' benchmarks/medium.json
  Time (mean ± σ):       4.6 ms ±   0.5 ms    [User: 2.7 ms, System: 1.9 ms]
  Range (min … max):     3.6 ms …   6.3 ms    521 runs
 
  Warning: Command took less than 5 ms to complete. Note that the results might be inaccurate because hyperfine can not calibrate the shell startup time much more precise than this limit. You can try to use the `-N`/`--shell=none` option to disable the shell completely.
 
Benchmark 2: jq 'map(.time)' benchmarks/medium.json
  Time (mean ± σ):       5.0 ms ±   0.4 ms    [User: 4.3 ms, System: 0.8 ms]
  Range (min … max):     4.4 ms …   7.7 ms    549 runs
 
  Warning: Command took less than 5 ms to complete. Note that the results might be inaccurate because hyperfine can not calibrate the shell startup time much more precise than this limit. You can try to use the `-N`/`--shell=none` option to disable the shell completely.
 
Summary
  'query-json 'map(.time)' benchmarks/medium.json' ran
    1.10 ± 0.16 times faster than 'jq 'map(.time)' benchmarks/medium.json'

### Length
Query: length
File: medium.json

Benchmark 1: query-json 'length' benchmarks/medium.json
  Time (mean ± σ):       2.7 ms ±   0.3 ms    [User: 1.9 ms, System: 0.8 ms]
  Range (min … max):     2.0 ms …   4.0 ms    819 runs
 
  Warning: Command took less than 5 ms to complete. Note that the results might be inaccurate because hyperfine can not calibrate the shell startup time much more precise than this limit. You can try to use the `-N`/`--shell=none` option to disable the shell completely.
 
Benchmark 2: jq 'length' benchmarks/medium.json
  Time (mean ± σ):       3.9 ms ±   0.3 ms    [User: 2.9 ms, System: 1.0 ms]
  Range (min … max):     3.3 ms …   5.9 ms    659 runs
 
  Warning: Command took less than 5 ms to complete. Note that the results might be inaccurate because hyperfine can not calibrate the shell startup time much more precise than this limit. You can try to use the `-N`/`--shell=none` option to disable the shell completely.
 
Summary
  'query-json 'length' benchmarks/medium.json' ran
    1.46 ± 0.22 times faster than 'jq 'length' benchmarks/medium.json'

===================================
Big File Tests (575KB)
===================================

### Identity
Query: .
File: big.json

Benchmark 1: query-json '.' benchmarks/big.json
  Time (mean ± σ):      28.0 ms ±   1.3 ms    [User: 22.9 ms, System: 5.0 ms]
  Range (min … max):    25.1 ms …  31.5 ms    110 runs
 
Benchmark 2: jq '.' benchmarks/big.json
  Time (mean ± σ):      16.5 ms ±   0.6 ms    [User: 14.9 ms, System: 1.6 ms]
  Range (min … max):    15.5 ms …  21.2 ms    168 runs
 
Summary
  'jq '.' benchmarks/big.json' ran
    1.70 ± 0.10 times faster than 'query-json '.' benchmarks/big.json'

### Map identity
Query: map(.)
File: big.json

Benchmark 1: query-json 'map(.)' benchmarks/big.json
  Time (mean ± σ):      27.9 ms ±   1.0 ms    [User: 22.6 ms, System: 5.3 ms]
  Range (min … max):    25.1 ms …  31.4 ms    93 runs
 
Benchmark 2: jq 'map(.)' benchmarks/big.json
  Time (mean ± σ):      16.7 ms ±   0.5 ms    [User: 15.2 ms, System: 1.6 ms]
  Range (min … max):    15.7 ms …  18.5 ms    172 runs
 
Summary
  'jq 'map(.)' benchmarks/big.json' ran
    1.67 ± 0.08 times faster than 'query-json 'map(.)' benchmarks/big.json'

### Keys
Query: keys
File: big.json

Benchmark 1: query-json 'keys' benchmarks/big.json
  Time (mean ± σ):      13.5 ms ±   0.8 ms    [User: 9.8 ms, System: 3.7 ms]
  Range (min … max):    11.8 ms …  16.5 ms    201 runs
 
Benchmark 2: jq 'keys' benchmarks/big.json
  Time (mean ± σ):      10.0 ms ±   0.5 ms    [User: 8.6 ms, System: 1.5 ms]
  Range (min … max):     8.8 ms …  11.3 ms    278 runs
 
Summary
  'jq 'keys' benchmarks/big.json' ran
    1.34 ± 0.11 times faster than 'query-json 'keys' benchmarks/big.json'

### Length
Query: length
File: big.json

Benchmark 1: query-json 'length' benchmarks/big.json
  Time (mean ± σ):       7.8 ms ±   0.6 ms    [User: 6.0 ms, System: 1.9 ms]
  Range (min … max):     6.4 ms …   9.2 ms    394 runs
 
Benchmark 2: jq 'length' benchmarks/big.json
  Time (mean ± σ):      10.9 ms ±   3.2 ms    [User: 8.5 ms, System: 2.4 ms]
  Range (min … max):     8.6 ms …  45.6 ms    266 runs
 
  Warning: Statistical outliers were detected. Consider re-running this benchmark on a quiet PC without any interferences from other programs. It might help to use the '--warmup' or '--prepare' options.
 
Summary
  'query-json 'length' benchmarks/big.json' ran
    1.39 ± 0.43 times faster than 'jq 'length' benchmarks/big.json'

### First element
Query: .[0]
File: big.json

Benchmark 1: query-json '.[0]' benchmarks/big.json
  Time (mean ± σ):       7.3 ms ±   0.6 ms    [User: 5.9 ms, System: 1.5 ms]
  Range (min … max):     6.4 ms …   9.5 ms    379 runs
 
Benchmark 2: jq '.[0]' benchmarks/big.json
  Time (mean ± σ):       9.4 ms ±   0.8 ms    [User: 7.9 ms, System: 1.5 ms]
  Range (min … max):     8.6 ms …  19.0 ms    316 runs
 
  Warning: Statistical outliers were detected. Consider re-running this benchmark on a quiet PC without any interferences from other programs. It might help to use the '--warmup' or '--prepare' options.
 
Summary
  'query-json '.[0]' benchmarks/big.json' ran
    1.28 ± 0.15 times faster than 'jq '.[0]' benchmarks/big.json'

### Filter and map
Query: filter(.base."Attack" > 100) | map(.name.english)
File: big.json

Benchmark 1: query-json 'filter(.base."Attack" > 100) | map(.name.english)' benchmarks/big.json
  Time (mean ± σ):       8.2 ms ±   0.7 ms    [User: 6.3 ms, System: 2.0 ms]
  Range (min … max):     7.1 ms …  11.2 ms    356 runs
 
Benchmark 2: jq 'map(select(.base.Attack > 100)) | map(.name.english)' benchmarks/big.json
  Time (mean ± σ):      10.2 ms ±   0.7 ms    [User: 8.7 ms, System: 1.5 ms]
  Range (min … max):     9.3 ms …  14.4 ms    279 runs
 
Summary
  'query-json 'filter(.base."Attack" > 100) | map(.name.english)' benchmarks/big.json' ran
    1.24 ± 0.14 times faster than 'jq 'map(select(.base.Attack > 100)) | map(.name.english)' benchmarks/big.json'

===================================
Huge File Tests (97MB)
===================================

### Keys
Query: keys
File: huge.json

Benchmark 1: query-json 'keys' benchmarks/huge.json
  Time (mean ± σ):      1.156 s ±  0.012 s    [User: 1.068 s, System: 0.087 s]
  Range (min … max):    1.126 s …  1.172 s    10 runs
 
Benchmark 2: jq 'keys' benchmarks/huge.json
  Time (mean ± σ):      1.154 s ±  0.017 s    [User: 1.028 s, System: 0.125 s]
  Range (min … max):    1.127 s …  1.172 s    10 runs
 
Summary
  'jq 'keys' benchmarks/huge.json' ran
    1.00 ± 0.02 times faster than 'query-json 'keys' benchmarks/huge.json'

### Identity (streaming)
Query: .
File: huge.json

Benchmark 1: query-json '.' benchmarks/huge.json
  Time (mean ± σ):      4.133 s ±  0.030 s    [User: 3.663 s, System: 0.468 s]
  Range (min … max):    4.083 s …  4.172 s    10 runs
 
Benchmark 2: jq '.' benchmarks/huge.json
  Time (mean ± σ):      2.737 s ±  0.019 s    [User: 2.601 s, System: 0.136 s]
  Range (min … max):    2.707 s …  2.764 s    10 runs
 
Summary
  'jq '.' benchmarks/huge.json' ran
    1.51 ± 0.02 times faster than 'query-json '.' benchmarks/huge.json'

===================================
Stdin Piping Tests (575KB)
===================================

### Pipe JSON to stdin
Query: .
File: big.json

Benchmark 1: cat benchmarks/big.json | query-json '.'
  Time (mean ± σ):      29.1 ms ±   1.3 ms    [User: 24.4 ms, System: 5.8 ms]
  Range (min … max):    25.8 ms …  33.4 ms    95 runs
 
Benchmark 2: cat benchmarks/big.json | jq '.'
  Time (mean ± σ):      16.9 ms ±   0.5 ms    [User: 15.8 ms, System: 2.3 ms]
  Range (min … max):    15.9 ms …  21.2 ms    170 runs
 
  Warning: Statistical outliers were detected. Consider re-running this benchmark on a quiet PC without any interferences from other programs. It might help to use the '--warmup' or '--prepare' options.
 
Summary
  'cat benchmarks/big.json | jq '.'' ran
    1.72 ± 0.09 times faster than 'cat benchmarks/big.json | query-json '.''

===================================
Benchmark Complete!
===================================
