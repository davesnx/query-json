#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../common.sh"

section "Optional access on functions"
run_cmd "${QUERY_JSON_BIN} 'first?' <<< '[]'"
run_cmd "${QUERY_JSON_BIN} 'last?' <<< '[]'"
