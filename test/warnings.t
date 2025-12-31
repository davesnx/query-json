tonumber is deprecated - now errors
  $ echo '"42"' | query-json --no-color 'tonumber'
  
  error[semantic_error]: tonumber is deprecated. Use to_number instead
    --> tonumber
                ^
  

tostring is deprecated - now errors
  $ echo '42' | query-json --no-color 'tostring'
  
  error[semantic_error]: tostring is deprecated. Use to_string instead
    --> tostring
                ^
  

startwith is deprecated - now errors
  $ echo '"Hello, world"' | query-json --no-color 'startwith("Hello")'
  
  error[semantic_error]: startwith is deprecated. Use starts_with instead
    --> startwith("Hello")
                         ^
  

startswith is deprecated - now errors
  $ echo '"Hello, world"' | query-json --no-color 'startswith("Hello")'
  
  error[semantic_error]: startswith is deprecated. Use starts_with instead
    --> startswith("Hello")
                          ^
  

endwith is deprecated - now errors
  $ echo '"Hello, world"' | query-json --no-color 'endwith("world")'
  
  error[semantic_error]: endwith is deprecated. Use ends_with instead
    --> endwith("world")
                       ^
  

endswith is deprecated - now errors
  $ echo '"Hello, world"' | query-json --no-color 'endswith("world")'
  
  error[semantic_error]: endswith is deprecated. Use ends_with instead
    --> endswith("world")
                        ^
  
New names work correctly

  $ echo '"42"' | query-json --no-color 'to_number'
  42

  $ echo '42' | query-json --no-color 'to_string'
  "42"

  $ echo '"Hello, world"' | query-json --no-color 'starts_with("Hello")'
  true

  $ echo '"Hello, world"' | query-json --no-color 'starts_with("boo")'
  false

  $ echo '"Hello, world"' | query-json --no-color 'ends_with("world")'
  true
