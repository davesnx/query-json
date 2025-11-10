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
  | `Variant _ -> "variant"
  | `Tuple _ -> "list"
  | `Intlit _ -> "int"

let make_error ~colorize (name : string) (json : Json.t) =
  let itemName = get_field_name json in
  make_error_wrong_operation ~colorize name itemName json

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

let in_ ~colorize (json : Json.t) expr =
  match json with
  | `Int n -> (
      match expr with
      | List list -> Output.return (`Bool (List.length list - 1 >= n))
      | _ -> Error (make_error ~colorize "in" json))
  | `String key -> (
      match expr with
      | Object list ->
          let cmp_literal_str key = function
            | Literal (String s) when s = key -> true
            | _ -> false
          in
          let s = List.map fst list |> List.find_opt (cmp_literal_str key) in
          Output.return (`Bool (Option.is_some s))
      | _ -> Error (make_error ~colorize "in" json))
  | _ -> Error (make_error ~colorize "in" json)

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

let starts_with ~colorize ~verbose ~is_deprecated expr json compile_fn =
  let name = if is_deprecated then "startwith/startswith" else "starts_with" in
  if is_deprecated then
    emit_warning ~verbose
      "Using deprecated 'startwith' or 'startswith'. Use 'starts_with' \
       instead. This may not be supported in future versions.";
  let* pattern = compile_fn expr json in
  match (json, pattern) with
  | `String s, `String prefix ->
      Output.return (`Bool (String.starts_with ~prefix s))
  | _ -> Error (make_error ~colorize name json)

let ends_with ~colorize ~verbose ~is_deprecated expr json compile_fn =
  let name = if is_deprecated then "endwith/endswith" else "ends_with" in
  if is_deprecated then
    emit_warning ~verbose
      "Using deprecated 'endwith' or 'endswith'. Use 'ends_with' instead. This \
       may not be supported in future versions.";
  let* pattern = compile_fn expr json in
  match (json, pattern) with
  | `String s, `String suffix ->
      Output.return (`Bool (String.ends_with ~suffix s))
  | _ -> Error (make_error ~colorize name json)

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

let contains ~colorize expr json compile_fn =
  let* needle = compile_fn expr json in
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

let index_of ~colorize expr json compile_fn =
  let* needle = compile_fn expr json in
  match (json, needle) with
  | `String haystack, `String needle -> (
      try
        let pos = Str.search_forward (Str.regexp_string needle) haystack 0 in
        Output.return (`Int pos)
      with Not_found -> Output.return `Null)
  | _ -> Error (make_error ~colorize "index" json)

let rindex_of ~colorize expr json compile_fn =
  let* needle = compile_fn expr json in
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

let group_by ~colorize ~verbose:_ expr json compile_fn =
  match json with
  | `List l ->
      let groups = Hashtbl.create 10 in
      List.iter
        (fun item ->
          match compile_fn expr item with
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

let while_loop ~colorize:_ ~verbose:_ cond update json compile_fn =
  let rec loop acc current =
    match compile_fn cond current with
    | Ok [ `Bool true ] -> (
        match compile_fn update current with
        | Ok [ next ] -> loop (current :: acc) next
        | _ -> List.rev acc)
    | Ok [ `Bool false ] -> List.rev acc
    | _ -> List.rev acc
  in
  Ok (loop [] json)

let until_loop ~colorize:_ ~verbose:_ cond update json compile_fn =
  let rec loop acc current =
    let acc_with_current = current :: acc in
    match compile_fn cond current with
    | Ok [ `Bool true ] -> List.rev acc_with_current
    | Ok [ `Bool false ] -> (
        match compile_fn update current with
        | Ok [ next ] -> loop acc_with_current next
        | _ -> List.rev acc_with_current)
    | _ -> List.rev acc_with_current
  in
  Ok (loop [] json)

let recurse_simple (json : Json.t) =
  let rec recurse acc current compile_fn =
    match compile_fn (Key "children") current with
    | Ok children ->
        let new_acc = current :: acc in
        List.fold_left
          (fun a child -> recurse a child compile_fn)
          new_acc children
    | Error _ -> current :: acc
  in
  fun compile_fn -> Ok (recurse [] json compile_fn)

let recurse_with_cond ~colorize:_ ~verbose:_ f cond json compile_fn =
  let rec loop acc current =
    match compile_fn cond current with
    | Ok [ `Bool true ] -> (
        let acc_with_current = current :: acc in
        match compile_fn f current with
        | Ok [ next ] -> loop acc_with_current next
        | _ -> List.rev acc_with_current)
    | Ok [ `Bool false ] -> List.rev acc
    | _ -> List.rev acc
  in
  Ok (loop [] json)

let walk_tree ~colorize:_ ~verbose:_ expr json compile_fn =
  let rec walk json =
    let walked_json =
      match json with
      | `List l -> `List (List.map walk l)
      | `Assoc obj -> `Assoc (List.map (fun (k, v) -> (k, walk v)) obj)
      | other -> other
    in
    match compile_fn expr walked_json with
    | Ok [ result ] -> result
    | _ -> walked_json
  in
  Output.return (walk json)

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

let rec compile ~colorize ~verbose expression json :
    (Json.t list, string) result =
  let compile_expr = compile ~colorize ~verbose in
  match expression with
  | Identity -> Output.return json
  | Empty -> Output.empty
  | Keys -> keys ~colorize json
  | Key key -> member ~colorize key json
  | Optional expr -> (
      match compile ~colorize ~verbose expr json with
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
      starts_with ~colorize ~verbose ~is_deprecated:false expr json compile_expr
  | Startwith expr ->
      starts_with ~colorize ~verbose ~is_deprecated:true expr json compile_expr
  | Ends_with expr ->
      ends_with ~colorize ~verbose ~is_deprecated:false expr json compile_expr
  | Endwith expr ->
      ends_with ~colorize ~verbose ~is_deprecated:true expr json compile_expr
  | To_entries -> to_entries ~colorize json
  | From_entries -> from_entries ~colorize json
  | Contains expr -> contains ~colorize expr json compile_expr
  | Explode -> explode ~colorize json
  | Implode -> implode ~colorize json
  | Map expr -> map ~colorize ~verbose expr json
  | Operation (left, op, right) -> (
      match op with
      | Add ->
          operation ~colorize ~verbose left right (Operators.add ~colorize) json
      | Subtract ->
          operation ~colorize ~verbose left right
            (Operators.subtract ~colorize)
            json
      | Multiply ->
          operation ~colorize ~verbose left right
            (Operators.multiply ~colorize)
            json
      | Divide ->
          operation ~colorize ~verbose left right
            (Operators.divide ~colorize)
            json
      | Modulo ->
          operation ~colorize ~verbose left right
            (Operators.modulo ~colorize)
            json
      | Greater_than ->
          operation ~colorize ~verbose left right (Operators.gt ~colorize) json
      | Greater_than_or_equal ->
          operation ~colorize ~verbose left right (Operators.gte ~colorize) json
      | Less_than ->
          operation ~colorize ~verbose left right (Operators.lt ~colorize) json
      | Less_than_or_equal ->
          operation ~colorize ~verbose left right (Operators.lte ~colorize) json
      | Equal -> operation ~colorize ~verbose left right Operators.equal json
      | Not_equal ->
          operation ~colorize ~verbose left right Operators.not_equal json
      | And ->
          operation ~colorize ~verbose left right (Operators.and_ ~colorize)
            json
      | Or ->
          operation ~colorize ~verbose left right (Operators.or_ ~colorize) json
      )
  | Literal literal -> (
      match literal with
      | Bool b -> Output.return (`Bool b)
      | Number f -> Output.return (`Float f)
      | String s -> Output.return (`String s)
      | Null -> Output.return `Null)
  | Pipe (left, right) ->
      let* left = compile ~colorize ~verbose left json in
      compile ~colorize ~verbose right left
  | Select conditional -> (
      let* res = compile ~colorize ~verbose conditional json in
      match res with
      | `Bool b -> (
          match b with true -> Output.return json | false -> Output.empty)
      | _ -> Error (make_error ~colorize "select" res))
  | List exprs ->
      List.map (fun expr -> compile ~colorize ~verbose expr json) exprs
      |> Output.collect
      |> Result.map (fun x -> [ `List x ])
  | Comma (left_expr, right_expr) ->
      Result.bind (compile ~colorize ~verbose left_expr json) (fun left ->
          Result.bind (compile ~colorize ~verbose right_expr json) (fun right ->
              Ok (left @ right)))
  | Object [] -> Output.return (`Assoc [])
  | Object list -> objects ~colorize ~verbose list json
  | Has expr -> (
      match expr with
      | Literal ((String _ | Number _) as expr) -> has ~colorize json expr
      | _ -> Error (show_expression expr ^ " is not allowed"))
  | In expr -> in_ ~colorize json expr
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
      let* cond = compile ~colorize ~verbose cond json in
      match cond with
      | `Bool b ->
          if b then compile ~colorize ~verbose if_branch json
          else compile ~colorize ~verbose else_branch json
      | json ->
          Error (make_error ~colorize "if condition should be a bool" json))
  | Sort_by expr -> sort_by ~colorize ~verbose expr json
  | Min_by expr -> min_by ~colorize ~verbose expr json
  | Max_by expr -> max_by ~colorize ~verbose expr json
  | Unique_by expr -> unique_by ~colorize ~verbose expr json
  | Index_of expr -> index_of ~colorize expr json compile_expr
  | Rindex_of expr -> rindex_of ~colorize expr json compile_expr
  | Group_by expr -> group_by ~colorize ~verbose expr json compile_expr
  | While (cond, update) ->
      while_loop ~colorize ~verbose cond update json compile_expr
  | Until (cond, update) ->
      until_loop ~colorize ~verbose cond update json compile_expr
  | Recurse -> recurse_simple json compile_expr
  | Recurse_with (f, cond) ->
      recurse_with_cond ~colorize ~verbose f cond json compile_expr
  | Walk expr -> walk_tree ~colorize ~verbose expr json compile_expr
  | _ -> Error (show_expression expression ^ " is not implemented")

and operation ~colorize ~verbose left_expr right_expr op json =
  let* left = compile ~colorize ~verbose left_expr json in
  let* right = compile ~colorize ~verbose right_expr json in
  op left right

and map ~colorize ~verbose (expr : expression) (json : Json.t) =
  match json with
  | `List list when List.length list > 0 ->
      Output.collect (List.map (compile ~colorize ~verbose expr) list)
      |> Result.map (fun x -> [ `List x ])
  | `List _ -> Error (make_empty_list_error ~colorize "map")
  | _ -> Error (make_error ~colorize "map" json)

and sort_by ~colorize ~verbose expr json =
  match json with
  | `List l ->
      let compare_by a b =
        match
          (compile ~colorize ~verbose expr a, compile ~colorize ~verbose expr b)
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
          (compile ~colorize ~verbose expr a, compile ~colorize ~verbose expr b)
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
          (compile ~colorize ~verbose expr a, compile ~colorize ~verbose expr b)
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
            match compile ~colorize ~verbose expr x with
            | Ok [ key ] ->
                if List.mem key seen then unique acc seen xs
                else unique (x :: acc) (key :: seen) xs
            | _ -> unique (x :: acc) seen xs)
      in
      Output.return (`List (unique [] [] l))
  | _ -> Error (make_error ~colorize "unique_by" json)

and objects ~colorize ~verbose list json =
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
          | Key search_val -> (
              match json with
              | `Assoc l -> (
                  match List.assoc_opt search_val l with
                  | None -> Output.return (`Assoc [ (key, `Null) ])
                  | Some v -> Output.return (`Assoc [ (key, v) ]))
              | _ -> assert false)
          | rexp ->
              let* rexp = compile ~colorize ~verbose rexp json in
              Output.return (`Assoc [ (key, rexp) ]))
      | _ -> Error (show_expression left_expr ^ " is not implemented"))
    list
  |> Output.collect

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
