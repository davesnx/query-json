# query-json: infinite is a Generator
# Shows how infinite produces 0, 1, 2, ... forever

Output docs/jq-compat-demos/08-infinite-generator.mp4
Require query-json

Set FontSize 28
Set Width 1200
Set Height 700
Set FontFamily "IBM Plex Mono"
Set CursorBlink false

Type "# query-json: infinite is a Generator"
Enter
Sleep 1s

# Basic infinite with limit
Type "# Generate first 5 numbers:"
Enter
Sleep 500ms
Type "query-json '[limit(5; infinite)]' 'null'"
Enter
Sleep 2s

# Generate more
Type "# Generate first 10 numbers:"
Enter
Sleep 500ms
Type "query-json '[limit(10; infinite)]' 'null'"
Enter
Sleep 2s

# Use with first
Type "# Get first value:"
Enter
Sleep 500ms
Type "query-json 'first(infinite)' 'null'"
Enter
Sleep 2s

# Use with nth
Type "# Get nth value:"
Enter
Sleep 500ms
Type "query-json 'nth(5; infinite)' 'null'"
Enter
Sleep 2s

# Transform infinite sequence
Type "# Transform the sequence:"
Enter
Sleep 500ms
Type "query-json '[limit(5; infinite) | . * 2]' 'null'"
Enter
Sleep 2s

# Filter infinite sequence
Type "# Filter: first 5 even numbers from infinite:"
Enter
Sleep 500ms
Type "query-json '[limit(5; infinite | select(. % 2 == 0))]' 'null'"
Enter
Sleep 2.5s

Sleep 1s

