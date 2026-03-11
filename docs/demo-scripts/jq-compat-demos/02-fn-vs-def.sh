#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../common.sh"

section "fn vs def"
run_cmd "echo '[1,2,3]' | jq 'def double: . * 2; map(double)'"
run_cmd "echo '[1,2,3]' | ${QUERY_JSON_BIN} 'fn double: . * 2; map(double)'"
