# query-json vs jq: unique Preserves Insertion Order
# Shows how unique returns first occurrences in order

Output docs/jq-compat-demos/07-unique-insertion-order.mp4
Require query-json

Set FontSize 28
Set Width 1200
Set Height 700
Set FontFamily "IBM Plex Mono"
Set CursorBlink false

Type "# query-json: unique Preserves Insertion Order"
Enter
Sleep 1s

# Basic unique difference
Type "# jq sorts the result:"
Enter
Sleep 500ms
Type "echo '[3, 1, 2, 1, 3, 2]' | jq 'unique'"
Enter
Sleep 2s

Type "# query-json preserves insertion order:"
Enter
Sleep 500ms
Type "echo '[3, 1, 2, 1, 3, 2]' | query-json 'unique'"
Enter
Sleep 2s

# With strings
Type "# With strings:"
Enter
Sleep 500ms
Type `echo '["banana", "apple", "cherry", "apple", "banana"]' | jq 'unique'`
Enter
Sleep 2s

Type `echo '["banana", "apple", "cherry", "apple", "banana"]' | query-json 'unique'`
Enter
Sleep 2s

# If you need sorted unique
Type "# If you need sorted unique in query-json:"
Enter
Sleep 500ms
Type "echo '[3, 1, 2, 1, 3, 2]' | query-json 'unique | sort'"
Enter
Sleep 2s

# unique_by also preserves order
Type "# unique_by also preserves order:"
Enter
Sleep 500ms
Type `echo '[{"name":"Bob","id":1},{"name":"Alice","id":2},{"name":"Bob","id":3}]' | query-json 'unique_by(.name)'`
Enter
Sleep 2.5s

Sleep 1s

