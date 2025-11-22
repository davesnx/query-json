json call works

  $ query-json --no-color '.first.name' mock.json
  "John Doe"

inline call works

  $ query-json --no-color '.' '{ "a": 1 }'
  { "a": 1 }

stdin works

  $ echo '{ "b": 2 }' | query-json --no-color '.'
  { "b": 2 }
