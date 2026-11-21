type number = Integer of string | Decimal of string
[@@deriving show { with_path = false }]

type literal = Bool of bool | String of string | Number of number | Null
[@@deriving show { with_path = false }]

type fn0 =
  | Trim
  | To_uppercase
  | To_lowercase
  | To_codepoints
  | From_codepoints
  | Sort
  | Unique
  | Reverse
  | Min
  | Max
  | First
  | Last
  | Add
  | Any
  | All
  | Flatten
  | Combinations
  | Transpose
  | Keys
  | To_entries
  | From_entries
  | Type
  | To_string
  | To_number
  | Length
  | Byte_length
  | Numbers
  | Strings
  | Objects
  | Arrays
  | Booleans
  | Nulls
  | Iterables
  | Scalars
  | Values
  | Floor
  | Sqrt
  | Abs
  | Ceil
  | Round
  | Sin
  | Cos
  | Tan
  | Asin
  | Acos
  | Atan
  | Sinh
  | Cosh
  | Tanh
  | Asinh
  | Acosh
  | Atanh
  | Log
  | Log10
  | Log2
  | Exp
  | Exp2
  | Expm1
  | Log1p
  | Cube_root
  | Truncate
  | Is_normal
  | Is_nan
  | Nearbyint
  | Logb
  | Infinite
  | Nan
  | Now
  | Paths
  | Leaf_paths
  | Recurse
  | Recurse_down
  | Descend
  | Dive
  | Empty
  | Not
  | Break
  | Halt
  | Env
  | Debug
  | Stderr
  | Builtins
  | To_local_time
  | To_utc
  | To_unix
  | From_date
  | Is_blank
  | Is_empty
[@@deriving show { with_path = false }]

type fn1_pattern = Test | Match | Scan | Capture
[@@deriving show { with_path = false }]

type fn1_separator = Split | Join | Parse_date
[@@deriving show { with_path = false }]

type fn1_expr =
  | Map
  | Map_values
  | Flat_map
  | Select
  | Sort_by
  | Group_by
  | Unique_by
  | Min_by
  | Max_by
  | Find
  | Some_
  | Any_cond
  | All_cond
  | Pluck
  | Partition
  | Flatten_n
  | Combinations_n
  | Transpose_expr
  | First_expr
  | Last_expr
  | Nth_array
  | Add_expr
  | Repeat
  | Binary_search
  | Has
  | In
  | With_entries
  | Delete
  | Pick
  | Getpath
  | Delpaths
  | Starts_with
  | Ends_with
  | Index_of
  | Last_index_of
  | Indices
  | Inside
  | Trim_start
  | Trim_end
  | Contains
  | Walk
  | Path
  | Paths_filter
  | Recurse_expr
  | Find_all
  | Find_first
  | Paths_to
  | Is_empty_expr
  | Error_msg
  | Halt_error_n
  | Debug_msg
  | Assert_simple
[@@deriving show { with_path = false }]

type compiled_regex = { pattern : string; regex : Re.re }

let pp_compiled_regex fmt r = Format.fprintf fmt "/%s/" r.pattern

type fn2 =
  | Replace
  | Replace_all
  | While
  | Until
  | Limit
  | Skip
  | Recurse_with
  | Any_gen
  | All_gen
  | Assert_msg
  | Raise
  | Setpath
  | Nth
  | Atan2
  | Copysign
  | Ldexp
  | Fdim
  | Remainder
  | Scalbn
  | Pow2
[@@deriving show { with_path = false }]

type op =
  | Add
  | Subtract
  | Multiply
  | Divide
  | Modulo
  | Equal
  | Not_equal
  | Greater_than
  | Less_than
  | Greater_than_or_equal
  | Less_than_or_equal
  | And
  | Or
[@@deriving show { with_path = false }]

type binding_pattern =
  | Pat_var of string
  | Pat_array of binding_pattern list
  | Pat_object of (string * string) list
[@@deriving show { with_path = false }]

type fn1 =
  | With_pattern of fn1_pattern * compiled_regex
  | With_separator of fn1_separator * string
  | With_expr of fn1_expr * expression

and expression =
  | Identity
  | Literal of literal
  | Variable of string
  | Env_var of string
  | Pipe of expression * expression
  | Update of expression * expression
  | Alternative of expression * expression
  | Comma of expression * expression
  | Operation of expression * op * expression
  | Assign of expression * expression
  | Fn0 of fn0
  | Fn1 of fn1
  | Fn2 of fn2 * expression * expression
  | List of expression option
  | Object of (expression * expression option) list
  | Key of string
  | Optional of expression
  | Index of int list
  | Dynamic_access of expression
  | Slice of int option * int option
  | Slice_expr of expression option * expression option
  | If_then_else of expression * expression * expression
  | Range of expression * expression option * expression option
  | Reduce of expression * binding_pattern * expression * expression
  | Foreach of
      expression * binding_pattern * expression * expression * expression
  | As of expression * binding_pattern * expression
  | Try of expression * expression option * expression option
  | Fma of expression * expression * expression
  | Fn of string * string list * expression
  | Apply of string * expression list
[@@deriving show { with_path = false }]
