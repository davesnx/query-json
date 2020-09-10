#!/usr/bin/env sh
# pxi --version
jq --version
q --version

function test () {
  /usr/bin/time "$@"
}

function title () {
  echo ""
  echo "$@"
  echo ""
  echo ""
}

echo ""

title "Select an attribute on small JSON files"
# test pxi 'json => json.first.id' < benchmarks/small.json
test jq '.first.id' benchmarks/small.json
test q '.first.id' benchmarks/small.json

title "Select an attribute on big JSON files"
# test pxi 'json => json.time' < benchmarks/big.json
test jq 'keys' benchmarks/big.json
test q 'keys' benchmarks/big.json

title "Bigger operation an attribute on small JSON file"
# test pxi 'json => json.time' < benchmarks/small.json
test jq '.second.store.books | map(.price + 10)' benchmarks/small.json
test q '.second.store.books | map(.price + 10)' benchmarks/small.json

title "Bigger operation an attribute on big JSON files"
# test pxi 'json => json.time' < benchmarks/big.json
test jq '.features | map(.properties."MAPBLKLOT")' benchmarks/big.json
test q '.features | map(.properties."MAPBLKLOT")' benchmarks/big.json