val parse :
  ?debug:bool ->
  ?colorize:bool ->
  ?verbose:bool ->
  string ->
  (Ast.expression, string) result

val run : string -> Json.t -> (string, string) result
