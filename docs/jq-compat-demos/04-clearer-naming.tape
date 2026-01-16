# query-json vs jq: Clearer Naming
# Shows self-explanatory function names

Output docs/jq-compat-demos/04-clearer-naming.mp4
Require query-json

Set FontSize 28
Set Width 1200
Set Height 700
Set FontFamily "IBM Plex Mono"
Set CursorBlink false

Type "# query-json: Clearer Function Names"
Enter
Sleep 1s

# Case conversion
Type "# 1. Case conversion"
Enter
Sleep 500ms
Type "# jq: ascii_upcase / ascii_downcase"
Enter
Type `echo '"Hello World"' | jq 'ascii_upcase'`
Enter
Sleep 1.5s

Type "# query-json: to_uppercase / to_lowercase"
Enter
Type `echo '"Hello World"' | query-json 'to_uppercase'`
Enter
Sleep 2s

# String trimming
Type "# 2. String trimming"
Enter
Sleep 500ms
Type "# jq: ltrimstr / rtrimstr (l=left, r=right)"
Enter
Type `echo '"hello world"' | jq 'ltrimstr("hello ")'`
Enter
Sleep 1.5s

Type "# query-json: trim_start / trim_end"
Enter
Type `echo '"hello world"' | query-json 'trim_start("hello ")'`
Enter
Sleep 2s

Type `echo '"hello world"' | query-json 'trim_end(" world")'`
Enter
Sleep 2s

# Byte length
Type "# 3. Byte length"
Enter
Sleep 500ms
Type "# jq: utf8bytelength"
Enter
Type `echo '"café"' | jq 'utf8bytelength'`
Enter
Sleep 1.5s

Type "# query-json: byte_length"
Enter
Type `echo '"café"' | query-json 'byte_length'`
Enter
Sleep 2s

# Combined example
Type "# 4. Combined: A real-world example"
Enter
Sleep 500ms
Type "# jq:"
Enter
Type `echo '{"name":"john doe"}' | jq '.name | ascii_upcase | startswith("JOHN")'`
Enter
Sleep 2s

Type "# query-json:"
Enter
Type `echo '{"name":"john doe"}' | query-json '.name | to_uppercase | starts_with("JOHN")'`
Enter
Sleep 2s

Sleep 1s

