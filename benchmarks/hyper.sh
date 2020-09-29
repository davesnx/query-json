#!/usr/bin/env sh

hyperfine --style basic --warmup 10 --min-runs 3 --export-markdown benchmarks/boot-time-report.md "query-json '.' esy.json" "jq '.' esy.json" "faq '.' esy.json" "fx esy.json '.'"