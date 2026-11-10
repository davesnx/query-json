===================================
query-json performance benchmarks
===================================

query-json version: 0.6.1
jq version: jq-1.7
Date: Wed Dec 17 09:43:26 PM GMT 2025

===================================
Small File Tests (1.3KB)
===================================

### Identity
Query: .
File: small.json

[1mBenchmark [0m[1m1[0m: query-json '.' benchmarks/small.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m  1.3 ms[0m ± [32m  0.2 ms[0m    [User: [34m1.1 ms[0m, System: [34m0.3 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m  0.7 ms[0m … [35m  2.4 ms[0m    [2m1208 runs[0m
 
  [33mWarning[0m: Command took less than 5 ms to complete. Note that the results might be inaccurate because hyperfine can not calibrate the shell startup time much more precise than this limit. You can try to use the `-N`/`--shell=none` option to disable the shell completely.
 
[1mBenchmark [0m[1m2[0m: jq '.' benchmarks/small.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m  1.6 ms[0m ± [32m  0.2 ms[0m    [User: [34m1.3 ms[0m, System: [34m0.3 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m  1.2 ms[0m … [35m  2.8 ms[0m    [2m1338 runs[0m
 
  [33mWarning[0m: Command took less than 5 ms to complete. Note that the results might be inaccurate because hyperfine can not calibrate the shell startup time much more precise than this limit. You can try to use the `-N`/`--shell=none` option to disable the shell completely.
 
[1mSummary[0m
  '[36mquery-json '.' benchmarks/small.json[0m' ran
[1;32m    1.19[0m ± [32m0.27[0m times faster than '[35mjq '.' benchmarks/small.json[0m'

### Select field
Query: .first.id
File: small.json

[1mBenchmark [0m[1m1[0m: query-json '.first.id' benchmarks/small.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m  1.4 ms[0m ± [32m  0.2 ms[0m    [User: [34m1.1 ms[0m, System: [34m0.4 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m  0.9 ms[0m … [35m  2.5 ms[0m    [2m1303 runs[0m
 
  [33mWarning[0m: Command took less than 5 ms to complete. Note that the results might be inaccurate because hyperfine can not calibrate the shell startup time much more precise than this limit. You can try to use the `-N`/`--shell=none` option to disable the shell completely.
 
[1mBenchmark [0m[1m2[0m: jq '.first.id' benchmarks/small.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m  1.6 ms[0m ± [32m  0.2 ms[0m    [User: [34m1.3 ms[0m, System: [34m0.3 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m  1.2 ms[0m … [35m  2.8 ms[0m    [2m1305 runs[0m
 
  [33mWarning[0m: Command took less than 5 ms to complete. Note that the results might be inaccurate because hyperfine can not calibrate the shell startup time much more precise than this limit. You can try to use the `-N`/`--shell=none` option to disable the shell completely.
 
[1mSummary[0m
  '[36mquery-json '.first.id' benchmarks/small.json[0m' ran
[1;32m    1.11[0m ± [32m0.20[0m times faster than '[35mjq '.first.id' benchmarks/small.json[0m'

### Nested access with map
Query: .second.store.books | map(.price + 10)
File: small.json

[1mBenchmark [0m[1m1[0m: query-json '.second.store.books | map(.price + 10)' benchmarks/small.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m  1.4 ms[0m ± [32m  0.2 ms[0m    [User: [34m1.1 ms[0m, System: [34m0.4 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m  0.9 ms[0m … [35m  2.6 ms[0m    [2m1373 runs[0m
 
  [33mWarning[0m: Command took less than 5 ms to complete. Note that the results might be inaccurate because hyperfine can not calibrate the shell startup time much more precise than this limit. You can try to use the `-N`/`--shell=none` option to disable the shell completely.
 
[1mBenchmark [0m[1m2[0m: jq '.second.store.books | map(.price + 10)' benchmarks/small.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m  1.7 ms[0m ± [32m  0.2 ms[0m    [User: [34m1.4 ms[0m, System: [34m0.3 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m  1.2 ms[0m … [35m  2.9 ms[0m    [2m1262 runs[0m
 
  [33mWarning[0m: Command took less than 5 ms to complete. Note that the results might be inaccurate because hyperfine can not calibrate the shell startup time much more precise than this limit. You can try to use the `-N`/`--shell=none` option to disable the shell completely.
 
[1mSummary[0m
  '[36mquery-json '.second.store.books | map(.price + 10)' benchmarks/small.json[0m' ran
[1;32m    1.15[0m ± [32m0.24[0m times faster than '[35mjq '.second.store.books | map(.price + 10)' benchmarks/small.json[0m'

===================================
Medium File Tests (104KB)
===================================

### Identity
Query: .
File: medium.json

[1mBenchmark [0m[1m1[0m: query-json '.' benchmarks/medium.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m  3.4 ms[0m ± [32m  0.3 ms[0m    [User: [34m2.4 ms[0m, System: [34m1.1 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m  2.7 ms[0m … [35m  4.8 ms[0m    [2m758 runs[0m
 
  [33mWarning[0m: Command took less than 5 ms to complete. Note that the results might be inaccurate because hyperfine can not calibrate the shell startup time much more precise than this limit. You can try to use the `-N`/`--shell=none` option to disable the shell completely.
 
[1mBenchmark [0m[1m2[0m: jq '.' benchmarks/medium.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m  5.6 ms[0m ± [32m  0.3 ms[0m    [User: [34m4.5 ms[0m, System: [34m1.2 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m  5.0 ms[0m … [35m  7.2 ms[0m    [2m475 runs[0m
 
  [33mWarning[0m: Command took less than 5 ms to complete. Note that the results might be inaccurate because hyperfine can not calibrate the shell startup time much more precise than this limit. You can try to use the `-N`/`--shell=none` option to disable the shell completely.
 
[1mSummary[0m
  '[36mquery-json '.' benchmarks/medium.json[0m' ran
[1;32m    1.63[0m ± [32m0.18[0m times faster than '[35mjq '.' benchmarks/medium.json[0m'

### Map identity
Query: map(.)
File: medium.json

[1mBenchmark [0m[1m1[0m: query-json 'map(.)' benchmarks/medium.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m  3.9 ms[0m ± [32m  0.3 ms[0m    [User: [34m2.5 ms[0m, System: [34m1.5 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m  3.2 ms[0m … [35m  6.7 ms[0m    [2m562 runs[0m
 
  [33mWarning[0m: Command took less than 5 ms to complete. Note that the results might be inaccurate because hyperfine can not calibrate the shell startup time much more precise than this limit. You can try to use the `-N`/`--shell=none` option to disable the shell completely.
 
[1mBenchmark [0m[1m2[0m: jq 'map(.)' benchmarks/medium.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m  6.0 ms[0m ± [32m  0.4 ms[0m    [User: [34m5.0 ms[0m, System: [34m1.0 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m  5.4 ms[0m … [35m  8.6 ms[0m    [2m461 runs[0m
 
[1mSummary[0m
  '[36mquery-json 'map(.)' benchmarks/medium.json[0m' ran
[1;32m    1.53[0m ± [32m0.17[0m times faster than '[35mjq 'map(.)' benchmarks/medium.json[0m'

### Map with field access
Query: map(.time)
File: medium.json

[1mBenchmark [0m[1m1[0m: query-json 'map(.time)' benchmarks/medium.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m  3.6 ms[0m ± [32m  0.3 ms[0m    [User: [34m2.3 ms[0m, System: [34m1.3 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m  2.8 ms[0m … [35m  5.5 ms[0m    [2m697 runs[0m
 
  [33mWarning[0m: Command took less than 5 ms to complete. Note that the results might be inaccurate because hyperfine can not calibrate the shell startup time much more precise than this limit. You can try to use the `-N`/`--shell=none` option to disable the shell completely.
 
[1mBenchmark [0m[1m2[0m: jq 'map(.time)' benchmarks/medium.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m  5.3 ms[0m ± [32m  0.4 ms[0m    [User: [34m4.3 ms[0m, System: [34m1.0 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m  4.6 ms[0m … [35m  7.3 ms[0m    [2m524 runs[0m
 
  [33mWarning[0m: Command took less than 5 ms to complete. Note that the results might be inaccurate because hyperfine can not calibrate the shell startup time much more precise than this limit. You can try to use the `-N`/`--shell=none` option to disable the shell completely.
 
[1mSummary[0m
  '[36mquery-json 'map(.time)' benchmarks/medium.json[0m' ran
[1;32m    1.47[0m ± [32m0.17[0m times faster than '[35mjq 'map(.time)' benchmarks/medium.json[0m'

### Length
Query: length
File: medium.json

[1mBenchmark [0m[1m1[0m: query-json 'length' benchmarks/medium.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m  2.7 ms[0m ± [32m  0.3 ms[0m    [User: [34m1.9 ms[0m, System: [34m0.8 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m  2.0 ms[0m … [35m  4.4 ms[0m    [2m936 runs[0m
 
  [33mWarning[0m: Command took less than 5 ms to complete. Note that the results might be inaccurate because hyperfine can not calibrate the shell startup time much more precise than this limit. You can try to use the `-N`/`--shell=none` option to disable the shell completely.
 
[1mBenchmark [0m[1m2[0m: jq 'length' benchmarks/medium.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m  3.9 ms[0m ± [32m  0.3 ms[0m    [User: [34m3.0 ms[0m, System: [34m1.0 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m  3.3 ms[0m … [35m  5.4 ms[0m    [2m676 runs[0m
 
  [33mWarning[0m: Command took less than 5 ms to complete. Note that the results might be inaccurate because hyperfine can not calibrate the shell startup time much more precise than this limit. You can try to use the `-N`/`--shell=none` option to disable the shell completely.
 
[1mSummary[0m
  '[36mquery-json 'length' benchmarks/medium.json[0m' ran
[1;32m    1.46[0m ± [32m0.19[0m times faster than '[35mjq 'length' benchmarks/medium.json[0m'

===================================
Big File Tests (575KB)
===================================

### Identity
Query: .
File: big.json

[1mBenchmark [0m[1m1[0m: query-json '.' benchmarks/big.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m 12.7 ms[0m ± [32m  0.8 ms[0m    [User: [34m9.2 ms[0m, System: [34m3.5 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m 11.1 ms[0m … [35m 18.7 ms[0m    [2m220 runs[0m
 
  [33mWarning[0m: Statistical outliers were detected. Consider re-running this benchmark on a quiet PC without any interferences from other programs. It might help to use the '--warmup' or '--prepare' options.
 
[1mBenchmark [0m[1m2[0m: jq '.' benchmarks/big.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m 16.6 ms[0m ± [32m  0.4 ms[0m    [User: [34m15.2 ms[0m, System: [34m1.4 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m 15.7 ms[0m … [35m 17.9 ms[0m    [2m176 runs[0m
 
[1mSummary[0m
  '[36mquery-json '.' benchmarks/big.json[0m' ran
[1;32m    1.31[0m ± [32m0.09[0m times faster than '[35mjq '.' benchmarks/big.json[0m'

### Map identity
Query: map(.)
File: big.json

[1mBenchmark [0m[1m1[0m: query-json 'map(.)' benchmarks/big.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m 12.7 ms[0m ± [32m  0.7 ms[0m    [User: [34m9.8 ms[0m, System: [34m2.9 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m 11.1 ms[0m … [35m 15.5 ms[0m    [2m217 runs[0m
 
[1mBenchmark [0m[1m2[0m: jq 'map(.)' benchmarks/big.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m 16.7 ms[0m ± [32m  0.4 ms[0m    [User: [34m15.1 ms[0m, System: [34m1.7 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m 15.8 ms[0m … [35m 17.8 ms[0m    [2m177 runs[0m
 
[1mSummary[0m
  '[36mquery-json 'map(.)' benchmarks/big.json[0m' ran
[1;32m    1.31[0m ± [32m0.08[0m times faster than '[35mjq 'map(.)' benchmarks/big.json[0m'

### Keys
Query: keys
File: big.json

[1mBenchmark [0m[1m1[0m: query-json 'keys' benchmarks/big.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m 13.7 ms[0m ± [32m  0.8 ms[0m    [User: [34m9.8 ms[0m, System: [34m3.9 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m 11.7 ms[0m … [35m 18.2 ms[0m    [2m212 runs[0m
 
[1mBenchmark [0m[1m2[0m: jq 'keys' benchmarks/big.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m  9.5 ms[0m ± [32m  0.4 ms[0m    [User: [34m8.2 ms[0m, System: [34m1.3 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m  8.8 ms[0m … [35m 11.1 ms[0m    [2m299 runs[0m
 
[1mSummary[0m
  '[36mjq 'keys' benchmarks/big.json[0m' ran
[1;32m    1.44[0m ± [32m0.10[0m times faster than '[35mquery-json 'keys' benchmarks/big.json[0m'

### Length
Query: length
File: big.json

[1mBenchmark [0m[1m1[0m: query-json 'length' benchmarks/big.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m  7.0 ms[0m ± [32m  0.4 ms[0m    [User: [34m5.7 ms[0m, System: [34m1.4 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m  6.3 ms[0m … [35m  8.7 ms[0m    [2m390 runs[0m
 
[1mBenchmark [0m[1m2[0m: jq 'length' benchmarks/big.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m  9.4 ms[0m ± [32m  0.5 ms[0m    [User: [34m8.0 ms[0m, System: [34m1.5 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m  8.5 ms[0m … [35m 10.8 ms[0m    [2m305 runs[0m
 
[1mSummary[0m
  '[36mquery-json 'length' benchmarks/big.json[0m' ran
[1;32m    1.34[0m ± [32m0.09[0m times faster than '[35mjq 'length' benchmarks/big.json[0m'

### First element
Query: .[0]
File: big.json

[1mBenchmark [0m[1m1[0m: query-json '.[0]' benchmarks/big.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m  7.2 ms[0m ± [32m  0.4 ms[0m    [User: [34m5.8 ms[0m, System: [34m1.5 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m  6.4 ms[0m … [35m  9.1 ms[0m    [2m351 runs[0m
 
[1mBenchmark [0m[1m2[0m: jq '.[0]' benchmarks/big.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m  9.6 ms[0m ± [32m  0.5 ms[0m    [User: [34m8.2 ms[0m, System: [34m1.5 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m  8.7 ms[0m … [35m 13.1 ms[0m    [2m292 runs[0m
 
[1mSummary[0m
  '[36mquery-json '.[0]' benchmarks/big.json[0m' ran
[1;32m    1.33[0m ± [32m0.10[0m times faster than '[35mjq '.[0]' benchmarks/big.json[0m'

### Filter and map
Query: filter(.base."Attack" > 100) | map(.name.english)
File: big.json

[1mBenchmark [0m[1m1[0m: query-json 'filter(.base."Attack" > 100) | map(.name.english)' benchmarks/big.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m  8.3 ms[0m ± [32m  0.5 ms[0m    [User: [34m6.4 ms[0m, System: [34m2.0 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m  7.2 ms[0m … [35m  9.8 ms[0m    [2m298 runs[0m
 
[1mBenchmark [0m[1m2[0m: jq 'map(select(.base.Attack > 100)) | map(.name.english)' benchmarks/big.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m 10.4 ms[0m ± [32m  0.6 ms[0m    [User: [34m9.0 ms[0m, System: [34m1.5 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m  9.5 ms[0m … [35m 13.2 ms[0m    [2m252 runs[0m
 
[1mSummary[0m
  '[36mquery-json 'filter(.base."Attack" > 100) | map(.name.english)' benchmarks/big.json[0m' ran
[1;32m    1.25[0m ± [32m0.10[0m times faster than '[35mjq 'map(select(.base.Attack > 100)) | map(.name.english)' benchmarks/big.json[0m'

===================================
Huge File Tests (97MB)
===================================

### Keys
Query: keys
File: huge.json

[1mBenchmark [0m[1m1[0m: query-json 'keys' benchmarks/huge.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m 1.165 s[0m ± [32m 0.013 s[0m    [User: [34m1.078 s[0m, System: [34m0.087 s[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m 1.145 s[0m … [35m 1.191 s[0m    [2m10 runs[0m
 
[1mBenchmark [0m[1m2[0m: jq 'keys' benchmarks/huge.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m 1.180 s[0m ± [32m 0.040 s[0m    [User: [34m1.047 s[0m, System: [34m0.133 s[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m 1.155 s[0m … [35m 1.291 s[0m    [2m10 runs[0m
 
  [33mWarning[0m: Statistical outliers were detected. Consider re-running this benchmark on a quiet PC without any interferences from other programs. It might help to use the '--warmup' or '--prepare' options.
 
[1mSummary[0m
  '[36mquery-json 'keys' benchmarks/huge.json[0m' ran
[1;32m    1.01[0m ± [32m0.04[0m times faster than '[35mjq 'keys' benchmarks/huge.json[0m'

### Identity (streaming)
Query: .
File: huge.json

[1mBenchmark [0m[1m1[0m: query-json '.' benchmarks/huge.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m 2.016 s[0m ± [32m 0.049 s[0m    [User: [34m1.811 s[0m, System: [34m0.204 s[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m 1.993 s[0m … [35m 2.152 s[0m    [2m10 runs[0m
 
  [33mWarning[0m: Statistical outliers were detected. Consider re-running this benchmark on a quiet PC without any interferences from other programs. It might help to use the '--warmup' or '--prepare' options.
 
[1mBenchmark [0m[1m2[0m: jq '.' benchmarks/huge.json
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m 2.774 s[0m ± [32m 0.091 s[0m    [User: [34m2.602 s[0m, System: [34m0.171 s[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m 2.705 s[0m … [35m 3.003 s[0m    [2m10 runs[0m
 
[1mSummary[0m
  '[36mquery-json '.' benchmarks/huge.json[0m' ran
[1;32m    1.38[0m ± [32m0.06[0m times faster than '[35mjq '.' benchmarks/huge.json[0m'

===================================
Stdin Piping Tests (575KB)
===================================

### Pipe JSON to stdin
Query: .
File: big.json

[1mBenchmark [0m[1m1[0m: cat benchmarks/big.json | query-json '.'
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m 13.7 ms[0m ± [32m  2.9 ms[0m    [User: [34m11.2 ms[0m, System: [34m3.9 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m 11.6 ms[0m … [35m 41.6 ms[0m    [2m206 runs[0m
 
  [33mWarning[0m: Statistical outliers were detected. Consider re-running this benchmark on a quiet PC without any interferences from other programs. It might help to use the '--warmup' or '--prepare' options.
 
[1mBenchmark [0m[1m2[0m: cat benchmarks/big.json | jq '.'
  Time ([1;32mmean[0m ± [32mσ[0m):     [1;32m 17.2 ms[0m ± [32m  1.5 ms[0m    [User: [34m16.3 ms[0m, System: [34m2.1 ms[0m]
  Range ([36mmin[0m … [35mmax[0m):   [36m 16.1 ms[0m … [35m 33.6 ms[0m    [2m169 runs[0m
 
  [33mWarning[0m: Statistical outliers were detected. Consider re-running this benchmark on a quiet PC without any interferences from other programs. It might help to use the '--warmup' or '--prepare' options.
 
[1mSummary[0m
  '[36mcat benchmarks/big.json | query-json '.'[0m' ran
[1;32m    1.25[0m ± [32m0.29[0m times faster than '[35mcat benchmarks/big.json | jq '.'[0m'

===================================
Benchmark Complete!
===================================
