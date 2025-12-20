type literal =
  | Bool of bool (* true *)
  | String of string (* "TEXT" *)
  | Number of float (* 123 or 123.0 *)
  | Null (* null *)
[@@deriving show { with_path = false }]

type builtin =
  | Add
  | Absolute
  | Sin
  | Cos
  | Tan
  | Asin
  | Acos
  | Atan
  | Log
  | Log10
  | Exp
  | Pow
  | Ceil
  | Round
  | Infinite
  | Now
  | Sinh
  | Cosh
  | Tanh
  | Asinh
  | Acosh
  | Atanh
  | Isinfinite
  | Isnormal
  | Trunc
  | Fabs
  | Cbrt
  | Expm1
  | Exp2
  | Log1p
  | Log2
  | Nearbyint
  | Logb
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

type expression =
  | Identity (* . *)
  | Empty (* empty *)
  | Pipe of expression * expression (* | *)
  | Update of expression * expression (* |= *)
  | Alternative of expression * expression (* // *)
  | Comma of expression * expression (* expr1 , expr2 *)
  | Literal of literal
  | Variable of string (* $var *)
  | Env (* env object containing all environment variables *)
  | Env_var of string (* $ENV.VAR or env.VAR *)
  (* Constructors *)
  | List of expression option (* [ expr ] *)
  | Object of (expression * expression option) list (* {} *)
  (* Objects *)
  | Walk of expression (* walk() *)
  | Transpose of expression (* transpose() *)
  | Key of string (* .foo *)
  | Optional of expression (* ? *)
  | Has of expression (* has(x) *)
  | Keys (* keys *)
  | Keys_unsorted (* keys_unsorted *)
  | Leaf_paths (* leaf_paths *)
  | Builtins (* builtins *)
  | Formats (* formats *)
  | Localtime (* localtime *)
  | Gmtime (* gmtime *)
  | Mktime (* mktime *)
  | Debug (* debug *)
  | Stderr (* stderr *)
  | Floor (* floor *)
  | Sqrt (* sqrt *)
  | Type (* type *)
  | Sort (* sort *)
  | Min (* min *)
  | Max (* max *)
  | Unique (* unique *)
  | Reverse (* reverse *)
  | Explode (* explode *)
  | Implode (* implode *)
  | Any (* any *)
  | All (* all *)
  | In of expression (* in *)
  | Recurse (* recurse *)
  | Recurse_expr of expression (* recurse(f) *)
  | Recurse_with of expression * expression (* recurse(f; condition) *)
  | Recurse_down (* recurse_down *)
  | To_entries (* to_entries *)
  | To_string (* to_string *)
  | Tostring (* tostring - deprecated *)
  | From_entries (* from_entries *)
  | With_entries of expression (* with_entries *)
  | Nan
  | Is_nan
  (* Array *)
  | Index of int list (* .[1] or .[0,1,2] - when empty list, acts as iterator *)
  | Iterator (* .[] - currently represented as Index [], kept for future use *)
  | Dynamic_access of expression (* .[$expr] - dynamic key/index access *)
  | Range of
      expression
      * expression option
      * expression option (* range(from; upto; step) *)
  | Flatten of expression option (* flatten or flatten(expr) *)
  | Head (* head *)
  | Tail (* tail *)
  | Map of expression
  | Map_values of expression (* map_values(x) *)
  (* .[] *)
  (* map(x) *)
  | Slice of int option * int option
  | Slice_expr of expression option * expression option (* .[expr:expr] *)
  | Flat_map of expression (* flat_map(x) *)
  | Reduce of expression * string * expression * expression
    (* reduce EXPR as $VAR (INIT; UPDATE) *)
  | As of expression * string * expression (* expr as $var | body *)
  | Select of expression (* select(x) *)
  | Sort_by of expression (* sort_by(x) *)
  | Group_by of expression (* group_by(x) *)
  | Unique_by of expression (* unique_by(x) *)
  | Min_by of expression (* min_by(x) *)
  | Max_by of expression (* max_by(x) *)
  | All_with_condition of expression (* all(c) *)
  | Any_with_condition of expression (* any(c) *)
  | Any_with_generator of expression * expression (* any(gen; cond) *)
  | All_with_generator of expression * expression (* all(gen; cond) *)
  | Some_ of expression (* some, Some_ to not collide with option *)
  | Find of expression (* find(x) *)
  (* operations *)
  | Operation of expression * op * expression
  (* Generic *)
  | Length (* length *)
  | Utf8bytelength (* utf8bytelength *)
  | Contains of expression (* contains *)
  (* Strings *)
  | Test of string
  (* TODO: this string is a regex, we could validate it in the parser and have a Regexp.t type here *)
  | Match of string (* match(regex) with captures *)
  | Scan of string (* scan(regex) *)
  | Capture of
      string (* capture(regex) - same as match but array of captures only *)
  | Sub of string * string (* sub(regex; replacement) *)
  | Gsub of string * string (* gsub(regex; replacement) *)
  | To_number (* to_number *)
  | Tonumber (* tonumber - deprecated *)
  | Starts_with of expression (* startswith *)
  | Startwith of expression (* startwith - deprecated *)
  | Ends_with of expression (* endswith *)
  | Endwith of expression (* endwith - deprecated *)
  | Index_of of expression (* index *)
  | Rindex_of of expression (* rindex *)
  | Indices of expression (* indices *)
  | Inside of expression (* inside *)
  | Ltrimstr of expression (* left_trimstr *)
  | Rtrimstr of expression (* right_trimstr *)
  | Trim (* trim *)
  | Ltrim (* left_trim *)
  | Rtrim (* right_trim *)
  | Ascii_upcase (* ascii_upcase *)
  | Ascii_downcase (* ascii_downcase *)
  | Split of expression (* split *)
  | Join of expression (* join *)
  | Bsearch of expression (* bsearch *)
  | Combinations (* combinations - all combinations of input arrays *)
  | Combinations_n of expression (* combinations(n) *)
  | Repeat of expression (* repeat(expr) *)
  | Add_expr of expression (* add(expr) *)
  | First of expression option (* first or first(expr) *)
  | Last of expression option (* last or last(expr) *)
  | Nth of expression * expression (* nth(n; expr) *)
  | Path of expression (* path(x) *)
  | If_then_else of
      expression * expression * expression (* If then (elseif) else end *)
  | While of expression * expression (* while(condition; update) *)
  | Until of expression * expression (* until(condition; update) *)
  | Atan2 of expression * expression (* atan2(y; x) *)
  | Copysign of expression * expression (* copysign(x; y) *)
  | Ldexp of expression * expression (* ldexp(m; e) *)
  | Fdim of expression * expression (* fdim(x; y) *)
  | Remainder of expression * expression (* remainder(x; y) *)
  | Scalbn of expression * expression (* scalbn(x; n) *)
  | Pow2 of expression * expression (* pow(x; y) - two argument version *)
  | Fma of
      expression
      * expression
      * expression (* fma(x; y; z) - fused multiply-add *)
  | Break (* break *)
  | Try of expression * expression option (* try expr catch handler *)
  | Limit of int * expression (* limit(n; expr) *)
  | Skip of int * expression (* skip(n; expr) *)
  | Error_msg of expression option (* error or error(msg) *)
  | Halt (* halt *)
  | Halt_error of int option (* halt_error or halt_error(exit_code) *)
  | Isempty of expression (* isempty(expr) *)
  | Foreach of expression * string * expression * expression * expression
    (* foreach EXPR as $VAR (INIT; UPDATE; EXTRACT) *)
  | Label of string * expression (* label(name; expr) *)
  | Del of expression (* del(path) *)
  | Delpaths of expression (* delpaths(paths_array) *)
  | Assign of expression * expression (* .foo = value *)
  | Getpath of expression (* getpath(path) *)
  | Setpath of expression * expression (* setpath(path; value) *)
  | Pick of expression (* pick(.a, .b.c) *)
  | Paths (* paths *)
  | Paths_filter of expression (* paths(filter) *)
  | Def of string * string list * expression (* def name(args): body *)
  | Apply of string * expression list (* function_name(args) *)
  | Not (* not *)
  | Fun of builtin
[@@deriving show { with_path = false }]
