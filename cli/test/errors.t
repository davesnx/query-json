Deprecation errors for old function names

tonumber is deprecated
  $ query-json -n --no-color 'tonumber'
  
  error[deprecated]: `tonumber` is deprecated
    --> tonumber
        ^^^^^^^^
  
    hint: use `to_number` instead
  

tostring is deprecated
  $ query-json -n --no-color 'tostring'
  
  error[deprecated]: `tostring` is deprecated
    --> tostring
        ^^^^^^^^
  
    hint: use `to_string` instead
  

startwith is undefined (typo)
  $ query-json --no-color 'startwith("Hello")' '"Hello, world"'
  
  error[undefined_function]: undefined function: `startwith`
  
    hint: check function name or define it with 'fn'
  

startswith is deprecated
  $ query-json -n --no-color 'startswith("Hello")' '"Hello, world"'
  
  error[deprecated]: `startswith` is deprecated
    --> startswith("Hello")
        ^^^^^^^^^^^
  
    hint: use `starts_with` instead
  

endwith is undefined (typo)
  $ query-json -n --no-color 'endwith("world")' '"Hello, world"'
  
  error[undefined_function]: undefined function: `endwith`
  
    hint: check function name or define it with 'fn'
  

endswith is deprecated
  $ query-json -n --no-color 'endswith("world")' '"Hello, world"'
  
  error[deprecated]: `endswith` is deprecated
    --> endswith("world")
        ^^^^^^^^^
  
    hint: use `ends_with` instead
  

isnormal is deprecated
  $ query-json -n --no-color 'isnormal'
  
  error[deprecated]: `isnormal` is deprecated
    --> isnormal
        ^^^^^^^^
  
    hint: use `is_normal` instead
  

trim_left is deprecated
  $ query-json -n --no-color 'trim_left' '" hello "'
  
  error[deprecated]: `trim_left` is deprecated
    --> trim_left
        ^^^^^^^^^
  
    hint: use `trim` instead
  

trim_right is deprecated
  $ query-json -n --no-color 'trim_right' '" hello "'
  
  error[deprecated]: `trim_right` is deprecated
    --> trim_right
        ^^^^^^^^^^
  
    hint: use `trim` instead
  

map without expression
  $ query-json --no-color 'map' '[1,2,3]'
  
  error[missing_argument]: map() requires expr
    --> map
        ^^^
  
    usage: map(expr)
    Transform each element
    applicable to: array
    example: [1, 2, 3] | map(. * 2) → [2, 4, 6]
  

New names work correctly

  $ query-json --no-color 'to_number' '"42"'
  42

  $ query-json --no-color 'to_string' '42'
  "42"

  $ query-json --no-color 'starts_with("Hello")' '"Hello, world"'
  true

  $ query-json --no-color 'starts_with("boo")' '"Hello, world"'
  false

  $ query-json --no-color 'ends_with("world")' '"Hello, world"'
  true

  $ query-json --no-color 'is_normal' '42'
  true

  $ query-json --no-color 'trim' '" hello "'
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
