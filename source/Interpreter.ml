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

let make_error_wrong_operation ~colorize op member_kind (value : Json.t) =
  let module Chalk = Chalk.Make (struct
    let disable = not colorize
  end) in
  "Trying to "
  ^ Console.Formatting.single_quotes (Chalk.bold op)
  ^ " on "
  ^ Chalk.bold (append_article member_kind)
  ^ ":" ^ Console.Formatting.enter 1
  ^ Chalk.gray (Json.to_string value ~colorize ~summarize:true)

let make_empty_list_error ~colorize op =
  let module Chalk = Chalk.Make (struct
    let disable = not colorize
  end) in
  "Trying to "
  ^ Console.Formatting.single_quotes (Chalk.bold op)
  ^ " on an empty array."

let get_field_name json =
  match json with
  | `List _ -> "list"
  | `Assoc _ -> "object"
  | `Bool _ -> "bool"
  | `Float _ -> "float"
  | `Int _ -> "int"
  | `Null -> "null"
  | `String _ -> "string"
  | `Intlit _ -> "int"

let make_error ~colorize (name : string) (json : Json.t) =
  let item_name = get_field_name json in
  make_error_wrong_operation ~colorize name item_name json

module Output = struct
  let ok x = Ok x
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
  let not (json : Json.t) =
    match json with
    | `Bool false | `Null -> Output.return (`Bool true)
    | _ -> Output.return (`Bool false)

  let rec merge_map ~(eq : 'a -> 'a -> 'b) ~(f : 'a -> 'b)
      (cmp : 'a -> 'a -> int) (l1 : 'a list) (l2 : 'a list) : 'b list =
    match (l1, l2) with
    | [], l2 -> List.map f l2
    | l1, [] -> List.map f l1
    | h1 :: t1, h2 :: t2 ->
        let r = cmp h1 h2 in
        if r = 0 then eq h1 h2 :: merge_map ~eq ~f cmp t1 t2
        else if r < 0 then f h1 :: merge_map ~eq ~f cmp t1 l2
        else f h2 :: merge_map ~eq ~f cmp l1 t2

  let rec add ~colorize str (left : Json.t) (right : Json.t) :
      (Json.t list, string) result =
    match (left, right) with
    | `Float l, `Float r -> Output.return (`Float (l +. r))
    | `Int l, `Float r -> Output.return (`Float (Int.to_float l +. r))
    | `Float l, `Int r -> Output.return (`Float (l +. Int.to_float r))
    | `Int l, `Int r ->
        Output.return (`Float (Int.to_float l +. Int.to_float r))
    | `Null, `Int r | `Int r, `Null -> Output.return (`Float (Int.to_float r))
    | `Null, `Float r | `Float r, `Null -> Output.return (`Float r)
    | `String l, `String r -> Output.return (`String (l ^ r))
    | `Null, `String r | `String r, `Null -> Output.return (`String r)
    | `Assoc l, `Assoc r -> (
        let cmp (key1, _) (key2, _) = String.compare key1 key2 in
        let eq (key, v1) (_, v2) =
          let* result = add ~colorize str v1 v2 in
          Output.return (key, result)
        in
        match merge_map ~f:Output.return ~eq cmp l r |> Output.collect with
        | Ok l -> Output.return (`Assoc l)
        | Error e -> Error e)
    | `Null, `Assoc r | `Assoc r, `Null -> Output.return (`Assoc r)
    | `List l, `List r -> Output.return (`List (l @ r))
    | `Null, `List r | `List r, `Null -> Output.return (`List r)
    | `Null, `Null -> Output.return `Null
    | _ -> Error (make_error ~colorize str left)

  let apply_operation ~colorize str fn (left : Json.t) (right : Json.t) =
    match (left, right) with
    | `Float l, `Float r -> Output.return (`Float (fn l r))
    | `Int l, `Float r -> Output.return (`Float (fn (Int.to_float l) r))
    | `Float l, `Int r -> Output.return (`Float (fn l (Int.to_float r)))
    | `Int l, `Int r ->
        Output.return (`Float (fn (Int.to_float l) (Int.to_float r)))
    | _ -> Error (make_error ~colorize str left)

  let compare ~colorize str fn (left : Json.t) (right : Json.t) =
    match (left, right) with
    | `Float l, `Float r -> Output.return (`Bool (fn l r))
    | `Int l, `Float r -> Output.return (`Bool (fn (Int.to_float l) r))
    | `Float l, `Int r -> Output.return (`Bool (fn l (Int.to_float r)))
    | `Int l, `Int r ->
        Output.return (`Bool (fn (Int.to_float l) (Int.to_float r)))
    | _ -> Error (make_error ~colorize str right)

  let condition ~colorize (str : string) (fn : bool -> bool -> bool)
      (left : Json.t) (right : Json.t) =
    match (left, right) with
    | `Bool l, `Bool r -> Output.return (`Bool (fn l r))
    | _ -> Error (make_error ~colorize str right)

  let gt ~colorize = compare ~colorize ">" ( > )
  let gte ~colorize = compare ~colorize ">=" ( >= )
  let lt ~colorize = compare ~colorize "<" ( < )
  let lte ~colorize = compare ~colorize "<=" ( <= )
  let and_ ~colorize = condition ~colorize "and" ( && )
  let or_ ~colorize = condition ~colorize "or" ( || )
  let equal l r = Output.return (`Bool (l = r))
  let not_equal l r = Output.return (`Bool (l <> r))

  (* Since + is used to concat strings, objects, lists, we don't use apply_operation *)
  let add ~colorize = add ~colorize "+"
  let subtract ~colorize = apply_operation ~colorize "-" (fun l r -> l -. r)
  let multiply ~colorize = apply_operation ~colorize "*" (fun l r -> l *. r)
  let divide ~colorize = apply_operation ~colorize "/" (fun l r -> l /. r)

  let modulo ~colorize =
    apply_operation ~colorize "%" (fun l r -> mod_float l r)
end

let keys ~colorize (json : Json.t) =
  match json with
  | `Assoc _list ->
      Output.return (`List (Json.keys json |> List.map (fun i -> `String i)))
  | _ -> Error (make_error ~colorize "keys" json)

let has ~colorize (json : Json.t) key =
  match key with
  | String key -> (
      match json with
      | `Assoc list -> Output.return (`Bool (List.mem_assoc key list))
      | _ -> Error (make_error ~colorize "has" json))
  | Number n -> (
      match json with
      | `List list ->
          Output.return (`Bool (List.length list - 1 >= int_of_float n))
      | _ -> Error (make_error ~colorize "has" json))
  | _ -> Error (make_error ~colorize "has" json)

let range ?step from upto =
  let rec range ?(step = 1) start stop =
    if step = 0 then []
    else if (step > 0 && start >= stop) || (step < 0 && start <= stop) then []
    else start :: range ~step (start + step) stop
  in
  match upto with None -> range 1 from | Some upto -> range ?step from upto

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

let length ~colorize (json : Json.t) =
  match json with
  | `List list -> Output.return (`Int (List.length list))
  | _ -> Error (make_error ~colorize "length" json)

let emit_warning ~verbose message =
  if verbose then Printf.eprintf "Warning: %s\n%!" message else ()

let type_of (json : Json.t) =
  let type_name =
    match json with
    | `List _ -> "array"
    | `Assoc _ -> "object"
    | `Bool _ -> "boolean"
    | `Float _ | `Int _ | `Intlit _ -> "number"
    | `Null -> "null"
    | `String _ -> "string"
  in
  Output.return (`String type_name)

let floor ~colorize (json : Json.t) =
  match json with
  | `Float f -> Output.return (`Int (int_of_float (floor f)))
  | `Int n -> Output.return (`Int n)
  | _ -> Error (make_error ~colorize "floor" json)

let sqrt ~colorize (json : Json.t) =
  match json with
  | `Float f -> Output.return (`Float (sqrt f))
  | `Int n -> Output.return (`Float (sqrt (float_of_int n)))
  | _ -> Error (make_error ~colorize "sqrt" json)

let to_number ~colorize ~verbose ~deprecated (json : Json.t) =
  let name = if deprecated then "tonumber" else "to_number" in
  if deprecated then
    emit_warning ~verbose
      "Using deprecated 'tonumber'. Use 'to_number' instead. This may not be \
       supported in future versions.";
  match json with
  | `String s -> (
      try Output.return (`Float (float_of_string s))
      with Failure _ -> Error (make_error ~colorize name json))
  | `Int _ | `Float _ -> Output.return json
  | _ -> Error (make_error ~colorize name json)

