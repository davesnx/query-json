Empty query makes the identity
  $ Bin '' <<< '{}'
  {}

  $ Bin '.' <<< '{ "flores": 12 }'
  { "flores": 12 }

  $ Bin '.flores' <<< '{ "flores": 12 }'
  12

Literals should return themselves
  $ Bin '23' <<< '{}'
  23

  $ Bin '.foo.bar' <<< '{ "foo": { "bar": 23 }}'
  23

non defined field gives back null when "?"
  $ Bin '.foo.bar.baz?' <<< '{ "foo": { "bar": {} }}'
  null

  $ Bin '.foo.bar.baz' <<< '{ "foo": { "bar": {} }}'
  
  Error:  Trying to ".baz" on an object, that don't have the field "baz":
  {}
  
