--functions with no argument lists all categories

  $ query-json --no-color --functions 2>&1 | head -20
  
  Available help categories:
  
   string - String manipulation functions
   array - Array manipulation functions
   object - Object manipulation functions
   path - Path and traversal functions
   math - Mathematical functions
   type - Type checking and conversion functions
   control - Control flow and iteration functions
   definition - Function definition syntax
   date - Date and time functions
   debug - Debugging and inspection functions
  
  Usage: query-json --functions <category>
  Example: query-json --functions string
  

--functions string shows string functions

  $ query-json --no-color --functions string 2>&1 | head -15
  
  String manipulation functions
  
   split - Split string by separator
    "a,b,c" | split(",") → ["a", "b", "c"]
   join - Join array elements with separator
    ["a", "b"] | join(",") → "a,b"
   trim - Remove whitespace from both ends
    "  hello  " | trim → "hello"
   trim_start - Remove prefix string
    "foobar" | trim_start("foo") → "bar"
   trim_end - Remove suffix string
    "foobar" | trim_end("bar") → "foo"
   starts_with - Check if string starts with prefix
    "hello" | starts_with("he") → true

--functions array shows array functions

  $ query-json --no-color --functions array 2>&1 | head -15
  
  Array manipulation functions
  
   map - Transform each element
    [1, 2, 3] | map(. * 2) → [2, 4, 6]
   select - Select elements matching condition
    [1, 2, 3] | map(select(. > 1)) → [2, 3]
   sort - Sort array
    [3, 1, 2] | sort → [1, 2, 3]
   sort_by - Sort by expression result
    [{a:2}, {a:1}] | sort_by(.a) → [{a:1}, {a:2}]
   group_by - Group elements by expression result
    [{x:1}, {x:2}, {x:1}] | group_by(.x) → {"1": [...], "2": [...]}
   unique - Remove duplicate elements
    [1, 2, 1, 3] | unique → [1, 2, 3]

--functions object shows object functions

  $ query-json --no-color --functions object 2>&1 | head -15
  
  Object manipulation functions
  
   keys - Get array of keys in original order
    {b:1, a:2} | keys → ["b", "a"]
   has - Check if key exists
    {a:1} | has("a") → true
   in - Check if key exists in object
    "a" | in({a:1}) → true
   to_entries - Convert to [{key, value}, ...]
    {a:1} | to_entries → [{key:"a", value:1}]
   from_entries - Convert from [{key, value}, ...] to object
    [{key:"a", value:1}] | from_entries → {a:1}
   with_entries - Transform each {key, value} entry
    {a:1} | with_entries(.value += 1) → {a:2}

--functions math shows math functions

  $ query-json --no-color --functions math 2>&1 | head -15
  
  Mathematical functions
  
   abs - Absolute value
    -5 | abs → 5
   floor - Round down
    3.7 | floor → 3
   ceil - Round up
    3.2 | ceil → 4
   round - Round to nearest integer
    3.5 | round → 4
   sqrt - Square root
    16 | sqrt → 4
   log - Natural logarithm
   log10 - Base-10 logarithm

--functions type shows type functions

  $ query-json --no-color --functions type 2>&1 | head -15
  
  Type checking and conversion functions
  
   type - Get type as string
    42 | type → "number"
   to_string (aliases: tostring) - Convert to string
    42 | to_string → "42"
   to_number (aliases: tonumber) - Convert to number
    "42" | to_number → 42
   numbers - Select only numbers
    [1, "a", 2] | .[] | numbers → 1, 2
   strings - Select only strings
    [1, "a", 2] | .[] | strings → "a"
   booleans - Select only booleans
    [1, true, "a"] | .[] | booleans → true

--functions control shows control flow functions

  $ query-json --no-color --functions control 2>&1 | head -15
  
  Control flow and iteration functions
  
   if-then-else - Conditional expression
    if . > 0 then "pos" else "neg" end
   try-catch - Error handling
    try .foo catch "not found"
   ?? - Alternative operator (on null or false)
    .foo ?? "default" → "default" if .foo is null/false
   empty - Produce no output
    1, empty, 2 → 1, 2
   error - Raise an error
    error("failed")
   raise - Raise a structured error
    raise("validation"; "invalid input")

--functions with invalid category shows error

  $ query-json --no-color --functions invalid 2>&1
  
  Unknown help category: invalid
  
  
  
  Available help categories:
  
   string - String manipulation functions
   array - Array manipulation functions
   object - Object manipulation functions
   path - Path and traversal functions
   math - Mathematical functions
   type - Type checking and conversion functions
   control - Control flow and iteration functions
   definition - Function definition syntax
   date - Date and time functions
   debug - Debugging and inspection functions
  
  Usage: query-json --functions <category>
  Example: query-json --functions string
  
  [1]

--functions can be used with other flags

  $ query-json --no-color --functions string | head -3
  
  String manipulation functions
  
