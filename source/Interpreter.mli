type execute_result = Ok of Json.t list | Error of string | Halt of int

val execute :
  colorize:bool ->
  verbose:bool ->
  ?env:(string * Json.t) list ->
  Ast.expression ->
  Json.t ->
  execute_result
