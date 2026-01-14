null input with simple query

  $ query-json --no-color -n '.'
  null

null input with object construction

  $ query-json --no-color -n '{ "a": 1, "b": 2 }'
  { "a": 1, "b": 2 }

null input piped with stdin (stdin should be ignored)

  $ echo '{ "ignored": true }' | query-json --no-color -n '{ "used": "null" }'
  { "used": "null" }

null input with cat piped (should be ignored)

  $ cat mock.json | query-json --no-color -n '{ "source": "null-input" }'
  { "source": "null-input" }

null input with conditional

  $ query-json --no-color -n 'if . == null then "is null" else "not null" end'
  "is null"

null input with array map

  $ query-json --no-color -n '[1, 2, 3] | map(. * 2)'
  [ 2, 4, 6 ]

null input with raw output

  $ query-json --no-color -n -r '"raw string"'
  raw string

null input creates data from scratch

  $ query-json --no-color -n '{ "numbers": [1, 2, 3], "total": ([1, 2, 3] | add) }'
  { "numbers": [ 1, 2, 3 ], "total": 6 }
