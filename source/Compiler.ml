open Ast

let appendArticle (noun : string) =
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

let makeErrorWrongOperation op memberKind (value : Json.t) =
  let open Console in
  "Trying to "
  ^ Formatting.singleQuotes (Chalk.bold op)
  ^ " on "
  ^ (appendArticle memberKind |> Chalk.bold)
  ^ ":" ^ Formatting.enter 1
  ^ Chalk.gray (Json.toString value ~colorize:false ~summarize:true)

let getFieldName json =
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

let makeError (name : string) (json : Json.t) =
  let itemName = getFieldName json in
  makeErrorWrongOperation name itemName json

let empty = Ok []

module Results = struct
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

let ( let* ) = Results.bind

let keys (json : Json.t) =
  match json with
  | `Assoc _list ->
      Results.return (`List (Json.keys json |> List.map (fun i -> `String i)))
  | _ -> Error (makeError "keys" json)

let length (json : Json.t) =
  match json with
  | `List list -> Results.return (`Int (list |> List.length))
  | _ -> Error (makeError "length" json)

let not__ (json : Json.t) =
  match json with
  | `Bool false | `Null -> Results.return (`Bool true)
  | _ -> Results.return (`Bool false)

let apply (str : string) (fn : float -> float -> float) (left : Json.t)
    (right : Json.t) =
  match (left, right) with
  | `Float l, `Float r -> Results.return (`Float (fn l r))
  | `Int l, `Float r -> Results.return (`Float (fn (float_of_int l) r))
  | `Float l, `Int r -> Results.return (`Float (fn l (float_of_int r)))
  | `Int l, `Int r ->
      Results.return (`Float (fn (float_of_int l) (float_of_int r)))
  | _ -> Error (makeError str left)

let compare (str : string) (fn : float -> float -> bool) (left : Json.t)
    (right : Json.t) =
  match (left, right) with
  | `Float l, `Float r -> Results.return (`Bool (fn l r))
  | `Int l, `Float r -> Results.return (`Bool (fn (float_of_int l) r))
  | `Float l, `Int r -> Results.return (`Bool (fn l (float_of_int r)))
  | `Int l, `Int r ->
      Results.return (`Bool (fn (float_of_int l) (float_of_int r)))
  | _ -> Error (makeError str right)

let condition (str : string) (fn : bool -> bool -> bool) (left : Json.t)
    (right : Json.t) =
  match (left, right) with
  | `Bool l, `Bool r -> Results.return (`Bool (fn l r))
  | _ -> Error (makeError str right)

let gt = compare ">" ( > )
let gte = compare ">=" ( >= )
let lt = compare "<" ( < )
let lte = compare "<=" ( <= )
let and_ = condition "and" ( && )
let or_ = condition "or" ( || )
let eq l r = Results.return (`Bool (l = r))
let notEq l r = Results.return (`Bool (l <> r))
let add = apply "+" (fun l r -> l +. r)
let sub = apply "-" (fun l r -> l -. r)
let mult = apply "*" (fun l r -> l *. r)
let div = apply "/" (fun l r -> l /. r)

let filter (fn : Json.t -> bool) (json : Json.t) =
  match json with
  | `List list -> Ok (`List (List.filter fn list))
  | _ -> Error (makeError "filter" json)

let makeEmptyListError op =
  let open Console in
  "Trying to " ^ Formatting.singleQuotes (Chalk.bold op) ^ " on an empty array."

let makeAcessingToMissingItem accessIndex length =
  let open Console in
  "Trying to read "
  ^ Formatting.singleQuotes ("[" ^ Chalk.bold (string_of_int accessIndex) ^ "]")
  ^ " from an array with " ^ string_of_int length ^ " elements only."

let head (json : Json.t) =
  match json with
  | `List list -> (
      match List.length list > 0 with
      | true -> Results.return (Json.index 0 json)
      | false -> Error (makeEmptyListError "head"))
  | _ -> Error (makeError "head" json)

let tail (json : Json.t) =
  match json with
  | `List list -> (
      match List.length list > 0 with
      | true ->
          let lastIndex = List.length list - 1 in
          Results.return (Json.index lastIndex json)
      | false -> Error (makeEmptyListError "tail"))
  | _ -> Error (makeError "tail" json)

let makeErrorMissingMember op key (value : Json.t) =
  let open Console in
  "Trying to "
  ^ Formatting.doubleQuotes (Chalk.bold op)
  ^ " on an object, that don't have the field "
  ^ Formatting.doubleQuotes key
  ^ ":" ^ Formatting.enter 1
  ^ Chalk.gray (Json.toString value ~colorize:false ~summarize:true)

let member (key : string) (opt : bool) (json : Json.t) =
  match json with
  | `Assoc _assoc -> (
      let accessMember = Json.member key json in
      match (accessMember, opt) with
      | `Null, true -> Results.return accessMember
      | `Null, false -> Error (makeErrorMissingMember ("." ^ key) key json)
      | _, false -> Results.return accessMember
      | _, true -> Results.return accessMember)
  | _ -> Error (makeError ("." ^ key) json)

let index (value : int) (json : Json.t) =
  match json with
  | `List list when List.length list > value ->
      Results.return (Json.index value json)
  | `List list -> Error (makeAcessingToMissingItem value (List.length list))
  | _ -> Error (makeError ("[" ^ string_of_int value ^ "]") json)

let rec compile expression json : (Json.t list, string) result =
  match expression with
  | Identity -> Results.return json
  | Empty -> empty
  | Keys -> keys json
  | Key (key, opt) -> member key opt json
  | Index idx -> index idx json
  | Head -> head json
  | Tail -> tail json
  | Length -> length json
  | Not -> not__ json
  | Map expr -> map expr json
  | Addition (left, right) -> operation left right add json
  | Subtraction (left, right) -> operation left right sub json
  | Multiply (left, right) -> operation left right mult json
  | Division (left, right) -> operation left right div json
  | Literal literal -> (
      match literal with
      | Bool b -> Results.return (`Bool b)
      | Number float -> Results.return (`Float float)
      | String string -> Results.return (`String string)
      | Null -> Results.return `Null)
  | Pipe (left, right) -> Results.bind (compile left json) (compile right)
  | Select conditional ->
      Results.bind (compile conditional json) (fun res ->
          match res with
          | `Bool b -> (
              match b with true -> Results.return json | false -> empty)
          | _ -> Error (makeError "select" res))
  | Greater (left, right) -> operation left right gt json
  | GreaterEqual (left, right) -> operation left right gte json
  | Lower (left, right) -> operation left right lt json
  | LowerEqual (left, right) -> operation left right lte json
  | Equal (left, right) -> operation left right eq json
  | NotEqual (left, right) -> operation left right notEq json
  | And (left, right) -> operation left right and_ json
  | Or (left, right) -> operation left right or_ json
  | List expr ->
      Result.bind (compile expr json) (fun xs -> Results.return (`List xs))
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
      Results.collect (List.map (fun item -> compile expr item) list)
      |> Result.map (fun x -> [ `List x ])
  | `List _list -> Error (makeEmptyListError "map")
  | _ -> Error (makeError "map" json)
