  $ Bin --debug --verbose '' <<< '{}'
  EOF

  $ Bin --debug --verbose '.' <<< '{ "flores": 12 }'
  12

$ Bin '23' <<< '{}'
23

$ Bin '.foo.bar' <<< '{ "foo": { "bar": 23 }}'
23

$ Bin '.foo.bar.baz?' <<< '{ "foo": { "bar": {} }}'
null

$ Bin '.foo.bar.baz' <<< '{ "foo": { "bar": {} }}'

Error:  Trying to ".baz" on an object, that don't have the field "baz":
{}

