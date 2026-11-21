val parse :
  debug:bool -> colorize:bool -> string -> (Ast.expression, string) result

val run :
  ?debug:bool ->
  ?colorize:bool ->
  ?verbose:bool ->
  ?raw:bool ->
  ?summarize:bool ->
  ?buf_size_hint:int ->
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

val run_output :
  ?debug:bool ->
  ?colorize:bool ->
  ?verbose:bool ->
  ?raw:bool ->
  ?summarize:bool ->
  ?oc:out_channel ->
  stream:bool ->
  string ->
  (Json.demand ->
  (Json.demand * (Json.t -> bool)) option ->
  (Json.t option, string) result
  ) ->
  (unit, string) result
