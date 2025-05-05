type literal =
  | Bool of bool (* true *)
  | String of string (* "TEXT" *)
  | Number of float (* 123 or 123.0 *)
  | Null (* null *)
[@@deriving show { with_path = false }]

type builtin = Add | Abs [@@deriving show { with_path = false }]

type op =
  | Add
  | Sub
  | Mult
  | Div
  | Eq
  | Neq
  | Gt (* > *)
  | St (* < *)
  | Ge (* >=*)
  | Se (* <= *)
  | And
  | Or
[@@deriving show { with_path = false }]

type expression =
  | Identity (* . *)
  | Empty (* empty *)
  | Pipe of expression * expression (* | *)
  | Comma of expression * expression (* expr1 , expr2 *)
  | Literal of literal
  (* Constructors *)
  | List of expression list (* [ expr ] *)
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
  | RecurseDown (* recurse_down *)
  | ToEntries (* to_entries *)
  | ToString (* to_string *)
  | FromEntries (* from_entries *)
  | WithEntries
  | Nan
  | IsNan
  (* Array *)
  | Index of int (* .[1] *)
  | Iterator (* .[] *)
  | Range of int * int option * int option (* range(1, 10) *)
  | Flatten (* flatten *)
  | Head (* head *)
  | Tail (* tail *)
  | Map of expression
  (* .[] *)
  (* map(x) *)
  | Slice of int option * int option
    (* slice(Some 1, Some 10), slice(None, Some 10), slice(Some 1, None) *)
  | FlatMap of expression (* flat_map(x) *)
  | Reduce of expression (* reduce(x) *)
  | Select of expression (* select(x) *)
  | SortBy of expression (* sort_by(x) *)
  | GroupBy of expression (* group_by(x) *)
  | UniqueBy of expression (* unique_by(x) *)
  | MinBy of expression (* min_by(x) *)
  | MaxBy of expression (* max_by(x) *)
  | AllWithCondition of expression (* all(c) *)
  | AnyWithCondition of expression (* any(c) *)
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
  | ToNumber (* to_num *)
  | StartsWith of expression (* starts_with *)
  | EndsWith of expression (* ends_with *)
  | Split of expression (* split *)
  | Join of expression (* join *)
  | Path of expression (* path(x) *)
  (* Logic *)
  | IfThenElse of
      expression * expression * expression (* If then (elseif) else end *)
  | Break (* break *)
  (* Conditionals *)
  | Not (* not *)
  (* builtin *)
  | Fun of builtin
[@@deriving show { with_path = false }]
