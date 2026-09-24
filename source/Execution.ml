type one =
  | Identity
  | Literal of Ast.literal
  | Key of string
  | Index of int
  | Pipe_one of one * one
  | Operation of one * Ast.op * one
  | List of plan option
  | Map of plan

and many =
  | Empty
  | Iterate
  | Indices of int list
  | Pipe of plan * plan
  | Comma of plan * plan
  | Select of plan

and plan = One of one | Many of many

type t = Plan of plan | Fallback of Ast.expression
type loaded = Loaded of t * Json.t
type backend = Compiled | Interpreted
type 'a fold_result = Completed of 'a | Failed of string | Halted of int

let ( let* ) = Option.bind

let pipe_plan left right =
  match (left, right) with
  | One left, One right ->
      One (Pipe_one (left, right))
  | _ ->
      Many (Pipe (left, right))

let rec compile = function
  | Ast.Identity ->
      Some (One Identity)
  | Ast.Literal literal ->
      Some (One (Literal literal))
  | Ast.Key key ->
      Some (One (Key key))
  | Ast.Index [] ->
      Some (Many Iterate)
  | Ast.Index [ index ] ->
      Some (One (Index index))
  | Ast.Index indices ->
      Some (Many (Indices indices))
  | Ast.Fn0 Empty ->
      Some (Many Empty)
  | Ast.Pipe (left, right) ->
      let* left = compile left in
      let* right = compile right in
      Some (pipe_plan left right)
  | Ast.Comma (left, right) ->
      let* left = compile left in
      let* right = compile right in
      Some (Many (Comma (left, right)))
  | Ast.List None ->
      Some (One (List None))
  | Ast.List (Some expr) ->
      let* plan = compile expr in
      Some (One (List (Some plan)))
  | Ast.Operation (left, op, right) -> (
      let* left = compile left in
      let* right = compile right in
      match (left, right) with
      | One left, One right ->
          Some (One (Operation (left, op, right)))
      | _ ->
          None
    )
  | Ast.Fn1 (With_expr (Map, expr)) ->
      let* plan = compile expr in
      Some (One (Map plan))
  | Ast.Fn1 (With_expr (Select, expr)) ->
      let* plan = compile expr in
      Some (Many (Select plan))
  | _ ->
      None

let prepare expr =
  match compile expr with Some plan -> Plan plan | None -> Fallback expr

let backend = function Plan _ -> Compiled | Fallback _ -> Interpreted

type stream_head = Root | Member of string
type stream_cut = Root_items of plan | Member_items of string * plan

let direct_member = function
  | Key member | Pipe_one (Identity, Key member) ->
      Some member
  | _ ->
      None

let rec split_stream_head = function
  | Many Iterate ->
      Some (Root, None)
  | Many (Pipe (One Identity, Many Iterate)) ->
      Some (Root, None)
  | Many (Pipe (One left, Many Iterate)) ->
      let* member = direct_member left in
      Some (Member member, None)
  | Many (Pipe (left, right)) ->
      let* head, residual = split_stream_head left in
      let residual =
        match residual with None -> right | Some left -> pipe_plan left right
      in
      Some (head, Some residual)
  | _ ->
      None

let stream_cut = function
  | Fallback _ ->
      None
  | Plan plan ->
      let* head, residual = split_stream_head plan in
      let residual = Option.value residual ~default:(One Identity) in
      Some
        ( match head with
        | Root ->
            Root_items residual
        | Member member ->
            Member_items (member, residual)
        )

module For_test = struct
  type stream_cut = Root_items of t | Member_items of string * t

  let stream_cut query =
    match stream_cut query with
    | None ->
        None
    | Some (Root_items residual) ->
        Some (Root_items (Plan residual))
    | Some (Member_items (member, residual)) ->
        Some (Member_items (member, Plan residual))
end

let rec leading_key_one = function
  | Key key ->
      Some (key, Identity)
  | Pipe_one (left, right) ->
      let* key, left = leading_key_one left in
      Some (key, Pipe_one (left, right))
  | _ ->
      None

