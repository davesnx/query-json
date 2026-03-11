#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../common.sh"

section "infinite generator"
run_cmd "${QUERY_JSON_BIN} '[limit(5; infinite)]' <<< 'null'"
