(* expose parse function for testing purposes only *)
val parse :
  debug:bool -> colorize:bool -> string -> (Ast.expression, string) result

val run :
  ?debug:bool ->
  ?colorize:bool ->
  ?verbose:bool ->
  ?raw:bool ->
  ?summarize:bool ->
  string ->
  Json.t ->
  (string, string) result
