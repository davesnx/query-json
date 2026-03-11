#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../common.sh"

section "keys insertion order"
run_cmd "echo '{\"z\":1,\"a\":2,\"m\":3}' | jq 'keys'"
run_cmd "echo '{\"z\":1,\"a\":2,\"m\":3}' | ${QUERY_JSON_BIN} 'keys'"
