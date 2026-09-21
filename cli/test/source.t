Root and member cuts drain both residual outputs while the input pipe stays open.

  $ ./stream_probe.exe "$(command -v query-json)"
  root: before EOF "1\n11\n"; final "1\n11\n2\n12\n"; exit 0
  member: before EOF "1\n11\n"; final "1\n11\n2\n12\n"; exit 0
  raw: before EOF "\n"; final "\n\n"; exit 0

Selected and fallback queries give the same bytes for string, file, and channel input.

  $ json='{"keep":[{"value":1},{"value":2}],"discard":[3,4]}'
  $ printf '%s' "$json" > source.json
  $ printf '1\n2\n' > expected.out
  $ for mode in '' '--stream-output'; do
  >   for query in '.keep[] | .value' 'fn chosen: .keep[] | .value; chosen'; do
  >     query-json --no-color $mode "$query" "$json" > string.out
  >     query-json --no-color $mode "$query" source.json > file.out
  >     query-json --no-color $mode "$query" < source.json > channel.out
  >     cmp expected.out string.out || exit 1
  >     cmp expected.out file.out || exit 1
  >     cmp expected.out channel.out || exit 1
  >   done
  > done

An existing filename takes precedence over inline JSON.

  $ printf '{"keep":42}' > null
  $ query-json --no-color '.keep' null
  42

Null input skips invalid inline and channel input in both output modes.

  $ for mode in '' '--stream-output'; do
  >   query-json --no-color $mode --null-input '.' '{' < source.json
  > done
  null
  null

Raw and empty selected results preserve output bytes in both modes and backends.

  $ for json in '{"keep":[]}' '{"keep":[""]}' '{"keep":["","a\nb","","\n",""]}'; do
  >   for raw in '' '-r'; do
  >     query-json --no-color $raw 'fn chosen: .keep[]; chosen' "$json" > expected.out
  >     for mode in '' '--stream-output'; do
  >       query-json --no-color $mode $raw '.keep[]' "$json" > selected.out
  >       cmp expected.out selected.out || exit 1
  >     done
  >   done
  > done

Invalid JSON wins over an invalid query for every source and output mode.
Debug output must not appear.

  $ json='{"keep":[1,2],"discard":[}'
  $ printf '%s' "$json" > invalid.json
  $ query-json --no-color '.' "$json" > input-error.out
  $ cat input-error.out
  
  JSON parse error: Line 1, bytes 25-26:
  Invalid token '}'
  
  $ for mode in '' '--stream-output'; do
  >   query-json --no-color --debug $mode '[' "$json" > string.out
  >   query-json --no-color --debug $mode '[' invalid.json > file.out
  >   query-json --no-color --debug $mode '[' < invalid.json > channel.out
  >   cmp input-error.out string.out || exit 1
  >   cmp input-error.out file.out || exit 1
  >   cmp input-error.out channel.out || exit 1
  > done

Valid input returns the saved query error in both modes.

  $ query-json --no-color --debug '[' source.json
  
  error[parse_error]: unexpected token, got end of input
    --> [
        ^
  
  $ query-json --no-color --debug --stream-output '[' source.json
  
  error[parse_error]: unexpected token, got end of input
    --> [
        ^
  

Debug prints the original AST once before execution, even when input is selected.

  $ query-json --no-color --debug '.keep[]' '{"keep":[1,2],"discard":[9]}'
  (Pipe ((Key "keep"), (Index [])))
  1
  2
  $ query-json --no-color --debug --stream-output '.keep[]' '{"keep":[1,2],"discard":[9]}'
  (Pipe ((Key "keep"), (Index [])))
  1
  2

Selected input remains atomic by default on a late execution error.

  $ query-json --no-color '.keep[] | .value' '{"keep":[{"value":1},{}],"discard":true}' | sed '/^$/d'
  error[key_not_found]: Key 'value' not found in object
    in: {}
    hint: Use .value? for optional access

Streamed selected input keeps results before a late execution error.

  $ query-json --no-color --stream-output '.keep[] | .value' '{"keep":[{"value":1},{}],"discard":true}' | sed '/^$/d'
  1
  error[key_not_found]: Key 'value' not found in object
    in: {}
    hint: Use .value? for optional access

Fallback execution has the same atomic and streamed errors.

  $ for mode in '' '--stream-output'; do
  >   json='{"keep":[{"value":1},{}],"discard":true}'
  >   query-json --no-color $mode '.keep[] | .value' "$json" > selected.out
  >   query-json --no-color $mode 'fn chosen: .keep[] | .value; chosen' "$json" > fallback.out
  >   cmp selected.out fallback.out || exit 1
  > done

Halt preserves its exit code and the output policy of each mode.

  $ query-json --no-color '1, halt_error(7), 2' 'null'
  [7]
  $ query-json --no-color --stream-output '1, halt_error(7), 2' 'null'
  1
  [7]

Malformed discarded values and trailing bytes fail before AST or result output.
Their errors match full-input parsing, including when the query is invalid.

  $ for json in '{"keep":[1,2],"discard":[}' '{"keep":[1,2],"discard":"\q"}' '{"keep":[1,2],"discard":"\uD800"}' '{"keep":[1,2],"discard":1e}' '{"keep":[1,2]} trailing'; do
  >   printf '%s' "$json" > invalid.json
  >   query-json --no-color '.' "$json" > input-error.out
  >   grep -q 'JSON parse error:' input-error.out || exit 1
  >   for mode in '' '--stream-output'; do
  >     for query in '.keep[]' 'fn chosen: .keep[]; chosen' '['; do
  >       query-json --no-color --debug $mode "$query" "$json" > string.out
  >       query-json --no-color --debug $mode "$query" invalid.json > file.out
  >       query-json --no-color --debug $mode "$query" < invalid.json > channel.out
  >       cmp input-error.out string.out || exit 1
  >       cmp input-error.out file.out || exit 1
  >       cmp input-error.out channel.out || exit 1
  >     done
  >   done
  > done
