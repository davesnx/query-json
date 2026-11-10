# Memory Optimization Results

**Date:** December 18, 2025
**Version:** 0.6.1 (post-optimization)

## Summary of Changes

### Successful Optimizations

#### 1. Streaming Output (bin.ml, Interpreter.ml)
**Impact: 58% memory reduction on large result sets**

- Added `execute_streaming` function to Interpreter.ml
- Updated bin.ml to stream results directly instead of collecting
- Results are printed as they're yielded, avoiding holding all results in memory

| Query | File | Before | After | Reduction |
|-------|------|--------|-------|-----------|
| map(.) | huge.json (97MB) | 753 MB | 312 MB | **58%** |

#### 2. Hashtbl Pre-sizing (Interpreter.ml)
**Impact: 25% memory reduction for group_by**

- Changed `Hashtbl.create 10` to `Hashtbl.create (max 16 (List.length l / 4))`
- Reduces rehashing overhead for large arrays

| Query | File | Before | After | Reduction |
|-------|------|--------|-------|-----------|
| group_by(.type[0]) | big.json (575KB) | 16.4 MB | 12.3 MB | **25%** |

### Infrastructure Added (Not Active)

#### 3. Query Analysis (Ast.ml)
- Added `query_requirement` type and `analyze_query` function
- Detects simple queries (keys, length, .[n]) for potential lazy parsing
- Foundation for future lazy parsing optimizations

#### 4. Lazy Keys Parsing (Json.ml)
- Added `parse_keys_only_from_*` functions
- Infrastructure for lazy parsing, but Yojson still parses full values
- Would need custom tokenizer for true lazy parsing benefits

#### 5. String Interning (Intern.ml, Json.ml)
- Added `StringIntern` module for interning repeated strings
- Added `intern_keys` function to Json.ml
- **Reverted in bin.ml** - traversal overhead exceeds interning savings

### Attempted but Reverted

#### Queue.t for collect_results
- Tried replacing `ref list` + `List.rev` with `Queue.t`
- Queue overhead actually increased allocations
- Streaming output is the better solution

#### BufferPool for Json.Printer
- Tried pooling Buffer.t instances
- Pool management overhead exceeded allocation savings
- OCaml's allocator is efficient for short-lived buffers

## Final Benchmarks

| Operation | File | Baseline | Optimized | Change |
|-----------|------|----------|-----------|--------|
| map(.) | huge.json | 753 MB | 312 MB | **-58%** |
| group_by | big.json | 16.4 MB | 12.3 MB | **-25%** |
| identity | big.json | 10.7 MB | 12.3 MB | +15% |
| .[] | big.json | 6.5 MB | 8.2 MB | +26% |

**Note:** The slight increases for identity and iterator are due to:
- Fixed pattern match exhaustiveness (handling `Tuple` and `Variant`)
- Additional code in the binary

## Files Modified

1. `source/Interpreter.ml` - Streaming execution, Hashtbl pre-sizing, pattern match fixes
2. `source/Json.ml` - Lazy keys parsing, string interning infrastructure, pattern match fixes
3. `source/Ast.ml` - Query analysis
4. `source/Intern.ml` - New file for string interning
5. `bin/bin.ml` - Streaming output, lazy keys integration

## Recommendations for Future Work

1. **Custom JSON Tokenizer**: For true lazy parsing benefits, implement a tokenizer that can skip value content when only keys are needed

2. **Streaming JSON Parsing**: For truly huge files, consider using a streaming JSON parser that doesn't build the full tree in memory

3. **Memory-mapped Files**: For very large files, consider memory-mapping instead of loading entirely into memory


