A root `.[] | f` on an array runs `f` on one element at a time. By default
nothing is printed before the whole input is read, so the output is the same
as for any other query.

  $ query-json -c '.[] | .a' '[{"a": 1}, {"a": [2]}, {"a": "x"}]'
  1
  [ 2 ]
  "x"
  $ query-json -c -r '.[] | .a' '[{"a": 1}, {"a": "x"}]'
  1
  x
  $ query-json -c -d '.[] | .a' '[{"a": 1}]'
  (Pipe ((Pipe (Identity, (Index []))), (Key "a")))
  1
  $ query-json '.[] | {a: .a}' '[{"a": 1, "b": 2}]'
  { "a": 1 }
  $ query-json -c '.[]' '[]'
  
  $ query-json -c '.[] | empty' '[1, 2]'
  
  $ query-json -c '.[] | .a' '{"a": 1}'
  
  error[type_mismatch]: Cannot index number with string "a"
  
    in: 1
  
  $ query-json -c '.[] | .a' '[{"a": 1}, {"a": 2}, tru]'
  
  JSON parse error: Line 1, bytes 21-25:
  Invalid token 'tru]'
  
  $ query-json -c '.[] | .a' '[{"a": 1}, 2, {"a": 3}]'
  
  error[type_mismatch]: Cannot index number with string "a"
  
    in: 2
  
  $ query-json -c '.[] | .a' '[{"a": 1}, 2, tru]'
  
  JSON parse error: Line 1, bytes 14-18:
  Invalid token 'tru]'
  
  $ query-json -c '.[] | if .a == 2 then halt_error(5) else .a end' '[{"a": 1}, {"a": 2}, {"a": 3}]'
  [5]
  $ query-json -c '.[] | if .a == 2 then halt_error(5) else .a end' '[{"a": 1}, {"a": 2}, tru]'
  
  JSON parse error: Line 1, bytes 21-25:
  Invalid token 'tru]'
  

A root `.`, `map(f)` or `[.[] | f]` on an array is also read one element at a
time. The output is the same array.

  $ query-json -c '.[] | 1' '[1, 2]'
  1
  1
  $ query-json -c 'map(1)' '[1, 2]'
  [ 1, 1 ]
  $ query-json -c 'map(.a)' '[{"a": 1}, {"a": [2]}]'
  [ 1, [ 2 ] ]
  $ query-json -c '.' '[{"a": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"}, [1, {"b": 2}], []]'
  [
    {
      "a": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
    },
    [
      1,
      {
        "b": 2
      }
    ],
    []
  ]
  $ query-json -c 'map(.a)' '[{"a": 1}, 2, tru]'
  
  JSON parse error: Line 1, bytes 14-18:
  Invalid token 'tru]'
  

With --stream-output, the results of each element are printed when they are
ready. An error found later follows them. The first query error or halt ends
the run: the rest of the input is not read.

  $ query-json -c --stream-output '.[] | .a' '[{"a": 1}, {"a": [2]}, {"a": "x"}]'
  1
  [ 2 ]
  "x"
  $ query-json -c --stream-output '.[] | empty' '[1, 2]'
  
  $ query-json -c --stream-output '.[] | .a' '[{"a": 1}, {"a": 2}, tru]'
  1
  2
  
  JSON parse error: Line 1, bytes 21-25:
  Invalid token 'tru]'
  
  $ query-json -c --stream-output '.[] | .a' '[{"a": 1}, 2, {"a": 3}]'
  1
  
  error[type_mismatch]: Cannot index number with string "a"
  
    in: 2
  
  $ query-json -c --stream-output '.[] | if .a == 2 then halt_error(5) else .a end' '[{"a": 1}, {"a": 2}, {"a": 3}]'
  1
  [5]
  $ query-json -c --stream-output '.[] | .a' '[{"a": 1}, 2, tru]'
  1
  
  error[type_mismatch]: Cannot index number with string "a"
  
    in: 2
  
  $ query-json -c --stream-output '.[] | if .a == 2 then halt_error(5) else .a end' '[{"a": 1}, {"a": 2}, tru]'
  1
  [5]
  $ query-json -c --stream-output -d '.[] | .a' '[{"a": 1}, {"a": 2}]'
  (Pipe ((Pipe (Identity, (Index []))), (Key "a")))
  1
  2
  $ query-json -c --stream-output '.a' '{"a": 1}'
  1
  $ query-json | grep stream-output
     --stream-output: Print each result as soon as it is ready
