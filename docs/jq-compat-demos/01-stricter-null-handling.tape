# query-json vs jq: Stricter Null Handling
# Demonstrates how query-json catches null-related bugs early

Output docs/jq-compat-demos/01-stricter-null-handling.mp4
Require query-json

Set FontSize 28
Set Width 1200
Set Height 700
Set FontFamily "IBM Plex Mono"
Set CursorBlink false

Type "# query-json: Stricter Null Handling"
Enter
Sleep 1s

# Null arithmetic comparison
Type "# 1. Null arithmetic"
Enter
Sleep 500ms
Type "# jq silently coerces null to 0:"
Enter
Type "echo 'null' | jq '. + 1'"
Enter
Sleep 2s

Type "# query-json raises an error:"
Enter
Type "echo 'null' | query-json '. + 1'"
Enter
Sleep 2.5s

# Null key access comparison
Type "# 2. Null key access"
Enter
Sleep 500ms
Type "# jq silently returns null:"
Enter
Type `echo '{"a": null}' | jq '.a.b.c'`
Enter
Sleep 2s

Type "# query-json tells you what happened:"
Enter
Type `echo '{"a": null}' | query-json '.a.b'`
Enter
Sleep 2.5s

# Optional access when null is expected
Type "# 3. Use ? for optional access"
Enter
Sleep 500ms
Type "# Optional access returns null without error:"
Enter
Type `query-json '.missing?' '{"name": "Alice"}'`
Enter
Sleep 2s

Type `query-json '.a.b?' '{"a": null}'`
Enter
Sleep 2s

# Try-catch for complex error handling
Type "# 4. Try-catch for complex error handling"
Enter
Sleep 500ms
Type `query-json 'try .foo.bar catch "not found"' '{"other": 1}'`
Enter
Sleep 2s

Sleep 1s

