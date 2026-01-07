# query-json Advanced Usage
# This tape demonstrates advanced queries: reduce, foreach, user functions

Output docs/cli-advanced.gif

Set FontSize 32
Set Width 1200
Set Height 600
Set FontFamily "IBM Plex Mono"
Set CursorBlink false

# Reduce - sum all prices
Type "# Reduce: Sum all book prices"
Enter
Sleep 500ms
Type "query-json 'reduce .second.store.books[].price as $p (0; . + $p)' test/mock.json"
Enter
Sleep 2.5s

# Group by category
Type "# Group books by category"
Enter
Sleep 500ms
Type "query-json '.second.store.books | group_by(.category)' test/mock.json"
Enter
Sleep 2.5s

# User-defined function
Type "# User-defined function"
Enter
Sleep 500ms
Type "query-json 'fn double: . * 2; [1, 2, 3] | map(double)' 'null'"
Enter
Sleep 2.5s

# Complex transformation with select and map
Type "# Filter and transform"
Enter
Sleep 500ms
Type "query-json '.second.store.books | map(select(.price > 10)) | map({title, price})' test/mock.json"
Enter
Sleep 2.5s

# Using foreach for running totals
Type "# Foreach: Running total"
Enter
Sleep 500ms
Type "query-json '[foreach range(5) as $n (0; . + $n; .)]' 'null'"
Enter
Sleep 2.5s

# String interpolation
Type "# String interpolation"
Enter
Sleep 500ms
Type "query-json '.second.store.books[] | \"\\(.title) by \\(.author)\"' test/mock.json"
Enter
Sleep 2.5s

# Recursive descent
Type "# Find all prices recursively"
Enter
Sleep 500ms
Type "query-json '[.. | numbers]' test/mock.json"
Enter
Sleep 2.5s

# Error handling with try-catch
Type "# Error handling"
Enter
Sleep 500ms
Type "query-json 'try .missing.field catch \"not found\"' '{\"data\": 1}'"
Enter
Sleep 2s

Sleep 1s

