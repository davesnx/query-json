# query-json vs jq: Function Definition Syntax
# Shows fn keyword instead of def

Output docs/jq-compat-demos/02-fn-vs-def.mp4
Require query-json

Set FontSize 28
Set Width 1200
Set Height 700
Set FontFamily "IBM Plex Mono"
Set CursorBlink false

Type "# query-json: fn for User-Defined Functions"
Enter
Sleep 1s

# Basic function definition
Type "# jq uses 'def':"
Enter
Sleep 500ms
Type "echo '[1,2,3]' | jq 'def double: . * 2; map(double)'"
Enter
Sleep 2s

Type "# query-json uses 'fn':"
Enter
Sleep 500ms
Type "echo '[1,2,3]' | query-json 'fn double: . * 2; map(double)'"
Enter
Sleep 2s

# Function with arguments
Type "# Function with arguments"
Enter
Sleep 500ms
Type "# jq:"
Enter
Type `echo '[1,2,3]' | jq 'def add_n(n): . + n; map(add_n(10))'`
Enter
Sleep 2s

Type "# query-json:"
Enter
Type `echo '[1,2,3]' | query-json 'fn add_n(n): . + n; map(add_n(10))'`
Enter
Sleep 2s

# Recursive function
Type "# Recursive function (factorial)"
Enter
Sleep 500ms
Type `query-json 'fn fact: if . <= 1 then 1 else . * ((. - 1) | fact) end; 5 | fact' 'null'`
Enter
Sleep 2.5s

# Multiple functions
Type "# Multiple functions"
Enter
Sleep 500ms
Type `query-json 'fn square: . * .; fn sum_of_squares: map(square) | add; [1,2,3,4] | sum_of_squares' 'null'`
Enter
Sleep 2.5s

Sleep 1s

