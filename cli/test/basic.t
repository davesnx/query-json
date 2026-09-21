json call works

  $ query-json --no-color '.first.name' mock.json
  "John Doe"

inline call works

  $ query-json --no-color '.' '{ "a": 1 }'
  { "a": 1 }

stdin works

  $ echo '{ "b": 2 }' | query-json --no-color '.'
  { "b": 2 }

stdin with cat works

  $ cat mock.json | query-json --no-color '.first.name'
  "John Doe"

raw output for string

  $ query-json --no-color -r '.first.name' mock.json
  John Doe

raw output for string (without -r for comparison)

  $ query-json --no-color '.first.name' mock.json
  "John Doe"

raw output for number

  $ query-json --no-color -r '.second.store.books[0].price' mock.json
  8.95

raw output for boolean

  $ query-json --no-color -r '.first.pages[1].deleted' mock.json
  true

raw output for integer

  $ query-json --no-color -r '.first.pages[0].id' mock.json
  1

raw output for object (should still output JSON)

  $ query-json --no-color -r '.first.pages[0]' mock.json
  { "id": 1, "title": "The Art of Flipping Coins", "url": "http://example.com/398eb027/1" }

raw output for array (should still output JSON)

  $ query-json --no-color -r '.first.pages[0,1]' mock.json
  { "id": 1, "title": "The Art of Flipping Coins", "url": "http://example.com/398eb027/1" }
  { "id": 2, "deleted": true }

raw output with string containing escape sequences

  $ printf '{"message": "Hello\\nWorld\\t!"}' | query-json --no-color '.message'
  "Hello\nWorld\t!"

  $ printf '{"message": "Hello\\nWorld\\t!"}' | query-json --no-color -r '.message'
  Hello
  World	!

stream output for multiple results

  $ query-json --no-color --stream-output '.[]' '[1,2,3]'
  1
  2
  3

empty stream output still writes one LF

  $ query-json --no-color --stream-output 'empty' 'null' | od -An -tx1
   0a

raw stream output preserves empty strings and embedded newlines

  $ query-json --no-color --stream-output -r '.[]' '["","a\nb","","\n",""]' | od -An -tx1
   0a 61 0a 62 0a 0a 0a 0a 0a

successful output bytes match default mode, including raw edge cases

  $ for options in '' '-r'; do
  >   for json in '[]' '[1,2,3]' '[""]' '["\n"]' '["","a\nb","","\n",""]'; do
  >     query-json --no-color $options '.[]' "$json" > default.out
  >     query-json --no-color --stream-output $options '.[]' "$json" > stream.out
  >     cmp default.out stream.out || exit 1
  >   done
  > done

stream output keeps the prefix on stdout and sends the late error to stderr

  $ query-json --no-color --stream-output '.[] | .value' '[{"value":1},{"value":2},{}]' 2>&1 | sed '/^$/d'
  1
  2
  error[key_not_found]: Key 'value' not found in object
    in: {}
    hint: Use .value? for optional access

default output remains atomic on the same late error

  $ query-json --no-color '.[] | .value' '[{"value":1},{"value":2},{}]' | sed '/^$/d'
  error[key_not_found]: Key 'value' not found in object
    in: {}
    hint: Use .value? for optional access