let rec leading_key = function
  | One one ->
      let* key, one = leading_key_one one in
      Some (key, One one)
  | Many (Pipe (left, right)) ->
      let* key, left = leading_key left in
      Some (key, Many (Pipe (left, right)))
  | _ ->
      None

let load query source =
  let select, residual =
    match query with
    | Plan plan -> (
        match leading_key plan with
        | Some (key, residual) ->
            (Some key, Plan residual)
        | None ->
            (None, query)
      )
    | Fallback _ ->
        (None, query)
  in
  Result.map
    (function
      | Json.Input.Whole json ->
          Loaded (query, json)
      | Json.Input.Selected json ->
          Loaded (residual, json)
      )
    (Json.Input.read ~select source)

type cursor = unit -> Json.t option

let once eval : cursor =
  let pending = ref true in
  fun () ->
    if !pending then begin
      pending := false;
      Some (eval ())
    end else
      None

(* Opening a branch must not evaluate it before earlier branches are drained. *)
let delayed open_cursor : cursor =
  let current = ref None in
  fun () ->
    let next =
      match !current with
      | Some next ->
          next
      | None ->
          let next = open_cursor () in
          current := Some next;
          next
    in
    next ()

let of_seq seq : cursor =
  let rest = ref seq in
  fun () ->
    match !rest () with
    | Seq.Nil ->
        None
    | Seq.Cons (value, tail) ->
        rest := tail;
        Some value

let rec eval_one ~colorize plan json =
  match plan with
  | Identity ->
      json
  | Literal literal ->
      Runtime.literal literal
  | Key key ->
      Runtime.member key json
  | Index index ->
      Runtime.index ~colorize index json
  | Pipe_one (left, right) ->
      let value = eval_one ~colorize left json in
      eval_one ~colorize right value
  | Operation (left, op, right) ->
      let left = eval_one ~colorize left json in
      let right = eval_one ~colorize right json in
      Runtime.Operators.apply ~colorize op left right
  | List None ->
      `List []
  | List (Some plan) ->
      `List (collect ~colorize plan json)
  | Map (One plan) ->
      let items = Runtime.map_inputs ~colorize json in
      `List (List.map (eval_one ~colorize plan) items)
  | Map plan ->
      let items = Runtime.map_inputs ~colorize json in
      let results =
        List.fold_left
          (fun acc item -> List.rev_append (collect ~colorize plan item) acc)
          [] items
      in
      `List (List.rev results)

and collect ~colorize plan json =
  match plan with
  | One plan ->
      [ eval_one ~colorize plan json ]
  | Many _ ->
      let next = open_cursor ~colorize plan json in
      let rec drain acc =
        match next () with
        | None ->
            List.rev acc
        | Some value ->
            drain (value :: acc)
      in
      drain []

and open_cursor ~colorize plan json : cursor =
  match plan with
  | One plan ->
      once (fun () -> eval_one ~colorize plan json)
  | Many Empty ->
      fun () -> None
  | Many Iterate ->
      delayed (fun () -> of_seq (Runtime.iterator ~colorize json))
  | Many (Indices indices) -> (
      let rest = ref indices in
      fun () ->
        match !rest with
        | [] ->
            None
        | index :: tail ->
            rest := tail;
            Some (Runtime.index ~colorize index json)
    )
  | Many (Comma (left, right)) ->
      let left = open_cursor ~colorize left json in
      let right = open_cursor ~colorize right json in
      let in_left = ref true in
      fun () ->
        if !in_left then (
          match left () with
          | Some _ as value ->
              value
          | None ->
              in_left := false;
              right ()
        ) else
          right ()
  | Many (Pipe (One left, right)) ->
      delayed (fun () ->
          let value = eval_one ~colorize left json in
          open_cursor ~colorize right value
      )
  | Many (Pipe (left, One right)) ->
      let left = open_cursor ~colorize left json in
      fun () -> Option.map (eval_one ~colorize right) (left ())
  | Many (Pipe (left, right)) ->
      let left = open_cursor ~colorize left json in
      let active = ref (fun () -> None) in
      let rec next () =
        match !active () with
        | Some _ as value ->
            value
        | None -> (
            match left () with
            | None ->
                None
            | Some value ->
                active := open_cursor ~colorize right value;
                next ()
          )
      in
      next
  | Many (Select (One conditional)) ->
      let pending = ref true in
      fun () ->
        if !pending then begin
          pending := false;
          let value = eval_one ~colorize conditional json in
          if Runtime.Operators.is_truthy value then
            Some json
          else
            None
        end else
          None
  | Many (Select conditional) ->
      let conditional = open_cursor ~colorize conditional json in
      let rec next () =
        match conditional () with
        | None ->
            None
        | Some value ->
            if Runtime.Operators.is_truthy value then
              Some json
            else
              next ()
      in
      next

