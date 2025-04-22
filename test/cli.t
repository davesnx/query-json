json call works

  $ query-json --no-color '.first.name' mock.json
  "John Doe"

inline call works

  $ query-json --no-color --kind=inline '.' '{ "a": 1 }'
  { "a": 1 }
