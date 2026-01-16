# query-json vs jq: keys Preserves Insertion Order
# Shows how keys returns insertion order instead of sorted

Output docs/jq-compat-demos/06-keys-insertion-order.mp4
Require query-json

Set FontSize 28
Set Width 1200
Set Height 700
Set FontFamily "IBM Plex Mono"
Set CursorBlink false

Type "# query-json: keys Preserves Insertion Order"
Enter
Sleep 1s

# Basic keys difference
Type "# jq returns sorted keys:"
Enter
Sleep 500ms
Type `echo '{"b":1, "a":2, "c":3}' | jq 'keys'`
Enter
Sleep 2s

Type "# query-json preserves insertion order:"
Enter
Sleep 500ms
Type `echo '{"b":1, "a":2, "c":3}' | query-json 'keys'`
Enter
Sleep 2s

# jq's keys_unsorted equivalent
Type "# jq requires keys_unsorted for insertion order"
Enter
Sleep 500ms
Type `echo '{"z":1, "m":2, "a":3}' | jq 'keys_unsorted'`
Enter
Sleep 2s

Type "# query-json: just use keys"
Enter
Sleep 500ms
Type `echo '{"z":1, "m":2, "a":3}' | query-json 'keys'`
Enter
Sleep 2s

# If you need sorted keys
Type "# If you need sorted keys in query-json:"
Enter
Sleep 500ms
Type `echo '{"b":1, "a":2, "c":3}' | query-json 'keys | sort'`
Enter
Sleep 2s

Sleep 1s