let fold ~colorize ~verbose ?env ~init ~f query json =
  match query with
  | Fallback expr -> (
      match Interpreter.fold ~colorize ~verbose ?env ~init ~f expr json with
      | Completed acc ->
          Completed acc
      | Failed error ->
          Failed error
      | Halted code ->
          Halted code
    )
  | Plan plan ->
      let next = open_cursor ~colorize plan json in
      let pull () =
        match next () with
        | value ->
            Ok value
        | effect Runtime.Runtime_error.Fail err, _ ->
            Error (Runtime.Runtime_error.format ~colorize err)
        | exception exn ->
            Error (Printexc.to_string exn)
      in
      let rec drain acc =
        match pull () with
        | Ok None ->
            Completed acc
        | Ok (Some value) ->
            (drain [@tailcall]) (f acc value)
        | Error error ->
            Failed error
      in
      drain init

let execute ~colorize ~verbose ?env query json : Interpreter.execute_result =
  match query with
  | Fallback expr ->
      Interpreter.execute ~colorize ~verbose ?env expr json
  | Plan _ -> (
      match
        fold ~colorize ~verbose ?env ~init:[]
          ~f:(fun acc value -> value :: acc)
          query json
      with
      | Completed values ->
          Ok (List.rev values)
      | Failed error ->
          Error error
      | Halted code ->
          Halt code
    )

let execute_loaded ~colorize ~verbose ?env (Loaded (query, json)) =
  execute ~colorize ~verbose ?env query json

let fold_loaded ~colorize ~verbose ?env ~init ~f (Loaded (query, json)) =
  fold ~colorize ~verbose ?env ~init ~f query json

let fold_source ~colorize ~verbose ?env ~init ~f query source =
  match stream_cut query with
  | None -> (
      match load query source with
      | Ok loaded ->
          fold_loaded ~colorize ~verbose ?env ~init ~f loaded
      | Error error ->
          Failed error
    )
  | Some cut -> (
      let at, residual =
        match cut with
        | Root_items residual ->
            (Json.Input.Root, residual)
        | Member_items (member, residual) ->
            (Json.Input.Member member, residual)
      in
      let step state item =
        let result =
          match state with
          | Completed acc ->
              fold ~colorize ~verbose ?env ~init:acc ~f (Plan residual) item
          | Failed _ | Halted _ ->
              state
        in
        match result with
        | Completed _ ->
            Json.Input.Continue result
        | Failed _ | Halted _ ->
            Json.Input.Validate_rest result
      in
      match Json.Input.fold_items ~at ~init:(Completed init) ~f:step source with
      | Error error ->
          Failed error
      | Ok (Folded result) ->
          result
      | Ok (Materialized (Whole json)) ->
          fold ~colorize ~verbose ?env ~init ~f query json
      | Ok (Materialized (Selected json)) ->
          fold ~colorize ~verbose ?env ~init ~f
            (Plan (pipe_plan (Many Iterate) residual))
            json
    )
