type literal =
  | Bool of bool (* true *)
  | String of string (* "TEXT" *)
  | Int of int (* small integers that fit in native int *)
  | Int64 of int64 (* large integers that need 64-bit *)
  | Big_int of Z.t [@printer fun fmt z -> Z.pp_print fmt z]
    (* huge integers beyond int64 range *)
  | Float of float (* 123.0 - floating point literals *)
  | Null (* null *)
[@@deriving show { with_path = false }]

type fn0 =
  (* String functions *)
  | Trim
  | To_uppercase
  | To_lowercase
  | To_codepoints
  | From_codepoints
  (* Array functions *)
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
  (* Object functions *)
  | Keys
  | To_entries
  | From_entries
  (* Type functions *)
  | Type
  | To_string
  | To_number
  | Length
  | Byte_length
  (* Type selectors *)
  | Numbers
  | Strings
  | Objects
  | Arrays
  | Booleans
  | Nulls
  | Iterables
  | Scalars
  | Values
  (* Math functions *)
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
  | Pow
  | Cube_root
  | Truncate
  | Is_normal
  | Is_nan
  | Nearbyint
  | Logb
  | Infinite
  | Nan
  | Now
  (* Path functions *)
  | Paths
  | Leaf_paths
  | Recurse
  | Recurse_down
  | Descend
  | Dive
  (* Control flow *)
  | Empty
  | Not
  | Break
  | Halt
  | Env
  (* Debug/IO *)
  | Debug
  | Stderr
  | Builtins
  (* Time *)
  | To_local_time
  | To_utc
  | To_unix
  | From_date
  (* Custom helpers *)
  | Is_blank
  | Is_empty
[@@deriving show { with_path = false }]

type fn1_pattern = Test | Match | Scan | Capture
[@@deriving show { with_path = false }]

type fn1_separator = Split | Join | Parse_date
[@@deriving show { with_path = false }]

type fn1_expr =
  (* Array functions *)
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
  (* Object functions *)
  | Has
  | In
  | With_entries
  | Delete
  | Pick
  | Getpath
  | Delpaths
  (* String functions *)
  | Starts_with
  | Ends_with
  | Index_of
  | Last_index_of
  | Indices
  | Inside
  | Trim_start
  | Trim_end
  | Contains
  (* Path functions *)
  | Walk
  | Path
  | Paths_filter
  | Recurse_expr
  | Find_all
  | Find_first
  | Paths_to
  (* Control flow *)
  | Is_empty_expr
  | Error_msg
  | Halt_error_n
  | Debug_msg
  | Assert_simple
[@@deriving show { with_path = false }]

type compiled_regex = { pattern : string; regex : Re.re }

let pp_compiled_regex fmt r = Format.fprintf fmt "/%s/" r.pattern

type fn2 =
  (* String functions *)
  | Replace
  | Replace_all
  (* Control flow *)
  | While
  | Until
  | Limit
  | Skip
  | Recurse_with
  | Any_gen
  | All_gen
  | Assert_msg
  | Raise
  (* Path functions *)
  | Setpath
  | Nth
  (* Math functions *)
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
  | Identity (* . *)
  | Literal of literal
  | Variable of string (* $var *)
  | Env_var of string (* $ENV.VAR or env.VAR *)
  (* Pipes and operators *)
  | Pipe of expression * expression (* | *)
  | Update of expression * expression (* |= *)
  | Alternative of expression * expression (* ?? *)
  | Comma of expression * expression (* expr1 , expr2 *)
  | Operation of expression * op * expression
  | Assign of expression * expression (* .foo = value *)
  | Fn0 of fn0
  | Fn1 of fn1
  | Fn2 of fn2 * expression * expression
  (* Constructors *)
  | List of expression option (* [ expr ] *)
  | Object of (expression * expression option) list (* {} *)
  (* Access patterns *)
  | Key of string (* .foo *)
  | Optional of expression (* ? *)
  | Index of int list (* .[1] or .[0,1,2] - when empty list, acts as iterator *)
  | Dynamic_access of expression (* .[$expr] - dynamic key/index access *)
  | Slice of int option * int option
  | Slice_expr of expression option * expression option (* .[expr:expr] *)
  | If_then_else of
      expression * expression * expression (* If then (elseif) else end *)
  | Range of
      expression
      * expression option
      * expression option (* range(from; upto; step) *)
  | Reduce of expression * binding_pattern * expression * expression
    (* reduce EXPR as PATTERN (INIT; UPDATE) *)
  | Foreach of
      expression * binding_pattern * expression * expression * expression
    (* foreach EXPR as PATTERN (INIT; UPDATE; EXTRACT) *)
  | As of expression * binding_pattern * expression (* expr as PATTERN | body *)
  | Try of expression * expression option * expression option
    (* try expr catch handler finally cleanup *)
  | Fma of
      expression
      * expression
      * expression (* fma(x; y; z) - fused multiply-add *)
  | Fn of string * string list * expression (* fn name(args): body *)
  | Apply of string * expression list (* function_name(args) *)
[@@deriving show { with_path = false }]
