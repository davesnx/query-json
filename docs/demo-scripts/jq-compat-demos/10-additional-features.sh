#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../common.sh"

section "Additional query-json features"
run_cmd "${QUERY_JSON_BIN} 'pluck(.name)' <<< '[{\"name\":\"A\"},{\"name\":\"B\"}]'"
run_cmd "${QUERY_JSON_BIN} 'partition(. > 10)' <<< '[3,12,1,20]'"
run_cmd "${QUERY_JSON_BIN} 'find(. > 10)' <<< '[3,12,1,20]'"
