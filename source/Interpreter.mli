type execute_result = Ok of Json.t list | Error of string | Halt of int

type 'a fold_result = Completed of 'a | Failed of string | Halted of int

val fold :
  colorize:bool ->
  verbose:bool ->
  ?env:(string * Json.t) list ->
  init:'a ->
  f:('a -> Json.t -> 'a) ->
  Ast.expression ->
  Json.t ->
  'a fold_result
(** Call [f] once per top-level yield, in order, without collecting the final
    result list. Nested expressions can still collect intermediate results.
    Errors and halts match [execute], but earlier calls to [f] remain visible.
    Exceptions from [f] escape unchanged. Each call owns its evaluation state.
*)

val execute :
  colorize:bool ->
  verbose:bool ->
  ?env:(string * Json.t) list ->
  Ast.expression ->
  Json.t ->
  execute_result
