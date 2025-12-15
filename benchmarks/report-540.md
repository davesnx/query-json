# Benchmark Report - OCaml 5.2.0+ox (oxcaml)

**Date:** Mon Dec 15 2025
**query-json version:** 0.6.1
**jq version:** jq-1.7
**OCaml:** 5.2.0+ox (Jane Street oxcaml)

## Summary

| Category | Test | Winner | Speedup |
|----------|------|--------|---------|
| Small (1.3KB) | Identity `.` | query-json | 1.15x |
| Small (1.3KB) | Select field `.first.id` | query-json | 1.18x |
| Small (1.3KB) | Nested + map | query-json | 1.12x |
| Medium (104KB) | Identity `.` | query-json | 1.16x |
| Medium (104KB) | `map(.)` | jq | 1.75x |
| Medium (104KB) | `map(.time)` | query-json | 1.08x |
| Medium (104KB) | `length` | query-json | **1.49x** |
| Big (575KB) | Identity `.` | jq | 1.85x |
| Big (575KB) | `map(.)` | jq | 1.70x |
| Big (575KB) | `keys` | jq | 1.44x |
| Big (575KB) | `length` | query-json | **1.50x** |
| Big (575KB) | First element `.[0]` | query-json | 1.33x |
| Big (575KB) | Filter + map | query-json | 1.21x |
| Huge (97MB) | `keys` | query-json | 1.01x |
| Huge (97MB) | Identity `.` | jq | 1.53x |
| Stdin | Pipe big.json | jq | 1.72x |

## Detailed Results

### Small File Tests (1.3KB)

#### Identity `.`
| Tool | Mean | Min | Max |
|------|------|-----|-----|
| query-json | 1.4 ms ± 0.2 ms | 1.0 ms | 2.6 ms |
| jq | 1.6 ms ± 0.2 ms | 1.2 ms | 2.5 ms |

**Winner: query-json (1.15x faster)**

#### Select field `.first.id`
| Tool | Mean | Min | Max |
|------|------|-----|-----|
| query-json | 1.4 ms ± 0.3 ms | 0.8 ms | 2.9 ms |
| jq | 1.6 ms ± 0.2 ms | 1.2 ms | 3.2 ms |

**Winner: query-json (1.18x faster)**

#### Nested access with map `.second.store.books | map(.price + 10)`
| Tool | Mean | Min | Max |
|------|------|-----|-----|
| query-json | 1.5 ms ± 0.2 ms | 0.8 ms | 2.8 ms |
| jq | 1.7 ms ± 0.2 ms | 1.3 ms | 4.7 ms |

**Winner: query-json (1.12x faster)**

---

### Medium File Tests (104KB)

#### Identity `.`
| Tool | Mean | Min | Max |
|------|------|-----|-----|
| query-json | 9.6 ms ± 0.9 ms | 7.3 ms | 14.1 ms |
| jq | 11.1 ms ± 55.8 ms | 5.1 ms | 1177.7 ms |

**Winner: query-json (1.16x faster)**

#### Map identity `map(.)`
| Tool | Mean | Min | Max |
|------|------|-----|-----|
| query-json | 10.8 ms ± 13.8 ms | 7.5 ms | 233.7 ms |
| jq | 6.2 ms ± 0.4 ms | 5.4 ms | 9.3 ms |

**Winner: jq (1.75x faster)**

#### Map with field access `map(.time)`
| Tool | Mean | Min | Max |
|------|------|-----|-----|
| query-json | 5.0 ms ± 0.4 ms | 4.1 ms | 7.3 ms |
| jq | 5.4 ms ± 0.3 ms | 4.6 ms | 7.8 ms |

**Winner: query-json (1.08x faster)**

#### Length `length`
| Tool | Mean | Min | Max |
|------|------|-----|-----|
| query-json | 2.8 ms ± 0.3 ms | 2.1 ms | 5.5 ms |
| jq | 4.2 ms ± 0.4 ms | 3.3 ms | 6.1 ms |

