val execute :
  colorize:bool ->
  verbose:bool ->
  ?env:(string * Json.t) list ->
  Ast.expression ->
  Json.t ->
  (Json.t list, string) result
