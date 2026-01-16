# query-json: Optional Access on Functions
# Shows how ? works on function calls, not just field access

Output docs/jq-compat-demos/09-optional-access-functions.mp4
Require query-json

Set FontSize 28
Set Width 1200
Set Height 700
Set FontFamily "IBM Plex Mono"
Set CursorBlink false

Type "# query-json: Optional Access on Functions"
Enter
Sleep 1s

Type "# In jq, ? only works on field access and indexing"
Enter
Type "# In query-json, ? works on ANY expression!"
Enter
Sleep 1.5s

# first? on empty array
Type "# Optional first on empty array:"
Enter
Sleep 500ms
Type `query-json 'first?' '[]'`
Enter
Sleep 2s

# keys? on non-object
Type "# Optional keys on non-object:"
Enter
Sleep 500ms
Type `query-json 'keys?' '123'`
Enter
Sleep 2s

# nth? out of bounds
Type "# Optional nth out of bounds:"
Enter
Sleep 500ms
Type `query-json 'nth(10)?' '[1,2,3]'`
Enter
Sleep 2s

# first? with empty generator
Type "# Optional first with empty generator:"
Enter
Sleep 500ms
Type `query-json 'first?(empty)' 'null'`
Enter
Sleep 2s

# Both syntaxes work
Type "# Both syntaxes work:"
Enter
Sleep 500ms
Type `query-json 'first?(range(3))' 'null'`
Enter
Sleep 1.5s
Type `query-json 'first(range(3))?' 'null'`
Enter
Sleep 2s

# Practical use case
Type "# Practical: Safe array access"
Enter
Sleep 500ms
Type `query-json '.users | first? // "no users"' '{"users": []}'`
Enter
Sleep 2s

Sleep 1s

