open Ast

let append_article (noun : string) =
  let starts_with_any (str : string) (chars : string list) =
    let rec loop (chars : string list) =
      match chars with
      | [] -> false
      | x :: xs -> if String.starts_with ~prefix:str x then true else loop xs
    in
    loop chars
  in
  match starts_with_any noun [ "a"; "e"; "i"; "o"; "u" ] with
  | true -> "an " ^ noun
  | false -> "a " ^ noun

let make_error_wrong_operation op member_kind (value : Json.t) =
  let open Console in
  "Trying to "
  ^ Formatting.single_quotes (Chalk.bold op)
  ^ " on "
  ^ (append_article member_kind |> Chalk.bold)
  ^ ":" ^ Formatting.enter 1
  ^ Chalk.gray (Json.to_string value ~colorize:false ~summarize:true)

let get_field_name json =
  match json with
  | `List _list -> "list"
  | `Assoc _assoc -> "object"
  | `Bool _b -> "bool"
  | `Float _f -> "float"
  | `Int _i -> "int"
  | `Null -> "null"
  | `String _identifier -> "string"
  | `Variant _ -> "variant"
  | `Tuple _ -> "list"
  | `Intlit _ -> "int"

let make_error (name : string) (json : Json.t) =
  let itemName = get_field_name json in
  make_error_wrong_operation name itemName json

