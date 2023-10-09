json call works
  $ Bin --no-color '.first.name' mock.json
  "John Doe"

inline call works
  $ Bin --no-color --kind=inline '.' '{ "a": 1 }'
  { "a": 1 }