let to_string ~verbose ~deprecated (json : Json.t) =
  if deprecated then
    emit_warning ~verbose
      "Using deprecated 'tostring'. Use 'to_string' instead. This may not be \
       supported in future versions.";
  Output.return (`String (Json.to_string ~colorize:false ~summarize:false json))

let min ~colorize (json : Json.t) =
  match json with
  | `List [] -> Error (make_empty_list_error ~colorize "min")
  | `List l ->
      let compare_json a b =
        match (a, b) with
        | `Int x, `Int y -> compare x y
        | `Float x, `Float y -> compare x y
        | `Int x, `Float y -> compare (float_of_int x) y
        | `Float x, `Int y -> compare x (float_of_int y)
        | _ -> 0
      in
      Output.return
        (List.fold_left
           (fun acc x -> if compare_json x acc < 0 then x else acc)
           (List.hd l) (List.tl l))
  | _ -> Error (make_error ~colorize "min" json)

let max ~colorize (json : Json.t) =
  match json with
  | `List [] -> Error (make_empty_list_error ~colorize "max")
  | `List l ->
      let compare_json a b =
        match (a, b) with
        | `Int x, `Int y -> compare x y
        | `Float x, `Float y -> compare x y
        | `Int x, `Float y -> compare (float_of_int x) y
        | `Float x, `Int y -> compare x (float_of_int y)
        | _ -> 0
      in
      Output.return
        (List.fold_left
           (fun acc x -> if compare_json x acc > 0 then x else acc)
           (List.hd l) (List.tl l))
  | _ -> Error (make_error ~colorize "max" json)

let flatten ~colorize depth_opt (json : Json.t) =
  match json with
  | `List l ->
      let depth = match depth_opt with Some d -> d | None -> 1 in
      let rec flatten_n n lst =
        if n <= 0 then lst
        else
          List.fold_left
            (fun acc item ->
              match item with
              | `List inner -> acc @ flatten_n (n - 1) inner
              | other -> acc @ [ other ])
            [] lst
      in
      Output.return (`List (flatten_n depth l))
  | _ -> Error (make_error ~colorize "flatten" json)

let sort ~colorize (json : Json.t) =
  match json with
  | `List l ->
      let compare_json a b =
        match (a, b) with
        | `Int x, `Int y -> compare x y
        | `Float x, `Float y -> compare x y
        | `Int x, `Float y -> compare (float_of_int x) y
        | `Float x, `Int y -> compare x (float_of_int y)
        | `String x, `String y -> compare x y
        | _ -> 0
      in
      Output.return (`List (List.sort compare_json l))
  | _ -> Error (make_error ~colorize "sort" json)

