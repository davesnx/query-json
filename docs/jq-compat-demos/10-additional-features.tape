# query-json: Additional Features Not in jq
# Shows functions unique to query-json

Output docs/jq-compat-demos/10-additional-features.mp4
Require query-json

Set FontSize 28
Set Width 1200
Set Height 700
Set FontFamily "IBM Plex Mono"
Set CursorBlink false

Type "# query-json: Additional Features"
Enter
Sleep 1s

# filter - alias for map(select())
Type "# filter(expr) - alias for map(select(expr))"
Enter
Sleep 500ms
Type `echo '[1,2,3,4,5]' | query-json 'filter(. > 2)'`
Enter
Sleep 2s

# flat_map
Type "# flat_map(expr) - map and flatten"
Enter
Sleep 500ms
Type `echo '[[1,2],[3,4]]' | query-json 'flat_map(. | map(. * 2))'`
Enter
Sleep 2s

# find
Type "# find(expr) - first matching element"
Enter
Sleep 500ms
Type `echo '[{"id":1,"name":"Alice"},{"id":2,"name":"Bob"}]' | query-json 'find(.id == 2)'`
Enter
Sleep 2.5s

# some
Type "# some(expr) - check if any element matches"
Enter
Sleep 500ms
Type `echo '[{"price":50},{"price":150}]' | query-json 'some(.price > 100)'`
Enter
Sleep 2s

# pluck
Type "# pluck(expr) - extract field from array"
Enter
Sleep 500ms
Type `echo '[{"name":"Alice"},{"name":"Bob"}]' | query-json 'pluck(.name)'`
Enter
Sleep 2s

# partition
Type "# partition(expr) - split into matching/non-matching"
Enter
Sleep 500ms
Type `echo '[1,2,3,4,5]' | query-json 'partition(. > 2)'`
Enter
Sleep 2.5s

# is_empty
Type "# is_empty - check if empty"
Enter
Sleep 500ms
Type `echo '[]' | query-json 'is_empty'`
Enter
Sleep 1.5s
Type `echo '[1]' | query-json 'is_empty'`
Enter
Sleep 2s

# is_blank
Type "# is_blank - null, empty, or whitespace"
Enter
Sleep 500ms
Type `echo '"  "' | query-json 'is_blank'`
Enter
Sleep 1.5s
Type `echo '""' | query-json 'is_blank'`
Enter
Sleep 2s

Sleep 1s

