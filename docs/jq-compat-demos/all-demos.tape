# query-json: Complete JQ Compatibility Demo
# Shows all major differences and features

Output docs/jq-compat-demos/all-demos.mp4
Require query-json

Set FontSize 26
Set Width 1200
Set Height 700
Set FontFamily "IBM Plex Mono"
Set CursorBlink false

# Title
Type "# query-json vs jq: Complete Compatibility Guide"
Enter
Sleep 1.5s

# Section 1: Error Messages
Type "# === HELPFUL ERROR MESSAGES ==="
Enter
Sleep 500ms
Type `query-json '.naem' '{"name": "Alice", "age": 30}'`
Enter
Sleep 2.5s

# Section 2: Stricter Null Handling
Type "# === STRICTER NULL HANDLING ==="
Enter
Sleep 500ms
Type "# jq silently coerces null:"
Enter
Type "echo 'null' | jq '. + 1'"
Enter
Sleep 1.5s
Type "# query-json catches the bug:"
Enter
Type "echo 'null' | query-json '. + 1'"
Enter
Sleep 2s

# Section 3: fn vs def
Type "# === FN FOR FUNCTIONS (not def) ==="
Enter
Sleep 500ms
Type "echo '[1,2,3]' | query-json 'fn double: . * 2; map(double)'"
Enter
Sleep 2s

# Section 4: Snake case
Type "# === SNAKE_CASE NAMING ==="
Enter
Sleep 500ms
Type `echo '"hello"' | query-json 'to_uppercase'`
Enter
Sleep 1.5s
Type `echo '"hello world"' | query-json 'starts_with("hello")'`
Enter
Sleep 2s

# Section 5: Clearer naming
Type "# === CLEARER NAMES ==="
Enter
Sleep 500ms
Type `echo '"  hello  "' | query-json 'trim'`
Enter
Sleep 1.5s
Type `echo '"hello world"' | query-json 'trim_start("hello ")'`
Enter
Sleep 2s

# Section 6: group_by returns object
Type "# === GROUP_BY RETURNS OBJECT ==="
Enter
Sleep 500ms
Type `echo '[{"x":1},{"x":2},{"x":1}]' | query-json 'group_by(.x)'`
Enter
Sleep 2.5s

# Section 7: keys preserves order
Type "# === KEYS PRESERVES INSERTION ORDER ==="
Enter
Sleep 500ms
Type `echo '{"b":1, "a":2, "c":3}' | query-json 'keys'`
Enter
Sleep 2s

# Section 8: unique preserves order
Type "# === UNIQUE PRESERVES ORDER ==="
Enter
Sleep 500ms
Type "echo '[3, 1, 2, 1, 3, 2]' | query-json 'unique'"
Enter
Sleep 2s

# Section 9: Optional access on functions
Type "# === OPTIONAL ACCESS ON FUNCTIONS ==="
Enter
Sleep 500ms
Type `query-json 'first?' '[]'`
Enter
Sleep 1.5s
Type `query-json 'keys?' '123'`
Enter
Sleep 2s

# Section 10: Additional features
Type "# === ADDITIONAL FEATURES ==="
Enter
Sleep 500ms
Type `echo '[1,2,3,4,5]' | query-json 'filter(. > 2)'`
Enter
Sleep 1.5s
Type `echo '[{"id":1},{"id":2}]' | query-json 'find(.id == 2)'`
Enter
Sleep 1.5s
Type `echo '[{"name":"Alice"},{"name":"Bob"}]' | query-json 'pluck(.name)'`
Enter
Sleep 2s

Sleep 1s

