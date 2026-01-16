# query-json: Helpful Error Messages
# Shows how query-json gives context and hints

Output docs/jq-compat-demos/00-error-messages.mp4
Require query-json

Set FontSize 24
Set Width 1200
Set Height 800
Set FontFamily "IBM Plex Mono"
Set CursorBlink false

Type "# query-json: Helpful Error Messages"
Enter
Sleep 1s

# Missing key with suggestions
Type "# 1. Missing key with suggestions"
Enter
Sleep 500ms
Type `query-json '.naem' '{"name": "Alice", "age": 30}'`
Enter
Sleep 3s

# Type mismatch
Type "# 2. Type mismatch with context"
Enter
Sleep 500ms
Type `query-json '.age | length' '{"name": "Alice", "age": 30}'`
Enter
Sleep 3s

# Index out of bounds
Type "# 3. Index out of bounds"
Enter
Sleep 500ms
Type `query-json '.[10]' '[1, 2, 3]'`
Enter
Sleep 3s

# Missing function argument
Type "# 4. Missing function argument"
Enter
Sleep 500ms
Type `echo '[1,2,3]' | query-json 'map'`
Enter
Sleep 3s

# Null access
Type "# 5. Null access"
Enter
Sleep 500ms
Type `query-json '.missing.name' '{"other": 1}'`
Enter
Sleep 3s

# Parse error
Type "# 6. Parse error with location"
Enter
Sleep 500ms
Type `query-json '{name: .foo}' '{"foo": 1}'`
Enter
Sleep 3s

Sleep 1s

