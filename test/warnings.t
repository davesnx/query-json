Deprecation warnings with verbose flag

tonumber warning appears with -v flag
  $ echo '"42"' | query-json --no-color -v 'tonumber'
  
  Error:  error[parse_error]: problem parsing at [line: 1, char: 8-8]
    --> tonumber
                ^
  

tostring warning appears with -v flag
  $ echo '42' | query-json --no-color -v 'tostring'
  
  Error:  error[parse_error]: problem parsing at [line: 1, char: 8-8]
    --> tostring
                ^
  

startwith warning appears with -v flag
  $ echo '"Hello, world"' | query-json --no-color -v 'startwith("Hello")'
  
  Error:  error[parse_error]: problem parsing at [line: 1, char: 17-18]
    --> startwith("Hello")
                         ^
  

startswith warning appears with -v flag
  $ echo '"Hello, world"' | query-json --no-color -v 'startswith("Hello")'
  
  Error:  error[parse_error]: problem parsing at [line: 1, char: 18-19]
    --> startswith("Hello")
                          ^
  

endwith warning appears with -v flag
  $ echo '"Hello, world"' | query-json --no-color -v 'endwith("world")'
  
  Error:  error[parse_error]: problem parsing at [line: 1, char: 15-16]
    --> endwith("world")
                       ^
  

endswith warning appears with -v flag
  $ echo '"Hello, world"' | query-json --no-color -v 'endswith("world")'
  
  Error:  error[parse_error]: problem parsing at [line: 1, char: 16-17]
    --> endswith("world")
                        ^
  

No warnings without -v flag

  $ echo '"42"' | query-json --no-color 'tonumber'
  
  Error:  error[parse_error]: problem parsing at [line: 1, char: 8-8]
    --> tonumber
                ^
  

  $ echo '42' | query-json --no-color 'tostring'
  
  Error:  error[parse_error]: problem parsing at [line: 1, char: 8-8]
    --> tostring
                ^
  

  $ echo '"Hello, world"' | query-json --no-color 'startwith("Hello")'
  
  Error:  error[parse_error]: problem parsing at [line: 1, char: 17-18]
    --> startwith("Hello")
                         ^
  

  $ echo '"Hello, world"' | query-json --no-color 'startswith("Hello")'
  
  Error:  error[parse_error]: problem parsing at [line: 1, char: 18-19]
    --> startswith("Hello")
                          ^
  

  $ echo '"Hello, world"' | query-json --no-color 'endwith("world")'
  
  Error:  error[parse_error]: problem parsing at [line: 1, char: 15-16]
    --> endwith("world")
                       ^
  

  $ echo '"Hello, world"' | query-json --no-color 'endswith("world")'
  
  Error:  error[parse_error]: problem parsing at [line: 1, char: 16-17]
    --> endswith("world")
                        ^
  

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

