#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../common.sh"

run_cmd "bash docs/demo-scripts/jq-compat-demos/00-error-messages.sh"
run_cmd "bash docs/demo-scripts/jq-compat-demos/01-stricter-null-handling.sh"
run_cmd "bash docs/demo-scripts/jq-compat-demos/02-fn-vs-def.sh"
run_cmd "bash docs/demo-scripts/jq-compat-demos/03-snake-case-naming.sh"
run_cmd "bash docs/demo-scripts/jq-compat-demos/04-clearer-naming.sh"
run_cmd "bash docs/demo-scripts/jq-compat-demos/05-group-by-behavior.sh"
run_cmd "bash docs/demo-scripts/jq-compat-demos/06-keys-insertion-order.sh"
run_cmd "bash docs/demo-scripts/jq-compat-demos/07-unique-insertion-order.sh"
run_cmd "bash docs/demo-scripts/jq-compat-demos/08-infinite-generator.sh"
run_cmd "bash docs/demo-scripts/jq-compat-demos/09-optional-access-functions.sh"
run_cmd "bash docs/demo-scripts/jq-compat-demos/10-additional-features.sh"
