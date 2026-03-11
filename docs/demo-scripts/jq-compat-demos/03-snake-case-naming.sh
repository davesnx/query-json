#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../common.sh"

section "Snake case naming"
run_cmd "echo '\"hello\"' | jq 'ascii_upcase'"
run_cmd "echo '\"hello\"' | ${QUERY_JSON_BIN} 'to_uppercase'"
