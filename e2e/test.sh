#!/usr/bin/env bats

function query-json () {
  if [[ ! -z $IS_CI ]]; then
    echo "Running in CI mode"
    run ./query-json "$@"
  else
    chmod +x _build/default/bin/query-json.exe
    run "_build/default/bin/query-json.exe" "$@"
  fi
}

@test "json call works ok" {
  query-json --no-color '.first.name' e2e/mock.json
  [ "$status" -eq 0 ]
  [ "$output" = '"John Doe"' ]
}

@test "inline call works ok" {
  query-json --kind="inline" --no-color '.' '{ "a": 1 }'
  [ "$status" -eq 0 ]
  [ "$output" = '{ "a": 1 }' ]
}

@test "non defined field gives back null" {
  query-json --no-color '.wat?' e2e/mock.json
  [ "$status" -eq 0 ]
  [ "$output" = "null" ]
}

teardown () {
    echo "$BATS_TEST_NAME

--------
$output
--------

"
}