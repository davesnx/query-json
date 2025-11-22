#!/usr/bin/env bash

# Configuration: which tools to benchmark (set to 0 to disable)
BENCH_JQ=${BENCH_JQ:-1}
BENCH_FAQ=${BENCH_FAQ:-0}
BENCH_FX=${BENCH_FX:-0}
BENCH_JET=${BENCH_JET:-0}

# Hyperfine settings
WARMUP=${WARMUP:-3}
MIN_RUNS=${MIN_RUNS:-10}
STYLE=${STYLE:-full}

echo "==================================="
echo "query-json performance benchmarks"
echo "==================================="
echo ""
echo "query-json version: $(query-json --version)"
[ "$BENCH_JQ" = "1" ] && echo "jq version: $(jq --version)"
[ "$BENCH_FAQ" = "1" ] && command -v faq &> /dev/null && echo "faq version: $(faq --version 2>/dev/null)"
[ "$BENCH_FX" = "1" ] && command -v fx &> /dev/null && echo "fx version: $(fx --version 2>/dev/null)"
[ "$BENCH_JET" = "1" ] && command -v jet &> /dev/null && echo "jet version: $(jet --version 2>/dev/null)"
echo "Date: $(date)"
echo ""

if ! command -v hyperfine &> /dev/null; then
    echo "Error: hyperfine is not installed"
    echo "Install with: brew install hyperfine (macOS) or cargo install hyperfine"
    exit 1
fi

run_bench() {
    local desc="$1"
    local qj_query="$2"
    local jq_query="${3:-$qj_query}"
    local fx_query="$4"
    local file="$5"

    echo ""
    echo "### $desc"
    echo "Query: $qj_query"
    echo "File: $file"
    echo ""

    local commands=("query-json '$qj_query' benchmarks/$file")

    if [ "$BENCH_JQ" = "1" ]; then
        commands+=("jq '$jq_query' benchmarks/$file")
    fi

    if [ "$BENCH_FAQ" = "1" ] && command -v faq &> /dev/null; then
        commands+=("faq '$qj_query' benchmarks/$file")
    fi

    if [ "$BENCH_FX" = "1" ] && command -v fx &> /dev/null && [ -n "$fx_query" ]; then
        commands+=("fx benchmarks/$file '$fx_query'")
    fi

    if [ "$BENCH_JET" = "1" ] && command -v jet &> /dev/null; then
        commands+=("jet --from json --to json '$qj_query' < benchmarks/$file")
    fi

    hyperfine --style "$STYLE" --warmup "$WARMUP" --min-runs "$MIN_RUNS" "${commands[@]}"
}

run_bench_stdin() {
    local desc="$1"
    local file="$2"

    echo ""
    echo "### $desc"
    echo "Query: ."
    echo "File: $file"
    echo ""

    local commands=("cat benchmarks/$file | query-json '.'")

    if [ "$BENCH_JQ" = "1" ]; then
        commands+=("cat benchmarks/$file | jq '.'")
    fi

    if [ "$BENCH_FAQ" = "1" ] && command -v faq &> /dev/null; then
        commands+=("cat benchmarks/$file | faq '.'")
    fi

    if [ "$BENCH_FX" = "1" ] && command -v fx &> /dev/null; then
        commands+=("cat benchmarks/$file | fx '.'")
    fi

    if [ "$BENCH_JET" = "1" ] && command -v jet &> /dev/null; then
        commands+=("cat benchmarks/$file | jet --from json --to json '.'")
    fi

    hyperfine --style "$STYLE" --warmup "$WARMUP" --min-runs "$MIN_RUNS" "${commands[@]}"
}

echo "==================================="
echo "Small File Tests (1.3KB)"
echo "==================================="
run_bench "Identity" "." "." "." "small.json"
run_bench "Select field" ".first.id" ".first.id" ".first.id" "small.json"
run_bench "Nested access with map" ".second.store.books | map(.price + 10)" ".second.store.books | map(.price + 10)" ".second.store.books.map(x => x.price + 10)" "small.json"

echo ""
echo "==================================="
echo "Medium File Tests (104KB)"
echo "==================================="
run_bench "Identity" "." "." "." "medium.json"
run_bench "Map identity" "map(.)" "map(.)" ".map(x => x)" "medium.json"
run_bench "Map with field access" "map(.time)" "map(.time)" ".map(x => x.time)" "medium.json"
run_bench "Length" "length" "length" ".length" "medium.json"

echo ""
echo "==================================="
echo "Big File Tests (575KB)"
echo "==================================="
run_bench "Identity" "." "." "." "big.json"
run_bench "Map identity" "map(.)" "map(.)" ".map(x => x)" "big.json"
run_bench "Keys" "keys" "keys" "Object.keys" "big.json"
run_bench "Length" "length" "length" ".length" "big.json"
run_bench "First element" ".[0]" ".[0]" ".[0]" "big.json"
run_bench "Filter and map" "filter(.base.\"Attack\" > 100) | map(.name.english)" "map(select(.base.Attack > 100)) | map(.name.english)" ".filter(x => x.base['Attack'] > 100).map(x => x.name.english)" "big.json"

echo ""
echo "==================================="
echo "Huge File Tests (97MB)"
echo "==================================="
run_bench "Keys" "keys" "keys" "Object.keys" "huge.json"
run_bench "Identity (streaming)" "." "." "." "huge.json"

echo ""
echo "==================================="
echo "Stdin Piping Tests (575KB)"
echo "==================================="
run_bench_stdin "Pipe JSON to stdin" "big.json"

echo ""
echo "==================================="
echo "Benchmark Complete!"
echo "==================================="
