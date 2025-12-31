Deprecation warnings with verbose flag

tonumber warning appears with -v flag
  $ echo '"42"' | query-json --no-color -v 'tonumber'
  Warning: Using deprecated 'tonumber'. Use 'to_number' instead. This may not be supported in future versions.
  42

tostring warning appears with -v flag
  $ echo '42' | query-json --no-color -v 'tostring'
  Warning: Using deprecated 'tostring'. Use 'to_string' instead. This may not be supported in future versions.
  "42"

startwith warning appears with -v flag
  $ echo '"Hello, world"' | query-json --no-color -v 'startwith("Hello")'
  Warning: Using deprecated 'startwith' or 'startswith'. Use 'starts_with' instead. This may not be supported in future versions.
  true

startswith warning appears with -v flag
  $ echo '"Hello, world"' | query-json --no-color -v 'startswith("Hello")'
  Warning: Using deprecated 'startwith' or 'startswith'. Use 'starts_with' instead. This may not be supported in future versions.
  true

endwith warning appears with -v flag
  $ echo '"Hello, world"' | query-json --no-color -v 'endwith("world")'
  Warning: Using deprecated 'endwith' or 'endswith'. Use 'ends_with' instead. This may not be supported in future versions.
  true

endswith warning appears with -v flag
  $ echo '"Hello, world"' | query-json --no-color -v 'endswith("world")'
  Warning: Using deprecated 'endwith' or 'endswith'. Use 'ends_with' instead. This may not be supported in future versions.
  true

No warnings without -v flag

  $ echo '"42"' | query-json --no-color 'tonumber'
  42

  $ echo '42' | query-json --no-color 'tostring'
  "42"

  $ echo '"Hello, world"' | query-json --no-color 'startwith("Hello")'
  true

  $ echo '"Hello, world"' | query-json --no-color 'startswith("Hello")'
  true

  $ echo '"Hello, world"' | query-json --no-color 'endwith("world")'
  true

  $ echo '"Hello, world"' | query-json --no-color 'endswith("world")'
  true

New names work without warnings

  $ echo '"42"' | query-json --no-color -v 'to_number'
  42

  $ echo '42' | query-json --no-color -v 'to_string'
  "42"

  $ echo '"Hello, world"' | query-json --no-color -v 'starts_with("Hello")'
  true

  $ echo '"Hello, world"' | query-json --no-color -v 'starts_with("boo")'
  false

  $ echo '"Hello, world"' | query-json --no-color -v 'ends_with("world")'
  true

