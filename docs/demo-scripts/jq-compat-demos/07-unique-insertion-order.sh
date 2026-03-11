#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../common.sh"

section "unique insertion order"
run_cmd "echo '[3,1,2,1,3]' | jq 'unique'"
run_cmd "echo '[3,1,2,1,3]' | ${QUERY_JSON_BIN} 'unique'"
