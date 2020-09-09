#!/usr/bin/env bats

@test "json call works ok" {
  run _build/default/bin/q.exe '.first.name' e2e/mock.json
  [ "$status" -eq 0 ]
}

@test "inline call works ok" {
  run _build/default/bin/q.exe --kind="inline" '.' '{ "a": 1 }'
  [ "$status" -eq 0 ]
  [ "$output" = '{ "a": 1 }' ]
}

@test "non defined field gives back null" {
  run _build/default/bin/q.exe '.wat' e2e/mock.json
  [ "$status" -eq 0 ]
  [ "$output" = "null" ]
}