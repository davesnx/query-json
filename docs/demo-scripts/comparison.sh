#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

section "jq vs query-json"
run_cmd "echo '\"hello\"' | jq 'ascii_upcase'"
run_cmd "echo '\"hello\"' | ${QUERY_JSON_BIN} 'to_uppercase'"
run_cmd "echo '42' | jq 'tostring'"
run_cmd "echo '42' | ${QUERY_JSON_BIN} 'to_string'"
run_cmd "echo '[1,2,3]' | jq 'def double: . * 2; map(double)'"
run_cmd "echo '[1,2,3]' | ${QUERY_JSON_BIN} 'fn double: . * 2; map(double)'"
