#!/usr/bin/env sh

title () {
  echo ""
  echo "$@"
  echo ""
}

title "Running benchmark tests..."
# pxi --version
jq --version
q --version

test () {
  /usr/bin/time "$@"
}

title "Select an attribute on a small (4kb) JSON file"
# test pxi 'json => json.first.id' < benchmarks/small.json
test jq '.first.id' benchmarks/small.json
test q '.first.id' benchmarks/small.json

title "Select an attribute on a medium (132k) JSON file"
# test pxi 'json => json.map(item => item.time)' < benchmarks/medium.json
test jq '.' benchmarks/medium.json
test q '.' benchmarks/medium.json

title "Select an attribute on a big JSON (604k) file"
# test pxi 'json => Object.keys(json)' < benchmarks/big.json
test jq 'keys' benchmarks/big.json
test q 'keys' benchmarks/big.json

title "Simple operation on a small (4kb) JSON file"
# test pxi 'json => json.time' < benchmarks/small.json
test jq '.second.store.books | map(.price + 10)' benchmarks/small.json
test q '.second.store.books | map(.price + 10)' benchmarks/small.json

title "Simple operation on a medium (132k) JSON file"
# test pxi 'json => json.first.id' < benchmarks/medium.json
test jq 'map(.time)' benchmarks/medium.json
test q 'map(.time)' benchmarks/medium.json

title "Simple operation an attribute on a big JSON (604k) file"
# test pxi 'json => json.time' < benchmarks/big.json
test jq 'map(select(.base.Attack > 100)) | map(.name.english)' benchmarks/big.json
test q 'filter(.base."Attack" > 100) | map(.name.english)' benchmarks/big.json