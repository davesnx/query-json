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

let empty = Ok []

module Output = struct
  let return x = Ok [ x ]

  let lift2 (f : 'a -> 'b -> 'c) (mx : ('a, string) result)
      (my : ('b, string) result) : ('c, string) result =
    match mx with
    | Ok x -> ( match my with Ok y -> Ok (f x y) | Error err -> Error err)
    | Error err -> Error err

  let collect (xs : ('a list, string) result list) : ('a list, string) result =
    List.fold_right (lift2 ( @ )) xs empty

  let bind (mx : ('a list, string) result) (f : 'a -> ('b list, string) result)
      : ('b list, string) result =
    match mx with Ok xs -> collect (List.map f xs) | Error err -> Error err
end

let ( let* ) = Output.bind

let keys (json : Json.t) =
  match json with
  | `Assoc _list ->
      Output.return (`List (Json.keys json |> List.map (fun i -> `String i)))
  | _ -> Error (make_error "keys" json)

let length (json : Json.t) =
  match json with
  | `List list -> Output.return (`Int (list |> List.length))
  | _ -> Error (make_error "length" json)

let not (json : Json.t) =
  match json with
  | `Bool false | `Null -> Output.return (`Bool true)
  | _ -> Output.return (`Bool false)

let apply str fn (left : Json.t) (right : Json.t) =
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
let add = apply "+" (fun l r -> l +. r)
let sub = apply "-" (fun l r -> l -. r)
let mult = apply "*" (fun l r -> l *. r)
let div = apply "/" (fun l r -> l /. r)

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
  | `List list -> Error (make_acessing_to_missing_item value (List.length list))
  | _ -> Error (make_error ("[" ^ string_of_int value ^ "]") json)

let rec compile expression json : (Json.t list, string) result =
  match expression with
  | Identity -> Output.return json
  | Empty -> empty
  | Keys -> keys json
  | Key (key, opt) -> member key opt json
  | Index idx -> index idx json
  | Head -> head json
  | Tail -> tail json
  | Length -> length json
  | Not -> not json
  | Map expr -> map expr json
  | Addition (left, right) -> operation left right add json
  | Subtraction (left, right) -> operation left right sub json
  | Multiply (left, right) -> operation left right mult json
  | Division (left, right) -> operation left right div json
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
      | `Bool b -> ( match b with true -> Output.return json | false -> empty)
      | _ -> Error (make_error "select" res))
  | Greater (left, right) -> operation left right gt json
  | GreaterEqual (left, right) -> operation left right gte json
  | Lower (left, right) -> operation left right lt json
  | LowerEqual (left, right) -> operation left right lte json
  | Equal (left, right) -> operation left right eq json
  | NotEqual (left, right) -> operation left right notEq json
  | And (left, right) -> operation left right and_ json
  | Or (left, right) -> operation left right or_ json
  | List exprs ->
      Output.collect (List.map (fun expr -> compile expr json) exprs)
      |> Result.map (fun x -> [ `List x ])
  | Comma (leftR, rightR) ->
      Result.bind (compile leftR json) (fun left ->
          Result.bind (compile rightR json) (fun right -> Ok (left @ right)))
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
