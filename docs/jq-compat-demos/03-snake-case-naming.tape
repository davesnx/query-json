# query-json vs jq: Snake_case Naming
# Shows the more readable function naming convention

Output docs/jq-compat-demos/03-snake-case-naming.mp4
Require query-json

Set FontSize 28
Set Width 1200
Set Height 700
Set FontFamily "IBM Plex Mono"
Set CursorBlink false

Type "# query-json: Snake_case Function Names"
Enter
Sleep 1s

# Type conversion
Type "# 1. Type conversion"
Enter
Sleep 500ms
Type "# jq: tostring / tonumber"
Enter
Type "echo '42' | jq 'tostring'"
Enter
Sleep 1.5s

Type "# query-json: to_string / to_number"
Enter
Type "echo '42' | query-json 'to_string'"
Enter
Sleep 2s

# String predicates
Type "# 2. String predicates"
Enter
Sleep 500ms
Type "# jq: startswith / endswith"
Enter
Type `echo '"hello world"' | jq 'startswith("hello")'`
Enter
Sleep 1.5s

Type "# query-json: starts_with / ends_with"
Enter
Type `echo '"hello world"' | query-json 'starts_with("hello")'`
Enter
Sleep 2s

# Type checking
Type "# 3. Type checking"
Enter
Sleep 500ms
Type "# jq: isnan"
Enter
Type `echo '"not a number"' | jq 'try tonumber catch nan | isnan'`
Enter
Sleep 2s

Type "# query-json: is_nan"
Enter
Type `query-json 'nan | is_nan' 'null'`
Enter
Sleep 2s

# Emptiness checks
Type "# 4. Emptiness checks"
Enter
Sleep 500ms
Type "# jq: isempty"
Enter
Type `echo '[]' | jq 'isempty(.[])'`
Enter
Sleep 1.5s

Type "# query-json: is_empty"
Enter
Type `echo '[]' | query-json 'is_empty(.[])'`
Enter
Sleep 2s

# Path operations
Type "# 5. Path operations"
Enter
Sleep 500ms
Type "# jq: getpath / setpath"
Enter
Type `echo '{"a":{"b":1}}' | jq 'getpath(["a","b"])'`
Enter
Sleep 1.5s

Type "# query-json: get_path / set_path"
Enter
Type `echo '{"a":{"b":1}}' | query-json 'get_path(["a","b"])'`
Enter
Sleep 2s

Sleep 1s

