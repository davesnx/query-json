# query-json REPL Demo
# This tape demonstrates the interactive REPL with autocomplete

Output docs/repl-demo.gif
Require query-json

Set FontSize 32
Set Width 1200
Set Height 1200
Set FontFamily "IBM Plex Mono"
Set CursorBlink false

# Start the REPL with a sample JSON file
Type "query-json --repl test/mock.json"
Enter
Sleep 2s

# Show the initial state with identity query
Type "."
Sleep 1s

# Navigate through the JSON structure
Type "second.store"
Sleep 1s

# Access nested array
Type ".books"
Sleep 1s

# Access first element
Type "[0]"
Sleep 1s

# Clear and try a more complex query
Ctrl+L
Sleep 500ms

# Use autocomplete - type partial and show completions
Type ".second.store.books | ma"
Sleep 1s

# Complete with map
Type "p"
Sleep 500ms

# Clear and demonstrate function autocomplete
Ctrl+L
Sleep 500ms

Type ".second.store.books | select(.price > 10)"
Sleep 1.5s

# Exit the REPL
Ctrl+C
Sleep 1s