**Winner: query-json (1.49x faster)**

---

### Big File Tests (575KB)

#### Identity `.`
| Tool | Mean | Min | Max |
|------|------|-----|-----|
| query-json | 31.4 ms ± 2.2 ms | 26.2 ms | 41.6 ms |
| jq | 17.0 ms ± 0.7 ms | 15.7 ms | 20.6 ms |

**Winner: jq (1.85x faster)**

#### Map identity `map(.)`
| Tool | Mean | Min | Max |
|------|------|-----|-----|
| query-json | 29.1 ms ± 1.6 ms | 25.8 ms | 38.8 ms |
| jq | 17.1 ms ± 0.5 ms | 15.9 ms | 20.4 ms |

**Winner: jq (1.70x faster)**

#### Keys `keys`
| Tool | Mean | Min | Max |
|------|------|-----|-----|
| query-json | 14.7 ms ± 0.9 ms | 12.4 ms | 19.1 ms |
| jq | 10.2 ms ± 0.5 ms | 9.0 ms | 11.6 ms |

**Winner: jq (1.44x faster)**

#### Length `length`
| Tool | Mean | Min | Max |
|------|------|-----|-----|
| query-json | 7.4 ms ± 0.3 ms | 6.6 ms | 9.1 ms |
| jq | 11.2 ms ± 9.7 ms | 8.7 ms | 165.9 ms |

**Winner: query-json (1.50x faster)**

#### First element `.[0]`
| Tool | Mean | Min | Max |
|------|------|-----|-----|
| query-json | 7.4 ms ± 0.4 ms | 6.4 ms | 9.1 ms |
| jq | 9.9 ms ± 0.5 ms | 8.9 ms | 13.1 ms |

**Winner: query-json (1.33x faster)**

#### Filter and map `filter(.base."Attack" > 100) | map(.name.english)`
| Tool | Mean | Min | Max |
|------|------|-----|-----|
| query-json | 8.9 ms ± 0.6 ms | 7.5 ms | 11.4 ms |
| jq | 10.8 ms ± 0.7 ms | 9.5 ms | 15.4 ms |

**Winner: query-json (1.21x faster)**

---

### Huge File Tests (97MB)

#### Keys `keys`
| Tool | Mean | Min | Max |
|------|------|-----|-----|
| query-json | 1.164 s ± 0.011 s | 1.149 s | 1.186 s |
| jq | 1.172 s ± 0.011 s | 1.159 s | 1.192 s |

**Winner: query-json (1.01x faster)**

#### Identity `.`
| Tool | Mean | Min | Max |
|------|------|-----|-----|
| query-json | 4.183 s ± 0.074 s | 4.086 s | 4.316 s |
| jq | 2.731 s ± 0.017 s | 2.709 s | 2.768 s |

**Winner: jq (1.53x faster)**

---

### Stdin Piping Tests (575KB)

#### Pipe JSON to stdin `.`
| Tool | Mean | Min | Max |
|------|------|-----|-----|
| query-json | 29.2 ms ± 1.4 ms | 26.2 ms | 34.4 ms |
| jq | 17.0 ms ± 0.5 ms | 16.0 ms | 19.9 ms |

**Winner: jq (1.72x faster)**

---

## Analysis

### Where query-json excels:
- **Simple field access** - Faster parsing and direct field lookup
- **`length` operations** - Significantly faster (1.49-1.50x)
- **Filtering with `filter()`** - More efficient predicate evaluation
- **Small files** - Lower startup overhead

### Where jq excels:
- **Identity and `map(.)` on large files** - Better JSON serialization/pretty-printing
- **Stdin piping** - More optimized streaming input handling
- **`keys` on medium/big files** - Object key extraction

### Observations:
1. query-json's JSON pretty-printing/serialization appears to be the bottleneck on large files
2. Both tools perform similarly on huge files for non-output-heavy operations (keys)
3. query-json has an edge on operations that don't require full output serialization

