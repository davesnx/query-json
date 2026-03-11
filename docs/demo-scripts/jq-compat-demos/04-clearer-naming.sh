#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../common.sh"

section "Clearer naming"
run_cmd "echo '\"hello world\"' | jq 'startswith(\"hello\")'"
run_cmd "echo '\"hello world\"' | ${QUERY_JSON_BIN} 'starts_with(\"hello\")'"
