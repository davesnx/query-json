val of_expression : Ast.expression -> Json.demand
(** The demand that [expression] puts on its input when its results are printed.
    [All] for any construct the analysis does not cover. *)
