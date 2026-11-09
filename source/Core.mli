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

val run_input :
  ?debug:bool ->
  ?colorize:bool ->
  ?verbose:bool ->
  ?raw:bool ->
  ?summarize:bool ->
  string ->
  (Json.demand -> (Json.t, string) result) ->
  (string, string) result
(** Like [run], but reads the input with [read] after the query is parsed,
    passing the demand of the query ([Json.All] when the query does not parse).
    An input error is reported before a query error. *)
