#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

section "query-json advanced filters"
run_cmd "${QUERY_JSON_BIN} '.second.store.books | map(.price) | add' test/mock.json"
run_cmd "${QUERY_JSON_BIN} 'fn expensive: .price > 20; .second.store.books | filter(expensive)' test/mock.json"
run_cmd "${QUERY_JSON_BIN} '.second.store.books | group_by(.category) | map_values(length)' test/mock.json"
run_cmd "${QUERY_JSON_BIN} '.second.store.books | map({title, price_with_tax: (.price * 1.21)})' test/mock.json"
