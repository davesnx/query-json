val of_expression : Ast.expression -> Json.demand
(** The demand that [expression] puts on its input when its results are printed.
    [All] for any construct the analysis does not cover. *)

val stream : Ast.expression -> Ast.expression option
(** [Some f] when the expression is [.[] | f] (in any pipe nesting) and running
    [f] once per element of an array gives the same results, errors and side
    effects as running the whole expression once. *)
