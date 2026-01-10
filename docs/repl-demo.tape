# query-json REPL Demo
# This tape demonstrates the interactive REPL with autocomplete

Output docs/repl-demo.mp4
Require query-json

Set Padding 8
Set Margin 0
Set FontSize 18
Set Width 1200
Set Height 900
Set FontFamily "IBM Plex Mono"
Set Framerate 60

# Start the REPL with a sample JSON file
Type "query-json --repl test/mock.json"
Enter
Sleep 3s

# Clear the initial query
Backspace 1

# Show the structure of the json
Type "keys"
Sleep 2s
Backspace 4

# Navigate through the JSON structure
Type ".second.store"
Sleep 2s

# Access nested array
Type ".books"
Sleep 2s

# Access first element
Type "[0]"
Sleep 2s

# Clear and try a more complex query
Backspace 3
Sleep 1s

# Use autocomplete - type partial and show completions
Type " | ma"
Sleep 2s

# Complete with map
Type "p"
Sleep 1s

# Mapping stuff
Type "(.price * 77)"
Sleep 1s

# Clear and demonstrate function autocomplete
Backspace 17
Sleep 1s

Type " select(.price > 10)"
Sleep 2.5s

# Exit the REPL
Ctrl+C
Sleep 1s

