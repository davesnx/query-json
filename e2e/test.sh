#!/usr/bin/env bats

function q () {
  if [[ ! -z $IS_CI ]]; then
    echo "Running in CI mode"
    run ./q "$@"
  else
    chmod +x _build/default/bin/q.exe
    run "_build/default/bin/q.exe" "$@"
  fi
}

@test "json call works ok" {
  q --no-color '.first.name' e2e/mock.json
  [ "$status" -eq 0 ]
  [ "$output" = '"John Doe"' ]
}

@test "inline call works ok" {
  q --kind="inline" --no-color '.' '{ "a": 1 }'
  [ "$status" -eq 0 ]
  [ "$output" = '{ "a": 1 }' ]
}

@test "non defined field gives back null" {
  q --no-color '.wat?' e2e/mock.json
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