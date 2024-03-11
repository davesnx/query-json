Empty query makes the identity
  $ echo '{}' | Bin ''
  {}

  $ echo '{ "flores": 12 }' | Bin '.'
  { "flores": 12 }

  $ echo '{ "flores": 12 }' | Bin '.flores'
  12

Literals should return themselves
  $ echo '{}' | Bin '23'
  23

  $ echo '{ "foo": { "bar": 23 }}' | Bin '.foo.bar'
  23

non defined field gives back null when "?"
  $ echo '{ "foo": { "bar": {} }}' | Bin '.foo.bar.baz?'
  null

  $ echo '{ "foo": { "bar": {} }}' | Bin '.foo.bar.baz'
  
  Error:  Trying to ".baz" on an object, that don't have the field "baz":
  {}
  
