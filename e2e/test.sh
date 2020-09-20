#!/usr/bin/env bats

function query-json () {
  if [[ -n $IS_CI ]]; then
    echo "Running in CI mode"
    run ./query-json "$@"
  else
    chmod +x _build/default/bin/Bin.exe
    run "_build/default/bin/Bin.exe" "$@"
  fi
}

@test "json call works ok" {
  query-json --no-color '.first.name' e2e/mock.json
  [ "$status" -eq 0 ]
  [ "$output" = '"John Doe"' ]
}

@test "inline call works ok" {
  query-json --no-color --kind=inline '.' '{ "a": 1 }'
  [ "$status" -eq 0 ]
  [ "$output" = '"John Doe"' ]
}

@test "stdin works ok" {
  cat e2e/mock.json | query-json '.first.name'
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