let unique ~colorize (json : Json.t) =
  match json with
  | `List l ->
      let rec unique acc = function
        | [] -> List.rev acc
        | x :: xs ->
            if List.mem x acc then unique acc xs else unique (x :: acc) xs
      in
      Output.return (`List (unique [] l))
  | _ -> Error (make_error ~colorize "unique" json)

let any ~colorize (json : Json.t) =
  match json with
  | `List l ->
      let is_truthy = function `Bool false | `Null -> false | _ -> true in
      Output.return (`Bool (List.exists is_truthy l))
  | _ -> Error (make_error ~colorize "any" json)

let all ~colorize (json : Json.t) =
  match json with
  | `List l ->
      let is_truthy = function `Bool false | `Null -> false | _ -> true in
      Output.return (`Bool (List.for_all is_truthy l))
  | _ -> Error (make_error ~colorize "all" json)

let to_entries ~colorize (json : Json.t) =
  match json with
  | `Assoc obj ->
      let entries =
        List.map
          (fun (key, value) ->
            `Assoc [ ("key", `String key); ("value", value) ])
          obj
      in
      Output.return (`List entries)
  | _ -> Error (make_error ~colorize "to_entries" json)

let from_entries ~colorize (json : Json.t) =
  match json with
  | `List entries -> (
      let rec convert acc = function
        | [] -> Ok (List.rev acc)
        | entry :: rest -> (
            match entry with
            | `Assoc fields -> (
                let key = List.assoc_opt "key" fields in
                let value = List.assoc_opt "value" fields in
                match (key, value) with
                | Some (`String k), Some v -> convert ((k, v) :: acc) rest
                | _ ->
                    Error
                      "from_entries requires objects with 'key' (string) and \
                       'value' fields")
            | _ -> Error "from_entries requires an array of objects")
      in
      match convert [] entries with
      | Ok obj -> Output.return (`Assoc obj)
      | Error e -> Error e)
  | _ -> Error (make_error ~colorize "from_entries" json)

let explode ~colorize (json : Json.t) =
  match json with
  | `String s ->
      let codepoints =
        List.init (String.length s) (fun i -> `Int (Char.code (String.get s i)))
      in
      Output.return (`List codepoints)
  | _ -> Error (make_error ~colorize "explode" json)

let implode ~colorize (json : Json.t) =
  match json with
  | `List l ->
      let chars =
        List.map (function `Int n -> Char.chr n | _ -> Char.chr 0) l
      in
      Output.return (`String (String.of_seq (List.to_seq chars)))
  | _ -> Error (make_error ~colorize "implode" json)

let nan_value () = Output.return (`Float nan)

let is_nan ~colorize (json : Json.t) =
  match json with
  | `Float f -> Output.return (`Bool (Float.is_nan f))
  | `Int _ -> Output.return (`Bool false)
  | _ -> Error (make_error ~colorize "is_nan" json)

let transpose ~colorize (json : Json.t) =
  match json with
  | `List [] -> Output.return (`List [])
  | `List rows ->
      let get_length row =
        match row with `List l -> Some (List.length l) | _ -> None
      in
      let lengths = List.filter_map get_length rows in
      if List.length lengths <> List.length rows then
        Error "transpose requires an array of arrays"
      else
        let max_len = List.fold_left Int.max 0 lengths in
        let get_column i =
          List.filter_map
            (fun row ->
              match row with
              | `List l when i < List.length l -> Some (List.nth l i)
              | _ -> None)
            rows
        in
        let transposed = List.init max_len (fun i -> `List (get_column i)) in
        Output.return (`List transposed)
  | _ -> Error (make_error ~colorize "transpose" json)

let recurse_down json =
  let rec descend acc current =
    match current with
    | `List items ->
        let new_items = List.concat_map (fun item -> descend [] item) items in
        new_items @ (current :: acc)
    | `Assoc fields ->
        let new_values = List.concat_map (fun (_, v) -> descend [] v) fields in
        new_values @ (current :: acc)
    | other -> other :: acc
  in
  Ok (descend [] json)

let test_regex ~colorize pattern json =
  match json with
  | `String s -> (
      try
        let regex = Str.regexp pattern in
        let _ = Str.search_forward regex s 0 in
        Output.return (`Bool true)
      with Not_found -> Output.return (`Bool false))
  | _ -> Error (make_error ~colorize "test" json)

let filter ~colorize (fn : Json.t -> bool) (json : Json.t) =
  match json with
  | `List list -> Ok (`List (List.filter fn list))
  | _ -> Error (make_error ~colorize "filter" json)

let head ~colorize (json : Json.t) =
  match json with
  | `List list -> (
      match List.length list > 0 with
      | true -> Output.return (Json.index 0 json)
      | false -> Error (make_empty_list_error ~colorize "head"))
  | _ -> Error (make_error ~colorize "head" json)

let tail ~colorize (json : Json.t) =
  match json with
  | `List list -> (
      match List.length list > 0 with
      | true ->
          let last_index = List.length list - 1 in
          Output.return (Json.index last_index json)
      | false -> Error (make_empty_list_error ~colorize "tail"))
  | _ -> Error (make_error ~colorize "tail" json)

let make_error_missing_member ~colorize op key (value : Json.t) =
  let open Console in
  let module Chalk = Chalk.Make (struct
    let disable = not colorize
  end) in
  "Trying to "
  ^ Formatting.double_quotes (Chalk.bold op)
  ^ " on an object, that don't have the field "
  ^ Formatting.double_quotes key
  ^ ":" ^ Formatting.enter 1
  ^ Chalk.gray (Json.to_string value ~colorize ~summarize:true)

let member ~colorize (key : string) (json : Json.t) =
  match json with
  | `Assoc _assoc -> (
      let access_member = Json.member key json in
      match access_member with
      | `Null ->
          Error (make_error_missing_member ~colorize ("." ^ key) key json)
      | _ -> Output.return access_member)
  | _ -> Error (make_error ~colorize ("." ^ key) json)

let iterator ~colorize (json : Json.t) =
  match json with
  | `List [] -> Output.empty
  | `List items -> Ok items
  | `Assoc obj -> Ok (List.map snd obj)
  | _ -> Error (make_error ~colorize "[]" json)

let rec index ~colorize (indices : int list) (json : Json.t) =
  match indices with
  | [] -> iterator ~colorize json
  | [ value ] -> (
      match json with
      | `List list when List.length list > value ->
          Output.return (Json.index value json)
      | `List _ -> Output.return `Null
      | _ -> Error (make_error ~colorize ("[" ^ Int.to_string value ^ "]") json)
      )
  | multiple ->
      List.map (fun idx -> index ~colorize [ idx ] json) multiple
      |> Output.collect

let slice ~colorize (start : int option) (finish : int option) (json : Json.t) =
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
        (make_error ~colorize
           ("[" ^ Int.to_string start ^ ":" ^ Int.to_string finish ^ "]")
           json)

type env = (string * Json.t) list

let rec interp ~colorize ~verbose ?(env = []) expression json :
    (Json.t list, string) result =
  match expression with
  | Identity -> Output.return json
  | Empty -> Output.empty
  | Keys -> keys ~colorize json
  | Key key -> member ~colorize key json
  | Optional expr -> (
      match interp ~colorize ~verbose expr json with
      | Ok values -> Output.ok values
      | Error _ -> Output.return `Null)
  | Index idx -> index ~colorize idx json
  | Iterator -> iterator ~colorize json
  | Slice (start, finish) -> slice ~colorize start finish json
  | Head -> head ~colorize json
  | Tail -> tail ~colorize json
  | Length -> length ~colorize json
  | Not -> Operators.not json
  | Type -> type_of json
  | Floor -> floor ~colorize json
  | Sqrt -> sqrt ~colorize json
  | To_number -> to_number ~colorize ~verbose ~deprecated:false json
  | Tonumber -> to_number ~colorize ~verbose ~deprecated:true json
  | To_string -> to_string ~verbose ~deprecated:false json
  | Tostring -> to_string ~verbose ~deprecated:true json
  | Min -> min ~colorize json
  | Max -> max ~colorize json
  | Flatten depth_opt -> flatten ~colorize depth_opt json
  | Sort -> sort ~colorize json
  | Unique -> unique ~colorize json
  | Any -> any ~colorize json
  | All -> all ~colorize json
  | Starts_with expr ->
      starts_with ~colorize ~verbose ~is_deprecated:false expr json
  | Startwith expr ->
      starts_with ~colorize ~verbose ~is_deprecated:true expr json
  | Ends_with expr ->
      ends_with ~colorize ~verbose ~is_deprecated:false expr json
  | Endwith expr -> ends_with ~colorize ~verbose ~is_deprecated:true expr json
  | To_entries -> to_entries ~colorize json
  | From_entries -> from_entries ~colorize json
  | With_entries expr -> with_entries ~colorize ~verbose expr json
  | Contains expr -> contains ~colorize ~verbose expr json
  | Explode -> explode ~colorize json
  | Implode -> implode ~colorize json
  | Map expr -> map ~colorize ~verbose expr json
  | Operation (left, op, right) ->
      operation ~colorize ~verbose ~env left right op json
  | Literal literal -> (
      match literal with
      | Bool b -> Output.return (`Bool b)
      | Number f -> Output.return (`Float f)
      | String s -> Output.return (`String s)
      | Null -> Output.return `Null)
  | Pipe (left, right) ->
      let* left = interp ~colorize ~verbose left json in
      interp ~colorize ~verbose right left
  | Update (path, transform) ->
      let* path_result = interp ~colorize ~verbose path json in
      interp ~colorize ~verbose transform path_result
  | Alternative (left, right) -> alternative ~colorize ~verbose left right json
  | Select conditional -> (
      let* res = interp ~colorize ~verbose conditional json in
      match res with
      | `Bool b -> (
          match b with true -> Output.return json | false -> Output.empty)
      | _ -> Error (make_error ~colorize "select" res))
  | List None -> Output.return (`List [])
  | List (Some expr) ->
      interp ~colorize ~verbose expr json |> Result.map (fun x -> [ `List x ])
  | Comma (left_expr, right_expr) ->
      Result.bind (interp ~colorize ~verbose left_expr json) (fun left ->
          Result.bind (interp ~colorize ~verbose right_expr json) (fun right ->
              Ok (left @ right)))
  | Object [] -> Output.return (`Assoc [])
  | Object list -> objects ~colorize ~verbose list json
  | Has expr -> (
      match expr with
      | Literal ((String _ | Number _) as expr) -> has ~colorize json expr
      | _ -> Error (show_expression expr ^ " is not allowed"))
  | In expr -> in_ ~colorize ~verbose json expr
  | Range (from, upto, step) ->
      Output.ok (range ?step from upto |> List.map (fun i -> `Int i))
  | Reverse -> (
      match json with
      | `List l -> Output.return (`List (List.rev l))
      | _ -> Error (make_error ~colorize "reverse" json))
  | Split expr -> split expr json
  | Join expr -> join expr json
  | Fun builtin -> builtin_functions ~colorize builtin json
  | If_then_else (cond, if_branch, else_branch) -> (
      let* cond = interp ~colorize ~verbose cond json in
      match cond with
      | `Bool b ->
          if b then interp ~colorize ~verbose if_branch json
          else interp ~colorize ~verbose else_branch json
      | json ->
          Error (make_error ~colorize "if condition should be a bool" json))
  | Sort_by expr -> sort_by ~colorize ~verbose expr json
  | Min_by expr -> min_by ~colorize ~verbose expr json
  | Max_by expr -> max_by ~colorize ~verbose expr json
  | Unique_by expr -> unique_by ~colorize ~verbose expr json
  | Index_of expr -> index_of ~colorize ~verbose expr json
  | Rindex_of expr -> rindex_of ~colorize ~verbose expr json
  | Group_by expr -> group_by ~colorize ~verbose expr json
  | While (cond, update) -> while_loop ~colorize ~verbose cond update json
  | Until (cond, update) -> until_loop ~colorize ~verbose cond update json
  | Recurse -> recurse_simple ~colorize ~verbose json
  | Recurse_with (f, cond) -> recurse_with_cond ~colorize ~verbose f cond json
  | Recurse_down -> recurse_down json
  | Walk expr -> walk_tree ~colorize ~verbose expr json
  | Transpose expr ->
      let* values = interp ~colorize ~verbose expr json in
      transpose ~colorize values
  | Nan -> nan_value ()
  | Is_nan -> is_nan ~colorize json
  | Flat_map expr -> flat_map ~colorize ~verbose expr json
  | Find expr -> find ~colorize ~verbose expr json
  | Some_ expr -> some ~colorize ~verbose expr json
  | Any_with_condition expr -> any_with_condition ~colorize ~verbose expr json
  | All_with_condition expr -> all_with_condition ~colorize ~verbose expr json
  | Test pattern -> test_regex ~colorize pattern json
  | Path expr -> path_of ~colorize ~verbose ~env expr json
  | Variable var_name -> (
      match List.assoc_opt var_name env with
      | Some value -> Output.return value
      | None -> Error ("Undefined variable: $" ^ var_name))
  | Reduce (generator, var_name, init_expr, update_expr) ->
      reduce ~colorize ~verbose ~env generator var_name init_expr update_expr
        json
  | Break -> Error "break is not supported"

and operation ~colorize ~verbose ~env left_expr right_expr op json =
  let* left = interp ~colorize ~verbose ~env left_expr json in
  let* right = interp ~colorize ~verbose ~env right_expr json in
  match op with
  | Add -> Operators.add ~colorize left right
  | Subtract -> Operators.subtract ~colorize left right
  | Multiply -> Operators.multiply ~colorize left right
  | Divide -> Operators.divide ~colorize left right
  | Modulo -> Operators.modulo ~colorize left right
  | Greater_than -> Operators.gt ~colorize left right
  | Greater_than_or_equal -> Operators.gte ~colorize left right
  | Less_than -> Operators.lt ~colorize left right
  | Less_than_or_equal -> Operators.lte ~colorize left right
  | Equal -> Operators.equal left right
  | Not_equal -> Operators.not_equal left right
  | And -> Operators.and_ ~colorize left right
  | Or -> Operators.or_ ~colorize left right

and map ~colorize ~verbose (expr : expression) (json : Json.t) =
  match json with
  | `List list when List.length list > 0 ->
      Output.collect (List.map (interp ~colorize ~verbose expr) list)
      |> Result.map (fun x -> [ `List x ])
  | `List _ -> Error (make_empty_list_error ~colorize "map")
  | _ -> Error (make_error ~colorize "map" json)

and sort_by ~colorize ~verbose expr json =
  match json with
  | `List l ->
      let compare_by a b =
        match
          (interp ~colorize ~verbose expr a, interp ~colorize ~verbose expr b)
        with
        | Ok [ av ], Ok [ bv ] -> (
            match (av, bv) with
            | `Int x, `Int y -> compare x y
            | `Float x, `Float y -> compare x y
            | `Int x, `Float y -> compare (float_of_int x) y
            | `Float x, `Int y -> compare x (float_of_int y)
            | `String x, `String y -> compare x y
            | _ -> 0)
        | _ -> 0
      in
      Output.return (`List (List.sort compare_by l))
  | _ -> Error (make_error ~colorize "sort_by" json)

and min_by ~colorize ~verbose expr json =
  match json with
  | `List [] -> Error (make_empty_list_error ~colorize "min_by")
  | `List l ->
      let compare_by a b =
        match
          (interp ~colorize ~verbose expr a, interp ~colorize ~verbose expr b)
        with
        | Ok [ av ], Ok [ bv ] -> (
            match (av, bv) with
            | `Int x, `Int y -> compare x y
            | `Float x, `Float y -> compare x y
            | `Int x, `Float y -> compare (float_of_int x) y
            | `Float x, `Int y -> compare x (float_of_int y)
            | _ -> 0)
        | _ -> 0
      in
      let min_elem =
        List.fold_left
          (fun acc x -> if compare_by x acc < 0 then x else acc)
          (List.hd l) (List.tl l)
      in
      Output.return min_elem
  | _ -> Error (make_error ~colorize "min_by" json)

and max_by ~colorize ~verbose expr json =
  match json with
  | `List [] -> Error (make_empty_list_error ~colorize "max_by")
  | `List l ->
      let compare_by a b =
        match
          (interp ~colorize ~verbose expr a, interp ~colorize ~verbose expr b)
        with
        | Ok [ av ], Ok [ bv ] -> (
            match (av, bv) with
            | `Int x, `Int y -> compare x y
            | `Float x, `Float y -> compare x y
            | `Int x, `Float y -> compare (float_of_int x) y
            | `Float x, `Int y -> compare x (float_of_int y)
            | _ -> 0)
        | _ -> 0
      in
      let max_elem =
        List.fold_left
          (fun acc x -> if compare_by x acc > 0 then x else acc)
          (List.hd l) (List.tl l)
      in
      Output.return max_elem
  | _ -> Error (make_error ~colorize "max_by" json)

and unique_by ~colorize ~verbose expr json =
  match json with
  | `List l ->
      let rec unique acc seen = function
        | [] -> List.rev acc
        | x :: xs -> (
            match interp ~colorize ~verbose expr x with
            | Ok [ key ] ->
                if List.mem key seen then unique acc seen xs
                else unique (x :: acc) (key :: seen) xs
            | _ -> unique (x :: acc) seen xs)
      in
      Output.return (`List (unique [] [] l))
  | _ -> Error (make_error ~colorize "unique_by" json)

and objects ~colorize ~verbose list json =
  let interp_field (left_expr, right_expr) =
    let keys_res =
      match left_expr with
      | Literal (String s) -> Ok [ `String s ]
      | expr -> interp ~colorize ~verbose expr json
    in
    match keys_res with
    | Error e -> Error e
    | Ok keys -> (
        let values_res =
          match right_expr with
          | None -> (
              match left_expr with
              | Literal (String s) -> (
                  match json with
                  | `Null -> Output.return `Null
                  | _ -> member ~colorize s json)
              | _ -> Error "Object shorthand only allowed for string keys")
          | Some expr -> interp ~colorize ~verbose expr json
        in
        match values_res with
        | Error e -> Error e
        | Ok values ->
            let rec build_pairs acc_pairs keys =
              match keys with
              | [] -> Ok (List.rev acc_pairs)
              | `String k :: rest ->
                  let new_pairs = List.map (fun v -> (k, v)) values in
                  build_pairs (List.rev_append new_pairs acc_pairs) rest
              | _ :: _ ->
                  Error (make_error ~colorize "object key must be string" json)
            in
            build_pairs [] keys)
  in

  let rec collect_fields acc = function
    | [] -> Ok (List.rev acc)
    | field :: rest -> (
        match interp_field field with
        | Ok options -> collect_fields (options :: acc) rest
        | Error e -> Error e)
  in

  let rec cartesian_product lists =
    match lists with
    | [] -> [ [] ]
    | first_field_options :: rest_fields ->
        let rest_product = cartesian_product rest_fields in
        List.concat_map
          (fun pair -> List.map (fun rest -> pair :: rest) rest_product)
          first_field_options
  in

  match collect_fields [] list with
  | Ok field_options_list ->
      let all_combinations = cartesian_product field_options_list in
      Ok (List.map (fun pairs -> `Assoc pairs) all_combinations)
  | Error e -> Error e

and builtin_functions ~colorize builtin json =
  match builtin with
  | Absolute -> (
      match json with
      | `Int n -> Output.return (`Int (abs n))
      | `Float j -> Output.return (`Float (abs_float j))
      | _ -> Error (make_error ~colorize "absolute" json))
  | Add -> (
      match json with
      | `List [] -> Output.return `Null
      | `List l ->
          List.fold_left
            (fun acc el ->
              let* acc = acc in
              Operators.add ~colorize acc el)
            (Output.return `Null) l
      | _ -> Error (make_error ~colorize "add" json))

and flat_map ~colorize ~verbose expr json =
  match json with
  | `List list when List.length list > 0 ->
      Output.collect (List.map (interp ~colorize ~verbose expr) list)
      |> Result.map (fun collected ->
          let flattened =
            List.concat_map
              (function `List l -> l | other -> [ other ])
              collected
          in
          [ `List flattened ])
  | `List _ -> Error (make_empty_list_error ~colorize "flat_map")
  | _ -> Error (make_error ~colorize "flat_map" json)

and find ~colorize ~verbose expr json =
  match json with
  | `List list ->
      let rec find_first = function
        | [] -> Output.return `Null
        | x :: xs -> (
            match interp ~colorize ~verbose expr x with
            | Ok [ `Bool true ] -> Output.return x
            | Ok [ `Bool false ] -> find_first xs
            | Ok [ other ] ->
                if other = `Null || other = `Bool false then find_first xs
                else Output.return x
            | _ -> find_first xs)
      in
      find_first list
  | _ -> Error (make_error ~colorize "find" json)

and some ~colorize ~verbose expr json =
  match json with
  | `List list ->
      let rec check_some = function
        | [] -> Output.return (`Bool false)
        | x :: xs -> (
            match interp ~colorize ~verbose expr x with
            | Ok [ `Bool true ] -> Output.return (`Bool true)
            | Ok [ `Bool false ] -> check_some xs
            | Ok [ other ] ->
                if other = `Null || other = `Bool false then check_some xs
                else Output.return (`Bool true)
            | _ -> check_some xs)
      in
      check_some list
  | _ -> Error (make_error ~colorize "some" json)

and any_with_condition ~colorize ~verbose expr json =
  match json with
  | `List list ->
      let is_truthy = function `Bool false | `Null -> false | _ -> true in
      let rec check_any = function
        | [] -> Output.return (`Bool false)
        | x :: xs -> (
            match interp ~colorize ~verbose expr x with
            | Ok results ->
                if List.exists is_truthy results then Output.return (`Bool true)
                else check_any xs
            | Error _ -> check_any xs)
      in
      check_any list
  | _ -> Error (make_error ~colorize "any" json)

and all_with_condition ~colorize ~verbose expr json =
  match json with
  | `List list ->
      let is_truthy = function `Bool false | `Null -> false | _ -> true in
      let rec check_all = function
        | [] -> Output.return (`Bool true)
        | x :: xs -> (
            match interp ~colorize ~verbose expr x with
            | Ok results ->
                if List.for_all is_truthy results then check_all xs
                else Output.return (`Bool false)
            | Error _ -> Output.return (`Bool false))
      in
      check_all list
  | _ -> Error (make_error ~colorize "all" json)

and path_of ~colorize ~verbose ~env expr json =
  (* Path tracking: returns JSON pointer paths to all values selected by expr. *)
  let rec extract_paths current_path expression value =
    match expression with
    | Identity -> [ current_path ]
    | Key key -> (
        match value with
        | `Assoc fields ->
            if List.mem_assoc key fields then [ current_path @ [ `String key ] ]
            else []
        | _ -> [])
    | Index indices when indices = [] -> (
        (* Iterator case *)
        match value with
        | `List l -> List.mapi (fun i _ -> current_path @ [ `Int i ]) l
        | `Assoc fields ->
            List.map (fun (k, _) -> current_path @ [ `String k ]) fields
        | _ -> [])
    | Index indices ->
        List.concat_map
          (fun idx ->
            match value with
            | `List _ -> [ current_path @ [ `Int idx ] ]
            | _ -> [])
          indices
    | Pipe (left, right) -> (
        match interp ~colorize ~verbose ~env left value with
        | Ok selected_values ->
            List.concat_map
              (fun selected ->
                match extract_path_for_value value selected with
                | Some left_path ->
                    extract_paths (current_path @ left_path) right selected
                | None -> [])
              selected_values
        | Error _ -> [])
    | _ -> []
  and extract_path_for_value parent child =
    (* Helper to find the path from parent to child *)
    match (parent, child) with
    | `Assoc fields, _ ->
        List.find_map
          (fun (key, v) -> if v = child then Some [ `String key ] else None)
          fields
    | `List items, _ ->
        List.find_mapi
          (fun i v -> if v = child then Some [ `Int i ] else None)
          items
    | _ -> if parent = child then Some [] else None
  in
  let paths = extract_paths [] expr json in
  let path_jsons =
    List.map
      (fun path ->
        `List
          (List.map
             (function `String s -> `String s | `Int i -> `Int i | _ -> `Null)
             path))
      paths
  in
  Ok path_jsons

and reduce ~colorize ~verbose ~env generator var_name init_expr update_expr json
    =
  match interp ~colorize ~verbose ~env init_expr json with
  | Error e -> Error e
  | Ok init_values -> (
      match init_values with
      | [ init_val ] -> (
          match interp ~colorize ~verbose ~env generator json with
          | Error e -> Error e
          | Ok generated_values ->
              List.fold_left
                (fun acc_result elem ->
                  match acc_result with
                  | Ok [ acc ] ->
                      let env_with_var = (var_name, elem) :: env in
                      interp ~colorize ~verbose ~env:env_with_var update_expr
                        acc
                  | err -> err)
                (Ok [ init_val ]) generated_values)
      | _ -> Error "reduce init expression must return a single value")

and in_ ~colorize ~verbose json expr =
  let* container = interp ~colorize ~verbose expr json in
  match (json, container) with
  | `Int n, `List l -> Output.return (`Bool (n >= 0 && n < List.length l))
  | `String key, `Assoc list -> Output.return (`Bool (List.mem_assoc key list))
  | _ -> Error (make_error ~colorize "in" json)

and starts_with ~colorize ~verbose ~is_deprecated expr json =
  let name = if is_deprecated then "startwith/startswith" else "starts_with" in
  if is_deprecated then
    emit_warning ~verbose
      "Using deprecated 'startwith' or 'startswith'. Use 'starts_with' \
       instead. This may not be supported in future versions.";
  let* pattern = interp ~colorize ~verbose expr json in
  match (json, pattern) with
  | `String s, `String prefix ->
      Output.return (`Bool (String.starts_with ~prefix s))
  | _ -> Error (make_error ~colorize name json)

and ends_with ~colorize ~verbose ~is_deprecated expr json =
  let name = if is_deprecated then "endwith/endswith" else "ends_with" in
  if is_deprecated then
    emit_warning ~verbose
      "Using deprecated 'endwith' or 'endswith'. Use 'ends_with' instead. This \
       may not be supported in future versions.";
  let* pattern = interp ~colorize ~verbose expr json in
  match (json, pattern) with
  | `String s, `String suffix ->
      Output.return (`Bool (String.ends_with ~suffix s))
  | _ -> Error (make_error ~colorize name json)

and with_entries ~colorize ~verbose expr json =
  let update_entry_field key transform_expr fields entry =
    match List.assoc_opt key fields with
    | Some value -> (
        match interp ~colorize ~verbose transform_expr value with
        | Ok [ new_value ] ->
            let updated_fields =
              List.map
                (fun (k, v) -> if k = key then (k, new_value) else (k, v))
                fields
            in
            `Assoc updated_fields
        | _ -> entry)
    | None -> entry
  in
  let transform_single_entry expr entry =
    match entry with
    | `Assoc fields -> (
        match interp ~colorize ~verbose expr entry with
        | Ok _results -> (
            match expr with
            | Update (Key key, transform_expr) ->
                Ok (update_entry_field key transform_expr fields entry)
            | _ -> Ok entry)
        | Error e -> Error e)
    | _ -> Ok entry
  in
  let rec transform_entry_list expr acc entries =
    match entries with
    | [] -> Ok (List.rev acc)
    | entry :: rest -> (
        match transform_single_entry expr entry with
        | Ok transformed -> transform_entry_list expr (transformed :: acc) rest
        | Error e -> Error e)
  in
  match to_entries ~colorize json with
  | Error e -> Error e
  | Ok [ `List entries ] -> (
      match transform_entry_list expr [] entries with
      | Ok transformed -> from_entries ~colorize (`List transformed)
      | Error e -> Error e)
  | _ -> Error "to_entries should return a list"

and alternative ~colorize ~verbose left right json =
  match interp ~colorize ~verbose left json with
  | Ok results -> (
      let is_valid value =
        match value with `Null | `Bool false -> false | _ -> true
      in
      let valid_results = List.filter is_valid results in
      match valid_results with
      | [] -> interp ~colorize ~verbose right json
      | _ -> Ok valid_results)
  | Error _ -> interp ~colorize ~verbose right json

and contains ~colorize ~verbose expr json =
  let* needle = interp ~colorize ~verbose expr json in
  let json_equal a b =
    match (a, b) with
    | `Int x, `Int y -> x = y
    | `Float x, `Float y -> x = y
    | `Int x, `Float y -> float_of_int x = y
    | `Float x, `Int y -> x = float_of_int y
    | _ -> a = b
  in
  match (json, needle) with
  | `String s, `String sub -> (
      try
        let _ = Str.search_forward (Str.regexp_string sub) s 0 in
        Output.return (`Bool true)
      with Not_found -> Output.return (`Bool false))
  | `List haystack, `List needles ->
      Output.return
        (`Bool
           (List.for_all (fun n -> List.exists (json_equal n) haystack) needles))
  | _ -> Error (make_error ~colorize "contains" json)

and index_of ~colorize ~verbose expr json =
  let* needle = interp ~colorize ~verbose expr json in
  match (json, needle) with
  | `String haystack, `String needle -> (
      try
        let pos = Str.search_forward (Str.regexp_string needle) haystack 0 in
        Output.return (`Int pos)
      with Not_found -> Output.return `Null)
  | _ -> Error (make_error ~colorize "index" json)

and rindex_of ~colorize ~verbose expr json =
  let* needle = interp ~colorize ~verbose expr json in
  match (json, needle) with
  | `String haystack, `String needle -> (
      let rec search_backward pos =
        try
          let found_pos =
            Str.search_forward (Str.regexp_string needle) haystack pos
          in
          search_backward (found_pos + 1)
        with Not_found -> if pos = 0 then None else Some (pos - 1)
      in
      match search_backward 0 with
      | Some pos -> Output.return (`Int pos)
      | None -> Output.return `Null)
  | _ -> Error (make_error ~colorize "rindex" json)

and group_by ~colorize ~verbose expr json =
  match json with
  | `List l ->
      let groups = Hashtbl.create 10 in
      List.iter
        (fun item ->
          match interp ~colorize ~verbose expr item with
          | Ok [ key ] ->
              let key_str =
                Json.to_string ~colorize:false ~summarize:false key
              in
              let existing =
                try Hashtbl.find groups key_str with Not_found -> []
              in
              Hashtbl.replace groups key_str (item :: existing)
          | _ -> ())
        l;
      let result =
        Hashtbl.fold (fun _ items acc -> List.rev items :: acc) groups []
      in
      Output.return (`List (List.map (fun items -> `List items) result))
  | _ -> Error (make_error ~colorize "group_by" json)

and while_loop ~colorize ~verbose cond update json =
  let rec loop acc current =
    match interp ~colorize ~verbose cond current with
    | Ok [ `Bool true ] -> (
        match interp ~colorize ~verbose update current with
        | Ok [ next ] -> loop (current :: acc) next
        | _ -> List.rev acc)
    | Ok [ `Bool false ] -> List.rev acc
    | _ -> List.rev acc
  in
  Ok (loop [] json)

and until_loop ~colorize ~verbose cond update json =
  let rec loop acc current =
    let acc_with_current = current :: acc in
    match interp ~colorize ~verbose cond current with
    | Ok [ `Bool true ] -> List.rev acc_with_current
    | Ok [ `Bool false ] -> (
        match interp ~colorize ~verbose update current with
        | Ok [ next ] -> loop acc_with_current next
        | _ -> List.rev acc_with_current)
    | _ -> List.rev acc_with_current
  in
  Ok (loop [] json)

and recurse_simple ~colorize ~verbose json =
  let rec recurse acc current =
    match interp ~colorize ~verbose (Key "children") current with
    | Ok children ->
        let new_acc = current :: acc in
        List.fold_left (fun a child -> recurse a child) new_acc children
    | Error _ -> current :: acc
  in
  Ok (recurse [] json)

and recurse_with_cond ~colorize ~verbose f cond json =
  let rec loop acc current =
    match interp ~colorize ~verbose cond current with
    | Ok [ `Bool true ] -> (
        let acc_with_current = current :: acc in
        match interp ~colorize ~verbose f current with
        | Ok [ next ] -> loop acc_with_current next
        | _ -> List.rev acc_with_current)
    | Ok [ `Bool false ] -> List.rev acc
    | _ -> List.rev acc
  in
  Ok (loop [] json)

and walk_tree ~colorize ~verbose expr json =
  let rec walk json =
    let walked_json =
      match json with
      | `List l -> `List (List.map walk l)
      | `Assoc obj -> `Assoc (List.map (fun (k, v) -> (k, walk v)) obj)
      | other -> other
    in
    match interp ~colorize ~verbose expr walked_json with
    | Ok [ result ] -> result
    | _ -> walked_json
  in
  Output.return (walk json)
