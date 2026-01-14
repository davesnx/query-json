Deprecation errors for old function names

tonumber is deprecated
  $ echo '"42"' | query-json --no-color 'tonumber'
  
  error[deprecated]: `tonumber` is deprecated
    --> tonumber
        ^
  
    hint: use `to_number` instead
  

tostring is deprecated
  $ echo '42' | query-json --no-color 'tostring'
  
  error[deprecated]: `tostring` is deprecated
    --> tostring
        ^
  
    hint: use `to_string` instead
  

startwith is undefined (typo)
  $ echo '"Hello, world"' | query-json --no-color 'startwith("Hello")'
  
  error[undefined_function]: undefined function: `startwith`
  
    hint: check function name or define it with 'fn'
  

startswith is deprecated
  $ echo '"Hello, world"' | query-json --no-color 'startswith("Hello")'
  
  error[deprecated]: `startswith` is deprecated
    --> startswith("Hello")
                  ^
  
    hint: use `starts_with` instead
  

endwith is undefined (typo)
  $ echo '"Hello, world"' | query-json --no-color 'endwith("world")'
  
  error[undefined_function]: undefined function: `endwith`
  
    hint: check function name or define it with 'fn'
  

endswith is deprecated
  $ echo '"Hello, world"' | query-json --no-color 'endswith("world")'
  
  error[deprecated]: `endswith` is deprecated
    --> endswith("world")
                ^
  
    hint: use `ends_with` instead
  

isnormal is deprecated
  $ echo '42' | query-json --no-color 'isnormal'
  
  error[deprecated]: `isnormal` is deprecated
    --> isnormal
        ^
  
    hint: use `is_normal` instead
  

trim_left is deprecated
  $ echo '" hello "' | query-json --no-color 'trim_left'
  
  error[deprecated]: `trim_left` is deprecated
    --> trim_left
        ^
  
    hint: use `trim` instead
  

trim_right is deprecated
  $ echo '" hello "' | query-json --no-color 'trim_right'
  
  error[deprecated]: `trim_right` is deprecated
    --> trim_right
        ^
  
    hint: use `trim` instead
  

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

  $ echo '42' | query-json --no-color 'is_normal'
  true

  $ echo '" hello "' | query-json --no-color 'trim'
  "hello"

Hyphenated keys should suggest quoted syntax

  $ echo '{"vite-plugin-monaco-editor": "1.0.0"}' | query-json --no-color '.vite-plugin-monaco-editor'
  
  error[key_not_found]: Key 'vite' not found in object
  
    in: { "vite-plugin-monaco-editor": ... }
    hint: Did you mean "vite-plugin-monaco-editor"? Use .["..."] or ."..." for keys with hyphens
  

Non-hyphenated key miss shows original hint

  $ echo '{"foo": 1}' | query-json --no-color '.bar'
  
  error[key_not_found]: Key 'bar' not found in object
  
    in: { "foo": ... }
    hint: Use .bar? for optional access
  

Quoted syntax works for hyphenated keys

  $ echo '{"vite-plugin-monaco-editor": "1.0.0"}' | query-json --no-color '.["vite-plugin-monaco-editor"]'
  "1.0.0"

  $ echo '{"vite-plugin-monaco-editor": "1.0.0"}' | query-json --no-color '."vite-plugin-monaco-editor"'
  "1.0.0"
