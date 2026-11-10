Queries read only the parts of the input they use. Output and errors stay the same.

  $ query-json -c '.first.pages | map(.id)' mock.json
  [ 1, 2, 3, 4 ]
  $ cat mock.json | query-json -c '.first.pages[] | .title'
  
  error[key_not_found]: Key 'title' not found in object
  
    in: { "id": ..., "deleted": ... }
    hint: Use .title? for optional access
  
  $ query-json -c '.[] | .a' '[{"a": 1, "b": [tru]}]'
  
  JSON parse error: Line 1, bytes 16-22:
  Invalid token 'tru]}]'
  
  $ query-json -c '.[] | .a' '[{"a": 1, "b": "\q"}]'
  
  JSON parse error: Line 1, bytes 17-21:
  Invalid escape sequence 'q"}]'
  
  $ query-json -c '.a +' '{"b": [tru]}'
  
  JSON parse error: Line 1, bytes 7-12:
  Invalid token 'tru]}'
  
  $ query-json -c '.a +' '{"b": 1}'
  
  error[parse_error]: unexpected token, got end of input
    --> .a +
           ^
  
  $ query-json -c '.a' '{"b": {"c": 1}, "a-x": 2}'
  
  error[key_not_found]: Key 'a' not found in object
  
    in: { "b": ..., "a-x": ... }
    hint: Did you mean "a-x"? Use .["..."] or ."..." for keys with hyphens
  
  $ query-json -c -d '.a' '{"a": 1, "b": 2}'
  (Key "a")
  1
  $ query-json -c '1' '{"b": 2'
  
  JSON parse error: Line 1, bytes 6-7:
  Unexpected end of input
  
