type t
type loaded
type backend = Compiled | Interpreted
type 'a fold_result = Completed of 'a | Failed of string | Halted of int

val prepare : Ast.expression -> t
(** Select a backend for the complete expression without evaluating it. Plans
    are immutable and can be reused after success or failure. *)

val backend : t -> backend

module For_test : sig
  type stream_cut = private Root_items of t | Member_items of string * t

  val stream_cut : t -> stream_cut option
end

val load : t -> Json.Input.source -> (loaded, string) result
(** Bind a query to immutable input, selecting one unconditional leading root
    key when possible. Whole input retains the original query; selected input
    uses the remaining plan. Input is read once, without retry. *)

val fold :
  colorize:bool ->
  verbose:bool ->
  ?env:(string * Json.t) list ->
  init:'a ->
  f:('a -> Json.t -> 'a) ->
  t ->
  Json.t ->
  'a fold_result
(** Fold top-level results in order without collecting the final result list,
    for either backend. Nested expressions can still collect intermediate
    results. A late failure or halt can follow earlier calls to [f]. Exceptions
    raised by [f] escape unchanged. Each call owns its evaluation state. *)

val execute :
  colorize:bool ->
  verbose:bool ->
  ?env:(string * Json.t) list ->
  t ->
  Json.t ->
  Interpreter.execute_result
(** Each call owns its pull state. An error discards all results from that call;
    compiled errors never cause an interpreter retry. *)

val execute_loaded :
  colorize:bool ->
  verbose:bool ->
  ?env:(string * Json.t) list ->
  loaded ->
  Interpreter.execute_result
(** Execute bound input with fresh evaluation state on each call. *)

val fold_loaded :
  colorize:bool ->
  verbose:bool ->
  ?env:(string * Json.t) list ->
  init:'a ->
  f:('a -> Json.t -> 'a) ->
  loaded ->
  'a fold_result
(** Fold bound input with the ordering and callback behavior of [fold]. Each
    call owns its evaluation state, including after failure or halt. *)

val fold_source :
  colorize:bool ->
  verbose:bool ->
  ?env:(string * Json.t) list ->
  init:'a ->
  f:('a -> Json.t -> 'a) ->
  t ->
  Json.Input.source ->
  'a fold_result
(** Permits early results only for proven compiled item cuts. Other plans use
    [load] and [fold_loaded]. Each complete child is fully evaluated before
    reading the next child.

    A query failure or halt stops callbacks and saves the terminal result while
    the remaining input is validated. A later input error wins. Otherwise the
    saved result returns. Earlier callbacks can precede an input error.
    Materialized input executes the original query, or iteration and the
    residual plan for a selected scalar. Input is never retried.

    Callback exceptions escape unchanged, including their backtrace.
    [Json.Input] closes owned files on every exit and leaves borrowed channels
    open. Prepared plans remain reusable. *)
