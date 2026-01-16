# query-json vs jq: group_by Behavior
# Shows how group_by returns an object instead of array of arrays

Output docs/jq-compat-demos/05-group-by-behavior.mp4
Require query-json

Set FontSize 28
Set Width 1200
Set Height 700
Set FontFamily "IBM Plex Mono"
Set CursorBlink false

Type "# query-json: group_by Returns an Object"
Enter
Sleep 1s

# Basic group_by difference
Type "# jq returns array of arrays:"
Enter
Sleep 500ms
Type `echo '[{"x":1},{"x":2},{"x":1}]' | jq 'group_by(.x)'`
Enter
Sleep 2.5s

Type "# query-json returns an object:"
Enter
Sleep 500ms
Type `echo '[{"x":1},{"x":2},{"x":1}]' | query-json 'group_by(.x)'`
Enter
Sleep 2.5s

# More practical example
Type "# Practical example: Group users by role"
Enter
Sleep 500ms
Type `echo '[{"name":"Alice","role":"admin"},{"name":"Bob","role":"user"},{"name":"Carol","role":"admin"}]' | query-json 'group_by(.role)'`
Enter
Sleep 3s

# Access groups by key
Type "# Access groups directly by key:"
Enter
Sleep 500ms
Type `echo '[{"name":"Alice","role":"admin"},{"name":"Bob","role":"user"}]' | query-json 'group_by(.role).admin'`
Enter
Sleep 2.5s

# Migrating from jq's structure
Type "# To get jq-style structure:"
Enter
Sleep 500ms
Type `echo '[{"x":1},{"x":2},{"x":1}]' | query-json 'group_by(.x) | to_entries | map({key, items: .value})'`
Enter
Sleep 3s

Sleep 1s

