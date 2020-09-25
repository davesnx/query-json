#!/usr/bin/env bash

title () {
  echo ""
  echo "$1"
  echo "$2"
}

title "Running benchmark tests..."
echo "query-json: $(query-json --version)"
echo "jq: $(jq --version)"
echo "faq: $(faq --version)"
echo "fx: $(fx --version)"
echo ""

test () {
  /usr/bin/time "$@"
}

title "### Pipe a json to stdin"
test cat benchmarks/big.json | query-json --kind=inline '.' > /dev/null
test cat benchmarks/big.json | jq '.' > /dev/null
test cat benchmarks/big.json | faq '.' > /dev/null
test cat benchmarks/big.json | fx '.' > /dev/null
test cat benchmarks/big.json | jet --from json --to json '.' > /dev/null

title "### Select an attribute on a small (4kb) JSON file" ".first.id"
test query-json '.first.id' benchmarks/small.json > /dev/null
test jq '.first.id' benchmarks/small.json > /dev/null
test faq '.first.id' benchmarks/small.json > /dev/null
test fx benchmarks/small.json '.first.id' > /dev/null

title "### Select an attribute on a medium (132k) JSON file" "."
test query-json '.' benchmarks/medium.json > /dev/null
test jq '.' benchmarks/medium.json > /dev/null
test faq '.' benchmarks/medium.json > /dev/null
test fx benchmarks/medium.json '.' > /dev/null

title "### Select an attribute on a big JSON (604k) file" "map(.)"
test query-json 'map(.)' benchmarks/big.json > /dev/null
test jq 'map(.)' benchmarks/big.json > /dev/null
test faq 'map(.)' benchmarks/big.json > /dev/null
test fx benchmarks/big.json '.map(x => x)' > /dev/null

title "### Simple operation on a small (4kb) JSON file" ".second.store.books | map(.price + 10)"
test query-json '.second.store.books | map(.price + 10)' benchmarks/small.json > /dev/null
test jq '.second.store.books | map(.price + 10)' benchmarks/small.json > /dev/null
test fx benchmarks/small.json '.second.store.books.map(x => x.price + 10)' > /dev/null

title "### Simple operation on a medium (132k) JSON file" "map(.time)"
test query-json 'map(.time)' benchmarks/medium.json > /dev/null
test jq 'map(.time)' benchmarks/medium.json > /dev/null
test faq 'map(.time)' benchmarks/medium.json > /dev/null
test fx benchmarks/medium.json '.map(x => x.time)' > /dev/null

title "### Simple operation an attribute on a big JSON (604k) file" "map(select(.base.Attack > 100)) | map(.name.english)"
test query-json 'filter(.base."Attack" > 100) | map(.name.english)' benchmarks/big.json > /dev/null
test jq 'map(select(.base.Attack > 100)) | map(.name.english)' benchmarks/big..json > /dev/null
# test faq 'filter(.base."Attack" > 100) | map(.name.english)' benchmarks/big.json > /dev/null
test fx benchmarks/big.json '.filter(x => x.base["Attack"] > 100).map(x => x.name.english)' > /dev/null

title "### Simple operation an attribute on a huge JSON (110M) file" "keys"
test query-json 'keys' benchmarks/huge.json > /dev/null
test jq 'keys' benchmarks/huge.json > /dev/null
test faq 'keys' benchmarks/huge.json > /dev/null
test fx benchmarks/huge.json 'Object.keys' > /dev/null