module Output = struct
  let return x = Ok [ x ]
  let empty = Ok []

  let lift2 (f : 'a -> 'b -> 'c) (mx : ('a, string) result)
      (my : ('b, string) result) : ('c, string) result =
    match (mx, my) with
    | Ok x, Ok y -> Ok (f x y)
    | Error err, _ | _, Error err -> Error err

  let collect (xs : ('a list, string) result list) : ('a list, string) result =
    List.fold_right (lift2 ( @ )) xs empty

  let bind (mx : ('a list, string) result) (f : 'a -> ('b list, string) result)
      : ('b list, string) result =
    match mx with Ok xs -> collect (List.map f xs) | Error err -> Error err
end

let ( let* ) = Output.bind

module Operators = struct
  type 'a t =
    | Number of float * float
    | Str of string * string
    | Obj of (string * 'a) list * (string * 'a) list

  let not (json : Json.t) =
    match json with
    | `Bool false | `Null -> Output.return (`Bool true)
    | _ -> Output.return (`Bool false)

  let rec merge_map ~(eq_f : 'a -> 'a -> 'b) ~(f : 'a -> 'b)
      (cmp : 'a -> 'a -> int) (l1 : 'a list) (l2 : 'a list) : 'b list =
    match (l1, l2) with
    | [], l2 -> List.map f l2
    | l1, [] -> List.map f l1
    | h1 :: t1, h2 :: t2 ->
        let r = cmp h1 h2 in
        if r = 0 then eq_f h1 h2 :: merge_map ~eq_f ~f cmp t1 t2
        else if r < 0 then f h1 :: merge_map ~eq_f ~f cmp t1 l2
        else f h2 :: merge_map ~eq_f ~f cmp l1 t2

  let rec add str (left : Json.t) (right : Json.t) :
      (Json.t list, string) result =
    match (left, right) with
    | `Float l, `Float r -> Output.return (`Float (l +. r))
    | `Int l, `Float r -> Output.return (`Float (float_of_int l +. r))
    | `Float l, `Int r -> Output.return (`Float (l +. float_of_int r))
    | `Int l, `Int r ->
        Output.return (`Float (float_of_int l +. float_of_int r))
    | `Null, `Int r | `Int r, `Null -> Output.return (`Float (float_of_int r))
    | `Null, `Float r | `Float r, `Null -> Output.return (`Float r)
    | `String l, `String r -> Output.return (`String (l ^ r))
    | `Null, `String r | `String r, `Null -> Output.return (`String r)
    | `Assoc l, `Assoc r -> (
        let cmp (key1, _) (key2, _) = String.compare key1 key2 in
        let eq_f (key, v1) (_, v2) =
          let* result = add str v1 v2 in
          Output.return (key, result)
        in
        match merge_map ~f:Output.return ~eq_f cmp l r |> Output.collect with
        | Ok l -> Output.return (`Assoc l)
        | Error e -> Error e)
    | `Null, `Assoc r | `Assoc r, `Null -> Output.return (`Assoc r)
    | `List l, `List r -> Output.return (`List (l @ r))
    | `Null, `List r | `List r, `Null -> Output.return (`List r)
    | `Null, `Null -> Output.return `Null
    | _ -> Error (make_error str left)

  let apply_op str fn (left : Json.t) (right : Json.t) =
    match (left, right) with
    | `Float l, `Float r -> Output.return (`Float (fn l r))
    | `Int l, `Float r -> Output.return (`Float (fn (float_of_int l) r))
    | `Float l, `Int r -> Output.return (`Float (fn l (float_of_int r)))
    | `Int l, `Int r ->
        Output.return (`Float (fn (float_of_int l) (float_of_int r)))
    | _ -> Error (make_error str left)

  let compare str fn (left : Json.t) (right : Json.t) =
    match (left, right) with
    | `Float l, `Float r -> Output.return (`Bool (fn l r))
    | `Int l, `Float r -> Output.return (`Bool (fn (float_of_int l) r))
    | `Float l, `Int r -> Output.return (`Bool (fn l (float_of_int r)))
    | `Int l, `Int r ->
        Output.return (`Bool (fn (float_of_int l) (float_of_int r)))
    | _ -> Error (make_error str right)

  let condition (str : string) (fn : bool -> bool -> bool) (left : Json.t)
      (right : Json.t) =
    match (left, right) with
    | `Bool l, `Bool r -> Output.return (`Bool (fn l r))
    | _ -> Error (make_error str right)

  let gt = compare ">" ( > )
  let gte = compare ">=" ( >= )
  let lt = compare "<" ( < )
  let lte = compare "<=" ( <= )
  let and_ = condition "and" ( && )
  let or_ = condition "or" ( || )
  let eq l r = Output.return (`Bool (l = r))
  let notEq l r = Output.return (`Bool (l <> r))
  let add = add "+"
  let sub = apply_op "-" (fun l r -> l -. r)
  let mult = apply_op "*" (fun l r -> l *. r)
  let div = apply_op "/" (fun l r -> l /. r)
end

let keys (json : Json.t) =
  match json with
  | `Assoc _list ->
      Output.return (`List (Json.keys json |> List.map (fun i -> `String i)))
  | _ -> Error (make_error "keys" json)

let has (json : Json.t) key =
  match key with
  | String key -> (
      match json with
      | `Assoc list -> Output.return (`Bool (List.mem_assoc key list))
      | _ -> Error (make_error "has" json))
  | Number n -> (
      match json with
      | `List list ->
          Output.return (`Bool (List.length list - 1 >= int_of_float n))
      | _ -> Error (make_error "has" json))
  | _ -> Error (make_error "has" json)

let in_ (json : Json.t) expr =
  match json with
  | `Int n -> (
      match expr with
      | List list -> Output.return (`Bool (List.length list - 1 >= n))
      | _ -> Error (make_error "in" json))
  | `String key -> (
      match expr with
      | Object list ->
          let cmp_literal_str key = function
            | Literal (String s) when s = key -> true
            | _ -> false
          in
          let s = List.map fst list |> List.find_opt (cmp_literal_str key) in
          Output.return (`Bool (Option.is_some s))
      | _ -> Error (make_error "in" json))
  | _ -> Error (make_error "in" json)

let range ?step from upto =
  let rec range ?(step = 1) start stop =
    if step = 0 then []
    else if (step > 0 && start >= stop) || (step < 0 && start <= stop) then []
    else `Int start :: range ~step (start + step) stop
  in
  match upto with
  | None -> Output.return (range 1 from)
  | Some upto -> Output.return (range ?step from upto)

let split expr json =
  match json with
  | `String s ->
      let* rcase =
        match expr with
        | Literal (String s) -> Output.return s
        | _ -> Error "split input should be a string"
      in
      Output.return
        (`List (Str.split (Str.regexp rcase) s |> List.map (fun s -> `String s)))
  | _ -> Error "input should be a JSON string"

let join expr json =
  let* rcase =
    match expr with
    | Literal (String s) -> Output.return s
    | _ -> Error "join input should be a string"
  in
  match json with
  | `List l ->
      Output.return
        (`String
           (List.map (function `String s -> s | _ -> "") l
           |> String.concat rcase))
  | _ -> Error "input should be a list"

let length (json : Json.t) =
  match json with
  | `List list -> Output.return (`Int (list |> List.length))
  | _ -> Error (make_error "length" json)

let filter (fn : Json.t -> bool) (json : Json.t) =
  match json with
  | `List list -> Ok (`List (List.filter fn list))
  | _ -> Error (make_error "filter" json)

let make_empty_list_error op =
  let open Console in
  "Trying to "
  ^ Formatting.single_quotes (Chalk.bold op)
  ^ " on an empty array."

let make_acessing_to_missing_item access_index length =
  let open Console in
  "Trying to read "
  ^ Formatting.single_quotes
      ("[" ^ Chalk.bold (string_of_int access_index) ^ "]")
  ^ " from an array with " ^ string_of_int length ^ " elements only."

let head (json : Json.t) =
  match json with
  | `List list -> (
      match List.length list > 0 with
      | true -> Output.return (Json.index 0 json)
      | false -> Error (make_empty_list_error "head"))
  | _ -> Error (make_error "head" json)

let tail (json : Json.t) =
  match json with
  | `List list -> (
      match List.length list > 0 with
      | true ->
          let last_index = List.length list - 1 in
          Output.return (Json.index last_index json)
      | false -> Error (make_empty_list_error "tail"))
  | _ -> Error (make_error "tail" json)

let make_error_missing_member op key (value : Json.t) =
  let open Console in
  "Trying to "
  ^ Formatting.double_quotes (Chalk.bold op)
  ^ " on an object, that don't have the field "
  ^ Formatting.double_quotes key
  ^ ":" ^ Formatting.enter 1
  ^ Chalk.gray (Json.to_string value ~colorize:false ~summarize:true)

let member (key : string) (opt : bool) (json : Json.t) =
  match json with
  | `Assoc _assoc -> (
      let access_member = Json.member key json in
      match (access_member, opt) with
      | `Null, true -> Output.return access_member
      | `Null, false -> Error (make_error_missing_member ("." ^ key) key json)
      | _, false -> Output.return access_member
      | _, true -> Output.return access_member)
  | _ -> Error (make_error ("." ^ key) json)

let index (value : int) (json : Json.t) =
  match json with
  | `List list when List.length list > value ->
      Output.return (Json.index value json)
  | `List _ -> Output.return `Null
  | _ -> Error (make_error ("[" ^ string_of_int value ^ "]") json)

let slice (start : int option) (finish : int option) (json : Json.t) =
  let start =
    match (json, start) with
    | `String s, Some start when start > String.length s -> String.length s
    | `String s, Some start when start < 0 -> start + String.length s
    | `List l, Some start when start > List.length l -> List.length l
    | `List l, Some start when start < 0 -> start + List.length l
    | (`String _ | `List _), Some start -> start
    | (`String _ | `List _), None -> 0
    | _ -> (* slice can't be parsed outside of List or String *) assert false
  in
  let finish =
    match (json, finish) with
    | `String s, None -> String.length s
    | `String s, Some end_ when end_ > String.length s -> String.length s
    | `String s, Some end_ when end_ < 0 -> end_ + String.length s
    | `List l, None -> List.length l
    | `List l, Some end_ when end_ > List.length l -> List.length l
    | `List l, Some end_ when end_ < 0 -> end_ + List.length l
    | (`String _ | `List _), Some end_ -> end_
    | _ -> (* slice can't be parsed outside of List or String *) assert false
  in
  match json with
  | `String _s when finish < start -> Output.return (`String "")
  | `String s -> Output.return (`String (String.sub s start (finish - start)))
  | `List _l when finish < start -> Output.return (`List [])
  | `List l ->
      let sliced =
        List.fold_left
          (fun (acc, i) x ->
            if i >= start && i < finish then (x :: acc, i + 1) else (acc, i + 1))
          ([], 0) l
        |> fst |> List.rev
      in
      Output.return (`List sliced)
  | _ ->
      Error
        (make_error
           ("[" ^ string_of_int start ^ ":" ^ string_of_int finish ^ "]")
           json)

let rec compile expression json : (Json.t list, string) result =
  match expression with
  | Identity -> Output.return json
  | Empty -> Output.empty
  | Keys -> keys json
  | Key (key, opt) -> member key opt json
  | Index idx -> index idx json
  | Slice (start, finish) -> slice start finish json
  | Head -> head json
  | Tail -> tail json
  | Length -> length json
  | Not -> Operators.not json
  | Map expr -> map expr json
  | Operation (left, op, right) -> (
      let open Operators in
      match op with
      | Add -> operation left right add json
      | Sub -> operation left right sub json
      | Mult -> operation left right mult json
      | Div -> operation left right div json
      | Gt -> operation left right gt json
      | Ge -> operation left right gte json
      | St -> operation left right lt json
      | Se -> operation left right lte json
      | Eq -> operation left right eq json
      | Neq -> operation left right notEq json
      | And -> operation left right and_ json
      | Or -> operation left right or_ json)
  | Literal literal -> (
      match literal with
      | Bool b -> Output.return (`Bool b)
      | Number float -> Output.return (`Float float)
      | String string -> Output.return (`String string)
      | Null -> Output.return `Null)
  | Pipe (left, right) ->
      let* left = compile left json in
      compile right left
  | Select conditional -> (
      let* res = compile conditional json in
      match res with
      | `Bool b -> (
          match b with true -> Output.return json | false -> Output.empty)
      | _ -> Error (make_error "select" res))
  | List exprs ->
      Output.collect (List.map (fun expr -> compile expr json) exprs)
      |> Result.map (fun x -> [ `List x ])
  | Comma (leftR, rightR) ->
      Result.bind (compile leftR json) (fun left ->
          Result.bind (compile rightR json) (fun right -> Ok (left @ right)))
  | Object [] -> Output.return (`Assoc [])
  | Object list -> handle_objects list json
  | Has e -> (
      match e with
      | Literal ((String _ | Number _) as e) -> has json e
      | _ -> Error (show_expression e ^ " is not allowed"))
  | In e -> in_ json e
  | Range (from, upto, step) -> Result.map List.flatten (range ?step from upto)
  | Reverse -> (
      match json with
      | `List l -> Output.return (`List (List.rev l))
      | _ -> Error (make_error "reverse" json))
  | Split expr -> split expr json
  | Join expr -> join expr json
  | Abs -> (
      match json with
      | `Int n -> Output.return (`Int (if n < 0 then -n else n))
      | `Float j -> Output.return (`Float (if j < 0. then -.j else j))
      | _ -> Error (make_error "reverse" json))
  | AddFun -> (
      match json with
      | `List [] -> Output.return `Null
      | `List l ->
          List.fold_left
            (fun acc el ->
              let* acc = acc in
              Operators.add acc el)
            (Output.return `Null) l
      | _ -> Error (make_error "add" json))
  | IfThenElse (cond, if_branch, else_branch) -> (
      let* cond = compile cond json in
      match cond with
      | `Bool b ->
          if b then compile if_branch json else compile else_branch json
      | json -> Error (make_error "if condition should be a bool" json))
  | _ -> Error (show_expression expression ^ " is not implemented")

and operation leftR rightR op json =
  let* left = compile leftR json in
  let* right = compile rightR json in
  op left right

and map (expr : expression) (json : Json.t) =
  match json with
  | `List list when List.length list > 0 ->
      Output.collect (List.map (compile expr) list)
      |> Result.map (fun x -> [ `List x ])
  | `List _list -> Error (make_empty_list_error "map")
  | _ -> Error (make_error "map" json)

and handle_objects list json =
  List.map
    (fun (left_expr, right_expr) ->
      match (left_expr, right_expr) with
      | Literal (String n), None ->
          (* Search for this key in JSON *)
          let r =
            match json with
            | `Null -> Output.return (`Assoc [ (n, `Null) ])
            | `Assoc l -> (
                match List.assoc_opt n l with
                | None -> Output.return (`Assoc [ (n, `Null) ])
                | Some v -> Output.return (`Assoc [ (n, v) ]))
            | _ -> Error (Json.show json ^ " is not implemented")
          in
          r
      | Literal (String key), Some right_expr -> (
          match right_expr with
          | Key (search_val, _) -> (
              match json with
              | `Assoc l -> (
                  match List.assoc_opt search_val l with
                  | None -> Output.return (`Assoc [ (key, `Null) ])
                  | Some v -> Output.return (`Assoc [ (key, v) ]))
              | _ -> assert false)
          | rexp ->
              let* rexp = compile rexp json in
              Output.return (`Assoc [ (key, rexp) ]))
      | _ -> Error (show_expression left_expr ^ " is not implemented"))
    list
  |> Output.collect
