#!/usr/bin/env sh

trash="benchmarks/trash.json"

title () {
  echo ""
  echo "$1"
  echo "$2"
}

title "## Running benchmark tests..."
# pxi --version
jq --version
q --version

test () {
  /usr/bin/time "$@"
}

title "### Select an attribute on a small (4kb) JSON file" ".first.id"
# test pxi 'json => json.first.id' < benchmarks/small.json > $trash
test jq '.first.id' benchmarks/small.json > $trash
test q '.first.id' benchmarks/small.json > $trash

title "### Select an attribute on a medium (132k) JSON file" "."
# test pxi 'json => json.map(item => item.time)' < benchmarks/medium.json > $trash
test jq '.' benchmarks/medium.json > $trash
test q '.' benchmarks/medium.json > $trash

title "### Select an attribute on a big JSON (604k) file" "map(.)"
# test pxi 'json => Object.keys(json)' < benchmarks/big.json > $trash
test jq 'map(.)' benchmarks/big.json > $trash
test q 'map(.)' benchmarks/big.json > $trash

title "### Simple operation on a small (4kb) JSON file" ".second.store.books | map(.price + 10)"
# test pxi 'json => json.time' < benchmarks/small.json
test jq '.second.store.books | map(.price + 10)' benchmarks/small.json > $trash
test q '.second.store.books | map(.price + 10)' benchmarks/small.json > $trash

title "### Simple operation on a medium (132k) JSON file" "map(.time)"
# test pxi 'json => json.first.id' < benchmarks/medium.json > $trash
test jq 'map(.time)' benchmarks/medium.json > $trash
test q 'map(.time)' benchmarks/medium.json > $trash

title "### Simple operation an attribute on a big JSON (604k) file" "map(select(.base.Attack > 100)) | map(.name.english)"
# test pxi 'json => json.time' < benchmarks/big.json > $trash
test jq 'map(select(.base.Attack > 100)) | map(.name.english)' benchmarks/big.json > $trash
test q 'filter(.base."Attack" > 100) | map(.name.english)' benchmarks/big.json > $trash

title "### Simple operation an attribute on a huge JSON (110M) file" "keys"
# test pxi 'json => json.time' < benchmarks/huge.json > $trash
test jq 'keys' benchmarks/huge.json > $trash
test q 'keys' benchmarks/huge.json > $trash

rm $trash