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
  | Range of int * int option * int option (* range(1, 10) *)
  | Flatten of int option (* flatten or flatten(n) *)
  | Head (* head *)
  | Tail (* tail *)
  | Map of expression
  (* .[] *)
  (* map(x) *)
  | Slice of int option * int option
  | Flat_map of expression (* flat_map(x) *)
  | Reduce of expression * string * expression * expression
    (* reduce EXPR as $VAR (INIT; UPDATE) *)
  | Select of expression (* select(x) *)
  | Sort_by of expression (* sort_by(x) *)
  | Group_by of expression (* group_by(x) *)
  | Unique_by of expression (* unique_by(x) *)
  | Min_by of expression (* min_by(x) *)
  | Max_by of expression (* max_by(x) *)
  | All_with_condition of expression (* all(c) *)
  | Any_with_condition of expression (* any(c) *)
  | Some_ of expression (* some, Some_ to not collide with option *)
  | Find of expression (* find(x) *)
  (* operations *)
  | Operation of expression * op * expression
  (* Generic *)
  | Length (* length *)
  | Contains of expression (* contains *)
  (* Strings *)
  | Test of string
  (* this string is a regex, we could validate it in the parser and have a Regexp.t type here *)
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
  | Split of expression (* split *)
  | Join of expression (* join *)
  | Path of expression (* path(x) *)
  (* Logic *)
  | If_then_else of
      expression * expression * expression (* If then (elseif) else end *)
  | While of expression * expression (* while(condition; update) *)
  | Until of expression * expression (* until(condition; update) *)
  | Break (* break *)
  | Try of expression * expression option (* try expr catch handler *)
  | Limit of int * expression (* limit(n; expr) *)
  | Error_msg of expression option (* error or error(msg) *)
  | Halt (* halt *)
  | Halt_error of int option (* halt_error or halt_error(exit_code) *)
  | Isempty of expression (* isempty(expr) *)
  | Foreach of expression * expression * expression * expression
    (* foreach EXPR as $VAR (INIT; UPDATE; EXTRACT) *)
  | Label of string * expression (* label(name; expr) *)
  | Del of expression (* del(path) *)
  | Assign of expression * expression (* .foo = value *)
  | Getpath of expression (* getpath(path) *)
  | Setpath of expression * expression (* setpath(path; value) *)
  | Paths (* paths - all paths *)
  | Paths_filter of expression (* paths(filter) *)
  | Def of string * string list * expression (* def name(args): body *)
  | Call of string * expression list (* function_name(args) *)
  (* Conditionals *)
  | Not (* not *)
  (* builtin *)
  | Fun of builtin
[@@deriving show { with_path = false }]
