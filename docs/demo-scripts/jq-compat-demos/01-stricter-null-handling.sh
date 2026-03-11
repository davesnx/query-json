#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../common.sh"

section "Stricter null handling"
run_cmd "${QUERY_JSON_BIN} '.missing.key' '{\"name\":\"Alice\"}'"
run_cmd "${QUERY_JSON_BIN} '.missing?.key?' '{\"name\":\"Alice\"}'"
