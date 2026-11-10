With --stream-output, the result for the first element is printed while the
rest of the input is still open. The writer sends the second element only after
the first result was read, and puts the text it received into it. The watchdog
only ends a hang.

  $ mkfifo in ack
  $ (sleep 60; echo timeout > ack) &
  $ watchdog=$!
  $ { printf '[{"a": 1},\n'; read line < ack; printf '{"a": "%s"}, tru]\n' "$line"; } > in &
  $ query-json -c --stream-output '.[] | .a' < in | { IFS= read -r first; echo "first: $first"; echo ok > ack & cat; }
  first: 1
  "ok"
  
  JSON parse error: Line 2, bytes 13-18:
  Invalid token 'tru]
  '
  
  $ kill $watchdog
