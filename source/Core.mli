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

val run_iter :
  ?debug:bool ->
  ?colorize:bool ->
  ?verbose:bool ->
  ?raw:bool ->
  ?summarize:bool ->
  emit:(string -> unit) ->
  string ->
  Json.t ->
  (int, string) result
(** Parse and prepare once, then call [emit] once per rendered result without
    separators, and return how many results were emitted. A late error can
    follow earlier calls to [emit]. Exceptions raised by [emit] escape
    unchanged. A halt exits as in [run]. *)

type input = Json.Input.source =
  | String of string
  | File of string
  | Channel of in_channel
  | Value of Json.t

val run_input :
  ?debug:bool ->
  ?colorize:bool ->
  ?verbose:bool ->
  ?raw:bool ->
  ?summarize:bool ->
  string ->
  input ->
  (string, string) result
(** Read and validate the complete input before reporting query errors, printing
    the debug AST, or executing. Retain selected input when the plan permits it.
    Render results atomically as in [run]. *)

val run_input_iter :
  ?debug:bool ->
  ?colorize:bool ->
  ?verbose:bool ->
  ?raw:bool ->
  ?summarize:bool ->
  emit:(string -> unit) ->
  string ->
  input ->
  (int, string) result
(** Call [emit] once per rendered result and return how many results were
    emitted. Can emit before EOF for eligible compiled queries. Barriers and
    interpreted queries still validate first, as in [run_input]. [debug=true]
    always validates first and prints the AST only after valid EOF. Invalid
    queries also validate the full input, with input errors taking precedence.

    A query failure or halt stops callbacks and validates the remaining input. A
    later input error wins. Otherwise the query error returns or the halt exits
    as in [run]. Earlier output can precede a query or input error. Callback
    exceptions escape unchanged, including their backtrace. Owned files close on
    every exit. Borrowed channels remain open. *)
