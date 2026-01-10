# query-json Basic CLI Usage
# This tape demonstrates basic CLI operations

Output docs/cli-basic.mp4
Require query-json

Set FontSize 32
Set Width 1200
Set Height 600
Set FontFamily "IBM Plex Mono"
Set CursorBlink false

# Show version
Type "query-json --version"
Enter
Sleep 1.5s

# Query a file directly
Type "# Query a JSON file"
Enter
Sleep 500ms
Type "query-json '.second.store.books[0].title' test/mock.json"
Enter
Sleep 2s

# Query from stdin using pipe
Type "# Query from stdin"
Enter
Sleep 500ms
Type "cat test/mock.json | query-json '.second.store.books | length'"
Enter
Sleep 2s

# Query inline JSON
Type "# Query inline JSON"
Enter
Sleep 500ms
Type `query-json '.users | map(.name)' '{"users": [{"name": "Alice"}, {"name": "Bob"}]}'`
Enter
Sleep 2s

# Raw output mode
Type "# Raw output (no quotes around strings)"
Enter
Sleep 500ms
Type "query-json -r '.second.store.books[0].author' test/mock.json"
Enter
Sleep 2s

# Multiple outputs
Type "# Multiple outputs"
Enter
Sleep 500ms
Type "query-json '.second.store.books[] | .title' test/mock.json"
Enter
Sleep 2s

# Get keys from an object
Type "# Get object keys"
Enter
Sleep 500ms
Type `query-json 'keys' '{"a": 1, "b": 2, "c": 3}'`
Enter
Sleep 2s

Sleep 1s

