open Ast

let items : Json.demand -> Json.demand = function All -> All | d -> Items d

let rec join (a : Json.demand) (b : Json.demand) : Json.demand =
  match (a, b) with
  | Skip, d | d, Skip ->
      d
  | All, _ | _, All ->
      All
  | Items a, Items b ->
      items (join a b)
  | Fields a, Fields b ->
      Fields
        (List.fold_left
           (fun acc (k, d) ->
             match List.assoc_opt k acc with
             | Some d' ->
                 (k, join d d') :: List.remove_assoc k acc
             | None ->
                 (k, d) :: acc
           )
           a b
        )
  | Fields _, Items _ | Items _, Fields _ ->
      All

let element : Json.demand -> Json.demand = function
  | Skip ->
      Skip
  | Items d ->
      d
  | All | Fields _ ->
      All

exception Unknown

let rec demand e (k : Json.demand) : Json.demand =
  match e with
  | Identity ->
      k
  | Key s ->
      Fields [ (s, k) ]
  | Index [] ->
      items k
  | Pipe (a, b) ->
      demand a (demand b k)
  | Comma (a, b) ->
      join (demand a k) (demand b k)
  | Literal _ | List None ->
      Skip
  | List (Some e) ->
      demand e (element k)
  | Fn1 (With_expr (Map, f)) ->
      items (demand f (element k))
  | Fn1 (With_expr (Select, f)) ->
      join k (demand f All)
  | Fn1 (With_expr ((Sort_by | Unique_by), f)) ->
      items (join (element k) (demand f All))
  | Fn1 (With_expr ((Min_by | Max_by), f)) ->
      items (join k (demand f All))
  | Fn1 (With_expr (Group_by, f)) ->
      items
        (join
           ( if k = Skip then
               Skip
             else
               All
           )
           (demand f All)
        )
  | Operation (a, _, b) ->
      join (demand a All) (demand b All)
  | Alternative (a, b) ->
      join (demand a All) (demand b k)
  | If_then_else (c, t, e) ->
      join (demand c All) (join (demand t k) (demand e k))
  | _ ->
      raise Unknown

let of_expression e = try demand e All with Unknown -> All
