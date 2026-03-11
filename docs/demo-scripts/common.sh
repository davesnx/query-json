#!/usr/bin/env bash
set -euo pipefail

QUERY_JSON_BIN="${QUERY_JSON_BIN:-_opam/bin/query-json}"
if [ ! -x "$QUERY_JSON_BIN" ]; then
  QUERY_JSON_BIN="$(command -v query-json)"
fi

section() {
  printf '\n# %s\n' "$1"
  sleep 0.8
}

run_cmd() {
  printf '\n$ %s\n' "$1"
  eval "$1"
  sleep 1
}
