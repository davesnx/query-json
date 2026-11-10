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
  | Fn0 Length ->
      Items Skip
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
  | Object pairs ->
      List.fold_left
        (fun acc (key, value) ->
          let value : Json.demand =
            match (key, value) with
            | _, Some v ->
                demand v All
            | Literal (String s), None ->
                Fields [ (s, All) ]
            | _, None ->
                All
          in
          join acc (join (demand key All) value)
        )
        Skip pairs
  | _ ->
      All

let children = function
  | Identity
  | Literal _
  | Variable _
  | Env_var _
  | Key _
  | Index _
  | Slice _
  | Fn0 _
  | Fn1 (With_pattern _ | With_separator _) ->
      []
  | Fn1 (With_expr (_, e)) | Optional e | Dynamic_access e ->
      [ e ]
  | Pipe (a, b)
  | Update (a, b)
  | Alternative (a, b)
  | Comma (a, b)
  | Operation (a, _, b)
  | Assign (a, b)
  | Fn2 (_, a, b) ->
      [ a; b ]
  | List e ->
      Option.to_list e
  | Object pairs ->
      List.concat_map (fun (k, v) -> k :: Option.to_list v) pairs
  | Slice_expr (a, b) ->
      Option.to_list a @ Option.to_list b
  | If_then_else (a, b, c) | Fma (a, b, c) ->
      [ a; b; c ]
  | Range (a, b, c) ->
      (a :: Option.to_list b) @ Option.to_list c
  | Reduce (a, _, b, c) ->
      [ a; b; c ]
  | Foreach (a, _, b, c, d) ->
      [ a; b; c; d ]
  | As (a, _, b) ->
      [ a; b ]
  | Try (a, b, c) ->
      (a :: Option.to_list b) @ Option.to_list c
  | Fn (_, _, body) ->
      [ body ]
  | Apply (_, args) ->
      args

let rec defines = function Fn _ -> true | e -> List.exists defines (children e)

let of_expression e : Json.demand =
  if defines e then
    All
  else
    demand e All

let rec prints = function
  | Fn0 (Debug | Stderr) | Fn1 (With_expr (Debug_msg, _)) ->
      true
  | e ->
      List.exists prints (children e)

let rec pipeline = function
  | Pipe (Fn _, _) as e ->
      [ e ]
  | Pipe (a, b) ->
      pipeline a @ pipeline b
  | Identity ->
      []
  | e ->
      [ e ]

let stream e =
  match pipeline e with
  | Index [] :: rest
    when not (List.exists (function Fn _ -> true | e -> prints e) rest) ->
      Some
        (List.fold_right
           (fun e acc ->
             if acc = Identity then
               e
             else
               Pipe (e, acc)
           )
           rest Identity
        )
  | _ ->
      None
