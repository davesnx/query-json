#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../common.sh"

section "Helpful error messages"
run_cmd "${QUERY_JSON_BIN} '.naem' '{\"name\":\"Alice\"}'"
