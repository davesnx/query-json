type t =
  [ `Null
  | `Bool of bool
  | `Int of int
  | `Intlit of string
  | `Float of float
  | `Floatlit of string
  | `String of string
  | `Stringlit of string
  | `Assoc of (string * t) list
  | `List of t list
  ]

