# query-json vs jq Comparison
# Side-by-side comparison showing syntax differences

Output docs/comparison.gif
Require query-json

Set FontSize 32
Set Width 1200
Set Height 600
Set FontFamily "IBM Plex Mono"
Set CursorBlink false

# Introduction
Type "# query-json vs jq: Syntax Comparison"
Enter
Sleep 1s

# Snake case function names
Type "# 1. Snake_case function names"
Enter
Sleep 500ms
Type "# jq:"
Enter
Type "echo '\"hello\"' | jq 'ascii_upcase'"
Enter
Sleep 1.5s

Type "# query-json:"
Enter
Type "echo '\"hello\"' | query-json 'to_uppercase'"
Enter
Sleep 2s

# String functions
Type "# 2. String prefix/suffix checking"
Enter
Sleep 500ms
Type "# jq:"
Enter
Type "echo '\"hello world\"' | jq 'startswith(\"hello\")'"
Enter
Sleep 1.5s

Type "# query-json:"
Enter
Type "echo '\"hello world\"' | query-json 'starts_with(\"hello\")'"
Enter
Sleep 2s

# Type conversion
Type "# 3. Type conversion"
Enter
Sleep 500ms
Type "# jq:"
Enter
Type "echo '42' | jq 'tostring'"
Enter
Sleep 1.5s

Type "# query-json:"
Enter
Type "echo '42' | query-json 'to_string'"
Enter
Sleep 2s

# User-defined functions
Type "# 4. User-defined functions"
Enter
Sleep 500ms
Type "# jq uses 'def':"
Enter
Type "echo '[1,2,3]' | jq 'def double: . * 2; map(double)'"
Enter
Sleep 1.5s

Type "# query-json uses 'fn':"
Enter
Type "echo '[1,2,3]' | query-json 'fn double: . * 2; map(double)'"
Enter
Sleep 2s

# group_by behavior
Type "# 5. group_by returns object (not array of arrays)"
Enter
Sleep 500ms
Type "# jq returns array of arrays:"
Enter
Type "echo '[{\"x\":1},{\"x\":2},{\"x\":1}]' | jq 'group_by(.x)'"
Enter
Sleep 1.5s

Type "# query-json returns object:"
Enter
Type "echo '[{\"x\":1},{\"x\":2},{\"x\":1}]' | query-json 'group_by(.x)'"
Enter
Sleep 2s

# Performance comparison hint
Type "# query-json is typically 2-4x faster than jq!"
Enter
Sleep 2s

Sleep 1s

