#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../common.sh"

section "group_by behavior"
run_cmd "echo '[{\"x\":1},{\"x\":2},{\"x\":1}]' | jq 'group_by(.x)'"
run_cmd "echo '[{\"x\":1},{\"x\":2},{\"x\":1}]' | ${QUERY_JSON_BIN} 'group_by(.x)'"
