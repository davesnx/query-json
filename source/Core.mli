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

val run_output :
  ?debug:bool ->
  ?colorize:bool ->
  ?verbose:bool ->
  ?raw:bool ->
  ?summarize:bool ->
  stream:bool ->
  string ->
  (Json.demand ->
  (Json.demand * (Json.t -> bool)) option ->
  (Json.t option, string) result
  ) ->
  (unit, string) result
(** Like [run_input], but prints the results on stdout itself, each followed by
    a newline (one newline when there is none). [read demand (Some (d, f))] may
    pass the elements of an array to [f] one by one instead of returning the
    value; [f] returns [false] to stop. For [.[] | f], each element is then run
    on its own. Nothing is printed before the input is read in full, unless
    [stream] is set: then the results of each element are printed and flushed
    when ready. *)
