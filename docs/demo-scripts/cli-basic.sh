#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

section "query-json basic CLI"
run_cmd "${QUERY_JSON_BIN} --version"
run_cmd "${QUERY_JSON_BIN} '.second.store.books[0].title' test/mock.json"
run_cmd "cat test/mock.json | ${QUERY_JSON_BIN} '.second.store.books | length'"
run_cmd "${QUERY_JSON_BIN} '.users | map(.name)' '{\"users\": [{\"name\": \"Alice\"}, {\"name\": \"Bob\"}]}'"
run_cmd "${QUERY_JSON_BIN} -r '.second.store.books[0].author' test/mock.json"
