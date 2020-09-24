#!/usr/bin/env sh

trash="benchmarks/trash.json"

title () {
  echo ""
  echo "$1"
  echo "$2"
}

title "## Running benchmark tests..."
jq --version
query-json --version
faq --version
fx --version

test () {
  /usr/bin/time "$@"
}

touch $trash;

title "### Select an attribute on a small (4kb) JSON file" ".first.id"
test query-json '.first.id' benchmarks/small.json >> $trash
test jq '.first.id' benchmarks/small.json >> $trash
test faq '.first.id' benchmarks/small.json >> $trash
test fx benchmarks/small.json '.first.id' >> $trash

title "### Select an attribute on a medium (132k) JSON file" "."
#
test query-json '.' benchmarks/medium.json >> $trash
test jq '.' benchmarks/medium.json >> $trash
test faq '.' benchmarks/medium.json >> $trash
test fx benchmarks/medium.json '.' >> $trash

title "### Select an attribute on a big JSON (604k) file" "map(.)"
#
test query-json 'map(.)' benchmarks/big.json >> $trash
test jq 'map(.)' benchmarks/big.json >> $trash
test faq 'map(.)' benchmarks/big.json >> $trash
test fx benchmarks/big.json '.map(x => x)' >> $trash

title "### Simple operation on a small (4kb) JSON file" ".second.store.books | map(.price + 10)"
#
test query-json '.second.store.books | map(.price + 10)' benchmarks/small.json >> $trash
test jq '.second.store.books | map(.price + 10)' benchmarks/small.json >> $trash
test fx benchmarks/small.json '.second.store.books.map(x => x.price + 10)' >> $trash

title "### Simple operation on a medium (132k) JSON file" "map(.time)"
#
test query-json 'map(.time)' benchmarks/medium.json >> $trash
test jq 'map(.time)' benchmarks/medium.json >> $trash
test faq 'map(.time)' benchmarks/medium.json >> $trash
test fx benchmarks/medium.json '.map(x => x.time)' >> $trash

title "### Simple operation an attribute on a big JSON (604k) file" "map(select(.base.Attack > 100)) | map(.name.english)"
#
test query-json 'filter(.base."Attack" > 100) | map(.name.english)' benchmarks/big.json >> $trash
test jq 'map(select(.base.Attack > 100)) | map(.name.english)' benchmarks/big.json >> $trash
# test faq 'filter(.base."Attack" > 100) | map(.name.english)' benchmarks/big.json >> $trash
test fx benchmarks/big.json '.filter(x => x.base["Attack"] > 100).map(x => x.name.english)' >> $trash

title "### Simple operation an attribute on a huge JSON (110M) file" "keys"
#
test query-json 'keys' benchmarks/huge.json >> $trash
test jq 'keys' benchmarks/huge.json >> $trash
test faq 'keys' benchmarks/huge.json >> $trash
test fx benchmarks/huge.json 'Object.keys' >> $trash

rm $trash