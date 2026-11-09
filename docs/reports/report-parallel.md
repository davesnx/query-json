===================================
query-json performance benchmarks
===================================

query-json version: 0.6.1
jq version: jq-1.7
Date: Mon Dec 15 09:09:21 PM GMT 2025

===================================
Small File Tests (1.3KB)
===================================

### Identity
Query: .
File: small.json

[1mBenchmark [0m[1m1[0m: query-json '.' benchmarks/small.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m  2.2 ms[0m ± [32m  0.3 ms[0m    [User: [34m1.6 ms[0m, System: [34m1.0 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m  1.3 ms[0m … [35m  3.3 ms[0m    [2m1016 runs[0m
 
  [33mWarning[0m: Command took less than 5 ms to complete. Note that the results might be inaccurate because hyperfine can not calibrate the shell startup time much more precise than this limit. You can try to use the `-N`/`--shell=none` option to disable the shell completely.
 
[1mBenchmark [0m[1m2[0m: jq '.' benchmarks/small.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m  1.7 ms[0m ± [32m  0.2 ms[0m    [User: [34m1.4 ms[0m, System: [34m0.3 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m  1.3 ms[0m … [35m  3.0 ms[0m    [2m1468 runs[0m
 
  [33mWarning[0m: Command took less than 5 ms to complete. Note that the results might be inaccurate because hyperfine can not calibrate the shell startup time much more precise than this limit. You can try to use the `-N`/`--shell=none` option to disable the shell completely.
 
[1mSummary[0m
  '[36mjq '.' benchmarks/small.json[0m' ran
[1;32m    1.34[0m ± [32m0.24[0m times faster than '[35mquery-json '.' benchmarks/small.json[0m'

### Select field
Query: .first.id
File: small.json

[1mBenchmark [0m[1m1[0m: query-json '.first.id' benchmarks/small.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m  2.2 ms[0m ± [32m  0.2 ms[0m    [User: [34m1.5 ms[0m, System: [34m1.0 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m  1.4 ms[0m … [35m  3.0 ms[0m    [2m1131 runs[0m
 
  [33mWarning[0m: Command took less than 5 ms to complete. Note that the results might be inaccurate because hyperfine can not calibrate the shell startup time much more precise than this limit. You can try to use the `-N`/`--shell=none` option to disable the shell completely.
 
[1mBenchmark [0m[1m2[0m: jq '.first.id' benchmarks/small.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m  1.5 ms[0m ± [32m  0.2 ms[0m    [User: [34m1.3 ms[0m, System: [34m0.3 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m  1.1 ms[0m … [35m  6.0 ms[0m    [2m1333 runs[0m
 
  [33mWarning[0m: Command took less than 5 ms to complete. Note that the results might be inaccurate because hyperfine can not calibrate the shell startup time much more precise than this limit. You can try to use the `-N`/`--shell=none` option to disable the shell completely.
  [33mWarning[0m: Statistical outliers were detected. Consider re-running this benchmark on a quiet PC without any interferences from other programs. It might help to use the '--warmup' or '--prepare' options.
 
[1mSummary[0m
  '[36mjq '.first.id' benchmarks/small.json[0m' ran
[1;32m    1.44[0m ± [32m0.27[0m times faster than '[35mquery-json '.first.id' benchmarks/small.json[0m'

### Nested access with map
Query: .second.store.books | map(.price + 10)
File: small.json

[1mBenchmark [0m[1m1[0m: query-json '.second.store.books | map(.price + 10)' benchmarks/small.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m  1.9 ms[0m ± [32m  0.2 ms[0m    [User: [34m1.5 ms[0m, System: [34m0.8 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m  1.2 ms[0m … [35m  3.4 ms[0m    [2m1137 runs[0m
 
  [33mWarning[0m: Command took less than 5 ms to complete. Note that the results might be inaccurate because hyperfine can not calibrate the shell startup time much more precise than this limit. You can try to use the `-N`/`--shell=none` option to disable the shell completely.
  [33mWarning[0m: Statistical outliers were detected. Consider re-running this benchmark on a quiet PC without any interferences from other programs. It might help to use the '--warmup' or '--prepare' options.
 
[1mBenchmark [0m[1m2[0m: jq '.second.store.books | map(.price + 10)' benchmarks/small.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m  1.6 ms[0m ± [32m  0.3 ms[0m    [User: [34m1.4 ms[0m, System: [34m0.3 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m  1.2 ms[0m … [35m  5.4 ms[0m    [2m1273 runs[0m
 
  [33mWarning[0m: Command took less than 5 ms to complete. Note that the results might be inaccurate because hyperfine can not calibrate the shell startup time much more precise than this limit. You can try to use the `-N`/`--shell=none` option to disable the shell completely.
  [33mWarning[0m: Statistical outliers were detected. Consider re-running this benchmark on a quiet PC without any interferences from other programs. It might help to use the '--warmup' or '--prepare' options.
 
[1mSummary[0m
  '[36mjq '.second.store.books | map(.price + 10)' benchmarks/small.json[0m' ran
[1;32m    1.18[0m ± [32m0.26[0m times faster than '[35mquery-json '.second.store.books | map(.price + 10)' benchmarks/small.json[0m'

===================================
Medium File Tests (104KB)
===================================

### Identity
Query: .
File: medium.json

[1mBenchmark [0m[1m1[0m: query-json '.' benchmarks/medium.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m 10.4 ms[0m ± [32m  0.8 ms[0m    [User: [34m6.5 ms[0m, System: [34m4.3 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m  9.3 ms[0m … [35m 14.1 ms[0m    [2m277 runs[0m
 
[1mBenchmark [0m[1m2[0m: jq '.' benchmarks/medium.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m  5.6 ms[0m ± [32m  0.3 ms[0m    [User: [34m4.6 ms[0m, System: [34m1.1 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m  5.0 ms[0m … [35m  6.7 ms[0m    [2m437 runs[0m
 
  [33mWarning[0m: Command took less than 5 ms to complete. Note that the results might be inaccurate because hyperfine can not calibrate the shell startup time much more precise than this limit. You can try to use the `-N`/`--shell=none` option to disable the shell completely.
 
[1mSummary[0m
  '[36mjq '.' benchmarks/medium.json[0m' ran
[1;32m    1.86[0m ± [32m0.17[0m times faster than '[35mquery-json '.' benchmarks/medium.json[0m'

### Map identity
Query: map(.)
File: medium.json

[1mBenchmark [0m[1m1[0m: query-json 'map(.)' benchmarks/medium.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m 11.1 ms[0m ± [32m  0.7 ms[0m    [User: [34m7.2 ms[0m, System: [34m4.3 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m  9.7 ms[0m … [35m 13.6 ms[0m    [2m245 runs[0m
 
[1mBenchmark [0m[1m2[0m: jq 'map(.)' benchmarks/medium.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m  6.0 ms[0m ± [32m  0.3 ms[0m    [User: [34m5.0 ms[0m, System: [34m1.1 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m  5.3 ms[0m … [35m  7.0 ms[0m    [2m440 runs[0m
 
[1mSummary[0m
  '[36mjq 'map(.)' benchmarks/medium.json[0m' ran
[1;32m    1.85[0m ± [32m0.16[0m times faster than '[35mquery-json 'map(.)' benchmarks/medium.json[0m'

### Map with field access
Query: map(.time)
File: medium.json

[1mBenchmark [0m[1m1[0m: query-json 'map(.time)' benchmarks/medium.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m  6.8 ms[0m ± [32m  0.4 ms[0m    [User: [34m4.1 ms[0m, System: [34m3.0 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m  5.9 ms[0m … [35m  8.1 ms[0m    [2m379 runs[0m
 
[1mBenchmark [0m[1m2[0m: jq 'map(.time)' benchmarks/medium.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m  5.2 ms[0m ± [32m  0.3 ms[0m    [User: [34m4.0 ms[0m, System: [34m1.2 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m  4.6 ms[0m … [35m  7.3 ms[0m    [2m541 runs[0m
 
  [33mWarning[0m: Command took less than 5 ms to complete. Note that the results might be inaccurate because hyperfine can not calibrate the shell startup time much more precise than this limit. You can try to use the `-N`/`--shell=none` option to disable the shell completely.
 
[1mSummary[0m
  '[36mjq 'map(.time)' benchmarks/medium.json[0m' ran
[1;32m    1.31[0m ± [32m0.10[0m times faster than '[35mquery-json 'map(.time)' benchmarks/medium.json[0m'

### Length
Query: length
File: medium.json

[1mBenchmark [0m[1m1[0m: query-json 'length' benchmarks/medium.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m  4.4 ms[0m ± [32m  0.7 ms[0m    [User: [34m2.8 ms[0m, System: [34m2.0 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m  3.4 ms[0m … [35m  7.6 ms[0m    [2m542 runs[0m
 
  [33mWarning[0m: Command took less than 5 ms to complete. Note that the results might be inaccurate because hyperfine can not calibrate the shell startup time much more precise than this limit. You can try to use the `-N`/`--shell=none` option to disable the shell completely.
 
[1mBenchmark [0m[1m2[0m: jq 'length' benchmarks/medium.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m  4.1 ms[0m ± [32m  0.6 ms[0m    [User: [34m2.9 ms[0m, System: [34m1.2 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m  3.2 ms[0m … [35m  6.8 ms[0m    [2m400 runs[0m
 
  [33mWarning[0m: Command took less than 5 ms to complete. Note that the results might be inaccurate because hyperfine can not calibrate the shell startup time much more precise than this limit. You can try to use the `-N`/`--shell=none` option to disable the shell completely.
 
[1mSummary[0m
  '[36mjq 'length' benchmarks/medium.json[0m' ran
[1;32m    1.09[0m ± [32m0.23[0m times faster than '[35mquery-json 'length' benchmarks/medium.json[0m'

===================================
Big File Tests (575KB)
===================================

### Identity
Query: .
File: big.json

[1mBenchmark [0m[1m1[0m: query-json '.' benchmarks/big.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m 32.7 ms[0m ± [32m  1.6 ms[0m    [User: [34m26.0 ms[0m, System: [34m7.1 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m 30.1 ms[0m … [35m 38.9 ms[0m    [2m93 runs[0m
 
[1mBenchmark [0m[1m2[0m: jq '.' benchmarks/big.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m 16.7 ms[0m ± [32m  0.5 ms[0m    [User: [34m14.7 ms[0m, System: [34m2.0 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m 15.8 ms[0m … [35m 19.6 ms[0m    [2m167 runs[0m
 
[1mSummary[0m
  '[36mjq '.' benchmarks/big.json[0m' ran
[1;32m    1.96[0m ± [32m0.11[0m times faster than '[35mquery-json '.' benchmarks/big.json[0m'

### Map identity
Query: map(.)
File: big.json

[1mBenchmark [0m[1m1[0m: query-json 'map(.)' benchmarks/big.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m 32.4 ms[0m ± [32m  1.1 ms[0m    [User: [34m25.2 ms[0m, System: [34m7.5 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m 30.5 ms[0m … [35m 36.5 ms[0m    [2m94 runs[0m
 
[1mBenchmark [0m[1m2[0m: jq 'map(.)' benchmarks/big.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m 16.7 ms[0m ± [32m  0.4 ms[0m    [User: [34m15.1 ms[0m, System: [34m1.7 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m 15.8 ms[0m … [35m 17.7 ms[0m    [2m169 runs[0m
 
[1mSummary[0m
  '[36mjq 'map(.)' benchmarks/big.json[0m' ran
[1;32m    1.94[0m ± [32m0.08[0m times faster than '[35mquery-json 'map(.)' benchmarks/big.json[0m'

### Keys
Query: keys
File: big.json

[1mBenchmark [0m[1m1[0m: query-json 'keys' benchmarks/big.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m 18.1 ms[0m ± [32m  0.9 ms[0m    [User: [34m12.6 ms[0m, System: [34m5.7 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m 16.6 ms[0m … [35m 20.9 ms[0m    [2m171 runs[0m
 
[1mBenchmark [0m[1m2[0m: jq 'keys' benchmarks/big.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m  9.8 ms[0m ± [32m  0.4 ms[0m    [User: [34m8.3 ms[0m, System: [34m1.6 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m  8.8 ms[0m … [35m 11.9 ms[0m    [2m268 runs[0m
 
[1mSummary[0m
  '[36mjq 'keys' benchmarks/big.json[0m' ran
[1;32m    1.85[0m ± [32m0.12[0m times faster than '[35mquery-json 'keys' benchmarks/big.json[0m'

### Length
Query: length
File: big.json

[1mBenchmark [0m[1m1[0m: query-json 'length' benchmarks/big.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m 10.6 ms[0m ± [32m  0.5 ms[0m    [User: [34m8.2 ms[0m, System: [34m2.7 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m  9.9 ms[0m … [35m 12.7 ms[0m    [2m271 runs[0m
 
[1mBenchmark [0m[1m2[0m: jq 'length' benchmarks/big.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m  9.5 ms[0m ± [32m  0.5 ms[0m    [User: [34m8.0 ms[0m, System: [34m1.5 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m  8.7 ms[0m … [35m 11.7 ms[0m    [2m299 runs[0m
 
[1mSummary[0m
  '[36mjq 'length' benchmarks/big.json[0m' ran
[1;32m    1.12[0m ± [32m0.08[0m times faster than '[35mquery-json 'length' benchmarks/big.json[0m'

### First element
Query: .[0]
File: big.json

[1mBenchmark [0m[1m1[0m: query-json '.[0]' benchmarks/big.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m 10.4 ms[0m ± [32m  0.5 ms[0m    [User: [34m8.2 ms[0m, System: [34m2.5 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m  9.3 ms[0m … [35m 12.4 ms[0m    [2m265 runs[0m
 
[1mBenchmark [0m[1m2[0m: jq '.[0]' benchmarks/big.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m  9.4 ms[0m ± [32m  0.5 ms[0m    [User: [34m7.8 ms[0m, System: [34m1.6 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m  8.5 ms[0m … [35m 13.6 ms[0m    [2m295 runs[0m
 
  [33mWarning[0m: Statistical outliers were detected. Consider re-running this benchmark on a quiet PC without any interferences from other programs. It might help to use the '--warmup' or '--prepare' options.
 
[1mSummary[0m
  '[36mjq '.[0]' benchmarks/big.json[0m' ran
[1;32m    1.11[0m ± [32m0.08[0m times faster than '[35mquery-json '.[0]' benchmarks/big.json[0m'

### Filter and map
Query: filter(.base."Attack" > 100) | map(.name.english)
File: big.json

[1mBenchmark [0m[1m1[0m: query-json 'filter(.base."Attack" > 100) | map(.name.english)' benchmarks/big.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m 12.4 ms[0m ± [32m  0.6 ms[0m    [User: [34m9.1 ms[0m, System: [34m3.7 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m 10.5 ms[0m … [35m 14.6 ms[0m    [2m212 runs[0m
 
[1mBenchmark [0m[1m2[0m: jq 'map(select(.base.Attack > 100)) | map(.name.english)' benchmarks/big.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m 10.5 ms[0m ± [32m  0.6 ms[0m    [User: [34m9.0 ms[0m, System: [34m1.6 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m  9.4 ms[0m … [35m 14.4 ms[0m    [2m266 runs[0m
 
[1mSummary[0m
  '[36mjq 'map(select(.base.Attack > 100)) | map(.name.english)' benchmarks/big.json[0m' ran
[1;32m    1.18[0m ± [32m0.09[0m times faster than '[35mquery-json 'filter(.base."Attack" > 100) | map(.name.english)' benchmarks/big.json[0m'

===================================
Huge File Tests (97MB)
===================================

### Keys
Query: keys
File: huge.json

[1mBenchmark [0m[1m1[0m: query-json 'keys' benchmarks/huge.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m 1.311 s[0m ± [32m 0.038 s[0m    [User: [34m1.184 s[0m, System: [34m0.130 s[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m 1.275 s[0m … [35m 1.403 s[0m    [2m10 runs[0m
 
[1mBenchmark [0m[1m2[0m: jq 'keys' benchmarks/huge.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m 1.156 s[0m ± [32m 0.014 s[0m    [User: [34m1.037 s[0m, System: [34m0.119 s[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m 1.134 s[0m … [35m 1.182 s[0m    [2m10 runs[0m
 
[1mSummary[0m
  '[36mjq 'keys' benchmarks/huge.json[0m' ran
[1;32m    1.13[0m ± [32m0.04[0m times faster than '[35mquery-json 'keys' benchmarks/huge.json[0m'

### Identity (streaming)
Query: .
File: huge.json

[1mBenchmark [0m[1m1[0m: query-json '.' benchmarks/huge.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m 4.444 s[0m ± [32m 0.182 s[0m    [User: [34m3.883 s[0m, System: [34m0.563 s[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m 4.245 s[0m … [35m 4.757 s[0m    [2m10 runs[0m
 
[1mBenchmark [0m[1m2[0m: jq '.' benchmarks/huge.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m 2.724 s[0m ± [32m 0.015 s[0m    [User: [34m2.585 s[0m, System: [34m0.138 s[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m 2.699 s[0m … [35m 2.749 s[0m    [2m10 runs[0m
 
[1mSummary[0m
  '[36mjq '.' benchmarks/huge.json[0m' ran
[1;32m    1.63[0m ± [32m0.07[0m times faster than '[35mquery-json '.' benchmarks/huge.json[0m'

===================================
Stdin Piping Tests (575KB)
===================================

### Pipe JSON to stdin
Query: .
File: big.json

[1mBenchmark [0m[1m1[0m: cat benchmarks/big.json | query-json '.'
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m 32.1 ms[0m ± [32m  1.2 ms[0m    [User: [34m26.9 ms[0m, System: [34m6.6 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m 30.4 ms[0m … [35m 37.6 ms[0m    [2m91 runs[0m
 
[1mBenchmark [0m[1m2[0m: cat benchmarks/big.json | jq '.'
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m 16.6 ms[0m ± [32m  0.5 ms[0m    [User: [34m15.6 ms[0m, System: [34m2.1 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m 15.7 ms[0m … [35m 20.6 ms[0m    [2m170 runs[0m
 
  [33mWarning[0m: Statistical outliers were detected. Consider re-running this benchmark on a quiet PC without any interferences from other programs. It might help to use the '--warmup' or '--prepare' options.
 
[1mSummary[0m
  '[36mcat benchmarks/big.json | jq '.'[0m' ran
[1;32m    1.94[0m ± [32m0.09[0m times faster than '[35mcat benchmarks/big.json | query-json '.'[0m'

===================================
Benchmark Complete!
===================================
