json call works

  $ query-json --no-color '.first.name' mock.json
  "John Doe"

inline call works

  $ query-json --no-color '.' '{ "a": 1 }'
  { "a": 1 }

stdin works

  $ echo '{ "b": 2 }' | query-json --no-color '.'
  { "b": 2 }

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
  {
    "id": 1,
    "title": "The Art of Flipping Coins",
    "url": "http://example.com/398eb027/1"
  }

raw output for array (should still output JSON)

  $ query-json --no-color -r '.first.pages[0,1]' mock.json
  {
    "id": 1,
    "title": "The Art of Flipping Coins",
    "url": "http://example.com/398eb027/1"
  }
  { "id": 2, "deleted": true }

raw output with string containing escape sequences

  $ printf '{"message": "Hello\\nWorld\\t!"}' | query-json --no-color '.message'
  "Hello\nWorld\t!"

  $ printf '{"message": "Hello\\nWorld\\t!"}' | query-json --no-color -r '.message'
  Hello
  World	!
