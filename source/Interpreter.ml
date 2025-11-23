open Ast
open Effect
open Effect.Deep

type _ Effect.t += Yield : Json.t -> unit Effect.t
type _ Effect.t += Break : unit Effect.t
type _ Effect.t += Halt : int -> unit Effect.t

exception Query_error of string

module Error = struct
  let prepend_article (noun : string) =
    let starts_with_any (str : string) (chars : string list) =
      let rec loop (chars : string list) =
        match chars with
        | [] -> false
        | x :: xs -> if String.starts_with ~prefix:x str then true else loop xs
      in
      loop chars
    in
    match starts_with_any noun [ "a"; "e"; "i"; "o"; "u" ] with
    | true -> "an " ^ noun
    | false -> "a " ^ noun

  let empty_list ~colorize op =
    let module Chalk = Chalk.Make (struct
      let disable = not colorize
    end) in
    raise
      (Query_error
         ("Trying to "
         ^ Formatting.single_quotes (Chalk.bold op)
         ^ " on an empty array."))

  let arg ~colorize op expected actual_value =
    let module Chalk = Chalk.Make (struct
      let disable = not colorize
    end) in
    raise
      (Query_error
         ("Invalid argument for "
         ^ Formatting.single_quotes (Chalk.bold op)
         ^ ": expected " ^ Chalk.bold expected ^ "." ^ Formatting.enter 1
         ^ Chalk.gray
             (Json.to_string actual_value ~colorize ~summarize:true ~raw:false)
         ))

  let structure ~colorize op msg actual_value =
    let module Chalk = Chalk.Make (struct
      let disable = not colorize
    end) in
    raise
      (Query_error
         ("Invalid structure for "
         ^ Formatting.single_quotes (Chalk.bold op)
         ^ ": " ^ msg ^ "." ^ Formatting.enter 1
         ^ Chalk.gray
             (Json.to_string actual_value ~colorize ~summarize:true ~raw:false)
         ))

  let message ~colorize msg =
    let module Chalk = Chalk.Make (struct
      let disable = not colorize
    end) in
    raise (Query_error (Chalk.red "Error: " ^ msg))

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

  let make ~colorize (name : string) (json : Json.t) =
    let member_kind = get_field_name json in
    let module Chalk = Chalk.Make (struct
      let disable = not colorize
    end) in
    raise
      (Query_error
         ("Trying to "
         ^ Formatting.single_quotes (Chalk.bold name)
         ^ " on "
         ^ Chalk.bold (prepend_article member_kind)
         ^ ":" ^ Formatting.enter 1
         ^ Chalk.gray (Json.to_string json ~colorize ~summarize:true ~raw:false)
         ))

  let missing_member ~colorize op key (value : Json.t) =
    let module Chalk = Chalk.Make (struct
      let disable = not colorize
    end) in
    raise
      (Query_error
         ("Trying to "
         ^ Formatting.double_quotes (Chalk.bold op)
         ^ " on an object, that don't have the field "
         ^ Formatting.double_quotes key
         ^ ":" ^ Formatting.enter 1
         ^ Chalk.gray
             (Json.to_string value ~colorize ~summarize:true ~raw:false)))
end

module Operators = struct
  let not (json : Json.t) =
    match json with `Bool false | `Null -> `Bool true | _ -> `Bool false

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

  let rec add ~colorize str (left : Json.t) (right : Json.t) : Json.t =
    match (left, right) with
    | `Float l, `Float r -> `Float (l +. r)
    | `Int l, `Float r -> `Float (Int.to_float l +. r)
    | `Float l, `Int r -> `Float (l +. Int.to_float r)
    | `Int l, `Int r -> `Float (Int.to_float l +. Int.to_float r)
    | `Null, `Int r | `Int r, `Null -> `Float (Int.to_float r)
    | `Null, `Float r | `Float r, `Null -> `Float r
    | `String l, `String r -> `String (l ^ r)
    | `Null, `String r | `String r, `Null -> `String r
    | `Assoc l, `Assoc r ->
        let cmp (key1, _) (key2, _) = String.compare key1 key2 in
        let eq (key, v1) (_, v2) =
          let result = add ~colorize str v1 v2 in
          (key, result)
        in
        let f (key, v) = (key, v) in
        `Assoc (merge_map ~f ~eq cmp l r)
    | `Null, `Assoc r | `Assoc r, `Null -> `Assoc r
    | `List l, `List r -> `List (l @ r)
    | `Null, `List r | `List r, `Null -> `List r
    | `Null, `Null -> `Null
    | _ -> Error.make ~colorize str left

  let apply_operation ~colorize str fn (left : Json.t) (right : Json.t) =
    match (left, right) with
    | `Float l, `Float r -> `Float (fn l r)
    | `Int l, `Float r -> `Float (fn (Int.to_float l) r)
    | `Float l, `Int r -> `Float (fn l (Int.to_float r))
    | `Int l, `Int r -> `Float (fn (Int.to_float l) (Int.to_float r))
    | _ -> Error.make ~colorize str left

  let compare ~colorize str fn (left : Json.t) (right : Json.t) =
    match (left, right) with
    | `Float l, `Float r -> `Bool (fn l r)
    | `Int l, `Float r -> `Bool (fn (Int.to_float l) r)
    | `Float l, `Int r -> `Bool (fn l (Int.to_float r))
    | `Int l, `Int r -> `Bool (fn (Int.to_float l) (Int.to_float r))
    | _ -> Error.make ~colorize str right

  let condition ~colorize (str : string) (fn : bool -> bool -> bool)
      (left : Json.t) (right : Json.t) =
    match (left, right) with
    | `Bool l, `Bool r -> `Bool (fn l r)
    | _ -> Error.make ~colorize str right

  let gt ~colorize = compare ~colorize ">" ( > )
  let gte ~colorize = compare ~colorize ">=" ( >= )
  let lt ~colorize = compare ~colorize "<" ( < )
  let lte ~colorize = compare ~colorize "<=" ( <= )
  let and_ ~colorize = condition ~colorize "and" ( && )
  let or_ ~colorize = condition ~colorize "or" ( || )
  let equal l r = `Bool (l = r)
  let not_equal l r = `Bool (l <> r)
  let add ~colorize = add ~colorize "+"
  let subtract ~colorize = apply_operation ~colorize "-" (fun l r -> l -. r)
  let multiply ~colorize = apply_operation ~colorize "*" (fun l r -> l *. r)
  let divide ~colorize = apply_operation ~colorize "/" (fun l r -> l /. r)

  let modulo ~colorize =
    apply_operation ~colorize "%" (fun l r -> mod_float l r)
end

let keys ~colorize (json : Json.t) =
  match json with
  | `Assoc _list -> `List (Json.keys json |> List.map (fun i -> `String i))
  | _ -> Error.make ~colorize "keys" json

let has ~colorize (json : Json.t) key =
  match key with
  | String key -> (
      match json with
      | `Assoc list -> `Bool (List.mem_assoc key list)
      | _ -> Error.make ~colorize "has" json)
  | Number n -> (
      match json with
      | `List list -> `Bool (List.length list - 1 >= int_of_float n)
      | _ -> Error.make ~colorize "has" json)
  | _ -> Error.make ~colorize "has" json

let range ?step from upto =
  let rec range ?(step = 1) start stop =
    if step = 0 then []
    else if (step > 0 && start >= stop) || (step < 0 && start <= stop) then []
    else start :: range ~step (start + step) stop
  in
  match upto with None -> range 1 from | Some upto -> range ?step from upto

let split ~colorize expr json =
  match json with
  | `String s ->
      let rcase =
        match expr with
        | Literal (String s) -> s
        | _ ->
            Error.message ~colorize
              "Invalid argument for 'split': expected string literal"
      in
      `List (Str.split (Str.regexp rcase) s |> List.map (fun s -> `String s))
  | _ -> Error.make ~colorize "split" json

let join ~colorize expr json =
  let rcase =
    match expr with
    | Literal (String s) -> s
    | _ ->
        Error.message ~colorize
          "Invalid argument for 'join': expected string literal"
  in
  match json with
  | `List l ->
      `String
        (List.map (function `String s -> s | _ -> "") l |> String.concat rcase)
  | _ -> Error.make ~colorize "join" json

let length ~colorize (json : Json.t) =
  match json with
  | `List list -> `Int (List.length list)
  | `String s -> `Int (String.length s)
  | `Assoc obj -> `Int (List.length obj)
  | `Null -> `Int 0
  | _ -> Error.make ~colorize "length" json

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
  `String type_name

let floor ~colorize (json : Json.t) =
  match json with
  | `Float f -> `Int (int_of_float (floor f))
  | `Int n -> `Int n
  | _ -> Error.make ~colorize "floor" json

let sqrt ~colorize (json : Json.t) =
  match json with
  | `Float f -> `Float (sqrt f)
  | `Int n -> `Float (sqrt (float_of_int n))
  | _ -> Error.make ~colorize "sqrt" json

let to_number ~colorize ~verbose ~deprecated (json : Json.t) =
  let name = if deprecated then "tonumber" else "to_number" in
  if deprecated then
    emit_warning ~verbose
      "Using deprecated 'tonumber'. Use 'to_number' instead. This may not be \
       supported in future versions.";
  match json with
  | `String s -> (
      try `Float (float_of_string s)
      with Failure _ -> Error.make ~colorize name json)
  | `Int _ | `Float _ -> json
  | _ -> Error.make ~colorize name json

let to_string ~verbose ~deprecated (json : Json.t) =
  if deprecated then
    emit_warning ~verbose
      "Using deprecated 'tostring'. Use 'to_string' instead. This may not be \
       supported in future versions.";
  `String (Json.to_string ~colorize:false ~summarize:false ~raw:false json)

let min ~colorize (json : Json.t) =
  match json with
  | `List [] -> Error.empty_list ~colorize "min"
  | `List l ->
      let compare_json a b =
        match (a, b) with
        | `Int x, `Int y -> compare x y
        | `Float x, `Float y -> compare x y
        | `Int x, `Float y -> compare (float_of_int x) y
        | `Float x, `Int y -> compare x (float_of_int y)
        | _ -> 0
      in
      List.fold_left
        (fun acc x -> if compare_json x acc < 0 then x else acc)
        (List.hd l) (List.tl l)
  | _ -> Error.make ~colorize "min" json

let max ~colorize (json : Json.t) =
  match json with
  | `List [] -> Error.empty_list ~colorize "max"
  | `List l ->
      let compare_json a b =
        match (a, b) with
        | `Int x, `Int y -> compare x y
        | `Float x, `Float y -> compare x y
        | `Int x, `Float y -> compare (float_of_int x) y
        | `Float x, `Int y -> compare x (float_of_int y)
        | _ -> 0
      in
      List.fold_left
        (fun acc x -> if compare_json x acc > 0 then x else acc)
        (List.hd l) (List.tl l)
  | _ -> Error.make ~colorize "max" json

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
      `List (flatten_n depth l)
  | _ -> Error.make ~colorize "flatten" json

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
      `List (List.sort compare_json l)
  | _ -> Error.make ~colorize "sort" json

let unique ~colorize (json : Json.t) =
  match json with
  | `List l ->
      let rec unique acc = function
        | [] -> List.rev acc
        | x :: xs ->
            if List.mem x acc then unique acc xs else unique (x :: acc) xs
      in
      `List (unique [] l)
  | _ -> Error.make ~colorize "unique" json

let any ~colorize (json : Json.t) =
  match json with
  | `List l ->
      let is_truthy = function `Bool false | `Null -> false | _ -> true in
      `Bool (List.exists is_truthy l)
  | _ -> Error.make ~colorize "any" json

let all ~colorize (json : Json.t) =
  match json with
  | `List l ->
      let is_truthy = function `Bool false | `Null -> false | _ -> true in
      `Bool (List.for_all is_truthy l)
  | _ -> Error.make ~colorize "all" json

let to_entries ~colorize (json : Json.t) =
  match json with
  | `Assoc obj ->
      let entries =
        List.map
          (fun (key, value) ->
            `Assoc [ ("key", `String key); ("value", value) ])
          obj
      in
      `List entries
  | _ -> Error.structure ~colorize "to_entries" "requires an object" json

let from_entries ~colorize (json : Json.t) =
  match json with
  | `List entries ->
      let rec convert acc = function
        | [] -> List.rev acc
        | entry :: rest -> (
            match entry with
            | `Assoc fields -> (
                let key = List.assoc_opt "key" fields in
                let value = List.assoc_opt "value" fields in
                match (key, value) with
                | Some (`String k), Some v -> convert ((k, v) :: acc) rest
                | _ ->
                    Error.structure ~colorize "from_entries"
                      "requires objects with 'key' (string) and 'value' fields"
                      json)
            | _ ->
                Error.structure ~colorize "from_entries"
                  "requires an array of objects" json)
      in
      `Assoc (convert [] entries)
  | _ -> Error.make ~colorize "from_entries" json

let explode ~colorize (json : Json.t) =
  match json with
  | `String s ->
      let codepoints =
        List.init (String.length s) (fun i -> `Int (Char.code (String.get s i)))
      in
      `List codepoints
  | _ -> Error.make ~colorize "explode" json

let implode ~colorize (json : Json.t) =
  match json with
  | `List l ->
      let chars =
        List.map (function `Int n -> Char.chr n | _ -> Char.chr 0) l
      in
      `String (String.of_seq (List.to_seq chars))
  | _ -> Error.make ~colorize "implode" json

let nan_value () = `Float nan

let is_nan ~colorize (json : Json.t) =
  match json with
  | `Float f -> `Bool (Float.is_nan f)
  | `Int _ -> `Bool false
  | _ -> Error.make ~colorize "is_nan" json

let transpose ~colorize (json : Json.t) =
  match json with
  | `List [] -> `List []
  | `List rows ->
      let get_length row =
        match row with `List l -> Some (List.length l) | _ -> None
      in
      let lengths = List.filter_map get_length rows in
      if List.length lengths <> List.length rows then
        Error.structure ~colorize "transpose" "requires an array of arrays" json
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
        `List transposed
  | _ -> Error.make ~colorize "transpose" json

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
  descend [] json

let test_regex ~colorize pattern json =
  match json with
  | `String s -> (
      try
        let regex = Str.regexp pattern in
        let _ = Str.search_forward regex s 0 in
        `Bool true
      with Not_found -> `Bool false)
  | _ -> Error.make ~colorize "test" json

let match_regex ~colorize pattern json =
  match json with
  | `String s -> (
      try
        let regex = Str.regexp pattern in
        let _ = Str.search_forward regex s 0 in
        let matched = Str.matched_string s in
        let captures = ref [] in
        (try
           for i = 1 to 9 do
             captures := Str.matched_group i s :: !captures
           done
         with Not_found | Invalid_argument _ -> ());
        let result =
          `Assoc
            [
              ("offset", `Int (Str.match_beginning ()));
              ("length", `Int (String.length matched));
              ("string", `String matched);
              ( "captures",
                `List
                  (List.rev_map
                     (fun c ->
                       `Assoc
                         [
                           ("offset", `Int (-1));
                           ("length", `Int (String.length c));
                           ("string", `String c);
                           ("name", `Null);
                         ])
                     !captures) );
            ]
        in
        perform (Yield result)
      with Not_found -> ())
  | _ -> Error.make ~colorize "match" json

let scan_regex ~colorize pattern json =
  match json with
  | `String s ->
      let regex = Str.regexp pattern in
      let rec scan_all pos =
        try
          let _ = Str.search_forward regex s pos in
          let matched = Str.matched_string s in
          perform (Yield (`String matched));
          scan_all (Str.match_end ())
        with Not_found -> ()
      in
      scan_all 0
  | _ -> Error.make ~colorize "scan" json

let capture_regex ~colorize pattern json =
  match json with
  | `String s -> (
      try
        let regex = Str.regexp pattern in
        let _ = Str.search_forward regex s 0 in
        let captures = ref [] in
        (try
           for i = 1 to 9 do
             captures := Str.matched_group i s :: !captures
           done
         with Not_found | Invalid_argument _ -> ());
        perform (Yield (`List (List.rev_map (fun c -> `String c) !captures)))
      with Not_found -> perform (Yield (`List [])))
  | _ -> Error.make ~colorize "capture" json

let sub_regex ~colorize pattern replacement json =
  match json with
  | `String s -> (
      try
        let regex = Str.regexp pattern in
        `String (Str.replace_first regex replacement s)
      with _ -> json)
  | _ -> Error.make ~colorize "sub" json

let gsub_regex ~colorize pattern replacement json =
  match json with
  | `String s -> (
      try
        let regex = Str.regexp pattern in
        `String (Str.global_replace regex replacement s)
      with _ -> json)
  | _ -> Error.make ~colorize "gsub" json

let head ~colorize (json : Json.t) =
  match json with
  | `List list -> (
      match List.length list > 0 with
      | true -> Json.index 0 json
      | false -> Error.empty_list ~colorize "head")
  | _ -> Error.make ~colorize "head" json

let tail ~colorize (json : Json.t) =
  match json with
  | `List list -> (
      match List.length list > 0 with
      | true ->
          let last_index = List.length list - 1 in
          Json.index last_index json
      | false -> Error.empty_list ~colorize "tail")
  | _ -> Error.make ~colorize "tail" json

let member ~colorize (key : string) (json : Json.t) =
  match json with
  | `Assoc _assoc -> (
      let access_member = Json.member key json in
      match access_member with
      | `Null -> Error.missing_member ~colorize ("." ^ key) key json
      | _ -> access_member)
  | _ -> Error.make ~colorize ("." ^ key) json

let iterator ~colorize (json : Json.t) =
  match json with
  | `List [] -> ()
  | `List items -> List.iter (fun x -> perform (Yield x)) items
  | `Assoc obj -> List.iter (fun (_, x) -> perform (Yield x)) obj
  | _ -> Error.make ~colorize "[]" json

let rec index ~colorize (indices : int list) (json : Json.t) =
  match indices with
  | [] -> iterator ~colorize json
  | [ value ] -> (
      match json with
      | `List list when List.length list > value ->
          perform (Yield (Json.index value json))
      | `List _ -> perform (Yield `Null)
      | _ -> Error.make ~colorize ("[" ^ Int.to_string value ^ "]") json)
  | multiple -> List.iter (fun idx -> index ~colorize [ idx ] json) multiple

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
  | `String _s when finish < start -> perform (Yield (`String ""))
  | `String s -> perform (Yield (`String (String.sub s start (finish - start))))
  | `List _l when finish < start -> perform (Yield (`List []))
  | `List l ->
      let sliced =
        List.fold_left
          (fun (acc, i) x ->
            if i >= start && i < finish then (x :: acc, i + 1) else (acc, i + 1))
          ([], 0) l
        |> fst |> List.rev
      in
      perform (Yield (`List sliced))
  | _ ->
      Error.make ~colorize
        ("[" ^ Int.to_string start ^ ":" ^ Int.to_string finish ^ "]")
        json

type env = (string * Json.t) list

let collect_results thunk =
  let results = ref [] in
  let handler =
    {
      effc =
        (fun (type a) (eff : a Effect.t) ->
          match eff with
          | Yield v ->
              Some
                (fun (k : (a, _) continuation) ->
                  results := v :: !results;
                  continue k ())
          | _ -> None);
    }
  in
  try_with thunk () handler;
  List.rev !results

let rec interp ~colorize ~verbose ?(env = []) expression json : unit =
  match expression with
  | Identity -> perform (Yield json)
  | Empty -> ()
  | Keys -> perform (Yield (keys ~colorize json))
  | Key key -> perform (Yield (member ~colorize key json))
  | Optional expr -> (
      try interp ~colorize ~verbose ~env expr json
      with Query_error _ -> perform (Yield `Null))
  | Index idx -> index ~colorize idx json
  | Iterator -> iterator ~colorize json
  | Slice (start, finish) -> slice ~colorize start finish json
  | Head -> perform (Yield (head ~colorize json))
  | Tail -> perform (Yield (tail ~colorize json))
  | Length -> perform (Yield (length ~colorize json))
  | Not -> perform (Yield (Operators.not json))
  | Type -> perform (Yield (type_of json))
  | Floor -> perform (Yield (floor ~colorize json))
  | Sqrt -> perform (Yield (sqrt ~colorize json))
  | To_number ->
      perform (Yield (to_number ~colorize ~verbose ~deprecated:false json))
  | Tonumber ->
      perform (Yield (to_number ~colorize ~verbose ~deprecated:true json))
  | To_string -> perform (Yield (to_string ~verbose ~deprecated:false json))
  | Tostring -> perform (Yield (to_string ~verbose ~deprecated:true json))
  | Min -> perform (Yield (min ~colorize json))
  | Max -> perform (Yield (max ~colorize json))
  | Flatten depth_opt -> perform (Yield (flatten ~colorize depth_opt json))
  | Sort -> perform (Yield (sort ~colorize json))
  | Unique -> perform (Yield (unique ~colorize json))
  | Any -> perform (Yield (any ~colorize json))
  | All -> perform (Yield (all ~colorize json))
  | Starts_with expr ->
      starts_with ~colorize ~verbose ~env ~is_deprecated:false expr json
  | Startwith expr ->
      starts_with ~colorize ~verbose ~env ~is_deprecated:true expr json
  | Ends_with expr ->
      ends_with ~colorize ~verbose ~env ~is_deprecated:false expr json
  | Endwith expr ->
      ends_with ~colorize ~verbose ~env ~is_deprecated:true expr json
  | To_entries -> perform (Yield (to_entries ~colorize json))
  | From_entries -> perform (Yield (from_entries ~colorize json))
  | With_entries expr -> with_entries ~colorize ~verbose ~env expr json
  | Contains expr -> contains ~colorize ~verbose ~env expr json
  | Explode -> perform (Yield (explode ~colorize json))
  | Implode -> perform (Yield (implode ~colorize json))
  | Map expr -> map ~colorize ~verbose ~env expr json
  | Operation (left, op, right) ->
      operation ~colorize ~verbose ~env left right op json
  | Literal literal -> (
      match literal with
      | Bool b -> perform (Yield (`Bool b))
      | Number f -> perform (Yield (`Float f))
      | String s -> perform (Yield (`String s))
      | Null -> perform (Yield `Null))
  | Pipe (left, right) ->
      let handler =
        {
          effc =
            (fun (type a) (eff : a Effect.t) ->
              match eff with
              | Yield v ->
                  Some
                    (fun (k : (a, _) continuation) ->
                      interp ~colorize ~verbose ~env right v;
                      continue k ())
              | _ -> None);
        }
      in
      try_with (fun () -> interp ~colorize ~verbose ~env left json) () handler
  | Update (path, transform) ->
      let handler =
        {
          effc =
            (fun (type a) (eff : a Effect.t) ->
              match eff with
              | Yield v ->
                  Some
                    (fun (k : (a, _) continuation) ->
                      interp ~colorize ~verbose ~env transform v;
                      continue k ())
              | _ -> None);
        }
      in
      try_with (fun () -> interp ~colorize ~verbose ~env path json) () handler
  | Alternative (left, right) ->
      alternative ~colorize ~verbose ~env left right json
  | Select conditional ->
      let handler =
        {
          effc =
            (fun (type a) (eff : a Effect.t) ->
              match eff with
              | Yield v ->
                  Some
                    (fun (k : (a, _) continuation) ->
                      (match v with
                      | `Bool false | `Null -> ()
                      | _ -> perform (Yield json));
                      continue k ())
              | _ -> None);
        }
      in
      try_with
        (fun () -> interp ~colorize ~verbose ~env conditional json)
        () handler
  | List None -> perform (Yield (`List []))
  | List (Some expr) ->
      let results =
        collect_results (fun () -> interp ~colorize ~verbose ~env expr json)
      in
      perform (Yield (`List results))
  | Comma (left_expr, right_expr) ->
      interp ~colorize ~verbose ~env left_expr json;
      interp ~colorize ~verbose ~env right_expr json
  | Object [] -> perform (Yield (`Assoc []))
  | Object list -> objects ~colorize ~verbose ~env list json
  | Has expr -> (
      match expr with
      | Literal ((String _ | Number _) as lit) ->
          perform (Yield (has ~colorize json lit))
      | _ -> Error.message ~colorize (show_expression expr ^ " is not allowed"))
  | In expr -> in_ ~colorize ~verbose ~env json expr
  | Range (from, upto, step) ->
      let vals = range ?step from upto in
      List.iter (fun i -> perform (Yield (`Int i))) vals
  | Reverse -> (
      match json with
      | `List l -> perform (Yield (`List (List.rev l)))
      | _ -> Error.make ~colorize "reverse" json)
  | Split expr -> perform (Yield (split ~colorize expr json))
  | Join expr -> perform (Yield (join ~colorize expr json))
  | Fun builtin -> builtin_functions ~colorize builtin json
  | If_then_else (cond, if_branch, else_branch) ->
      let handler =
        {
          effc =
            (fun (type a) (eff : a Effect.t) ->
              match eff with
              | Yield v ->
                  Some
                    (fun (k : (a, _) continuation) ->
                      (match v with
                      | `Bool true ->
                          interp ~colorize ~verbose ~env if_branch json
                      | `Bool false | `Null ->
                          interp ~colorize ~verbose ~env else_branch json
                      | _ ->
                          Error.make ~colorize "if condition should be a bool" v);
                      continue k ())
              | _ -> None);
        }
      in
      try_with (fun () -> interp ~colorize ~verbose ~env cond json) () handler
  | Sort_by expr -> sort_by ~colorize ~verbose ~env expr json
  | Min_by expr -> min_by ~colorize ~verbose ~env expr json
  | Max_by expr -> max_by ~colorize ~verbose ~env expr json
  | Unique_by expr -> unique_by ~colorize ~verbose ~env expr json
  | Index_of expr -> index_of ~colorize ~verbose ~env expr json
  | Rindex_of expr -> rindex_of ~colorize ~verbose ~env expr json
  | Group_by expr -> group_by ~colorize ~verbose ~env expr json
  | While (cond, update) -> while_loop ~colorize ~verbose ~env cond update json
  | Until (cond, update) -> until_loop ~colorize ~verbose ~env cond update json
  | Recurse ->
      let results = recurse_simple ~colorize ~verbose json in
      List.iter (fun x -> perform (Yield x)) results
  | Recurse_with (f, cond) ->
      recurse_with_cond ~colorize ~verbose ~env f cond json
  | Recurse_down ->
      let results = recurse_down json in
      List.iter (fun x -> perform (Yield x)) results
  | Walk expr -> walk_tree ~colorize ~verbose ~env expr json
  | Transpose expr ->
      let handler =
        {
          effc =
            (fun (type a) (eff : a Effect.t) ->
              match eff with
              | Yield v ->
                  Some
                    (fun (k : (a, _) continuation) ->
                      perform (Yield (transpose ~colorize v));
                      continue k ())
              | _ -> None);
        }
      in
      try_with (fun () -> interp ~colorize ~verbose ~env expr json) () handler
  | Nan -> perform (Yield (nan_value ()))
  | Is_nan -> perform (Yield (is_nan ~colorize json))
  | Flat_map expr -> flat_map ~colorize ~verbose ~env expr json
  | Find expr -> find ~colorize ~verbose ~env expr json
  | Some_ expr -> some ~colorize ~verbose ~env expr json
  | Any_with_condition expr ->
      any_with_condition ~colorize ~verbose ~env expr json
  | All_with_condition expr ->
      all_with_condition ~colorize ~verbose ~env expr json
  | Test pattern -> perform (Yield (test_regex ~colorize pattern json))
  | Match pattern -> match_regex ~colorize pattern json
  | Scan pattern -> scan_regex ~colorize pattern json
  | Capture pattern -> capture_regex ~colorize pattern json
  | Sub (pattern, replacement) ->
      perform (Yield (sub_regex ~colorize pattern replacement json))
  | Gsub (pattern, replacement) ->
      perform (Yield (gsub_regex ~colorize pattern replacement json))
  | Path expr -> path_of ~colorize ~verbose ~env expr json
  | Variable var_name -> (
      match List.assoc_opt var_name env with
      | Some value -> perform (Yield value)
      | None -> Error.message ~colorize ("Undefined variable: $" ^ var_name))
  | Def (name, _params, _body) ->
      Error.message ~colorize
        ("def " ^ name
       ^ " is not yet fully implemented - definitions should be at program top \
          level")
  | Call (fname, _args) ->
      Error.message ~colorize
        ("calling function " ^ fname ^ " - custom functions not yet implemented")
  | Reduce (generator, var_name, init_expr, update_expr) ->
      reduce ~colorize ~verbose ~env generator var_name init_expr update_expr
        json
  | Break -> perform Break
  | Try (expr, handler_opt) ->
      try_catch ~colorize ~verbose ~env expr handler_opt json
  | Limit (n, expr) -> limit ~colorize ~verbose ~env n expr json
  | Error_msg msg_expr -> error_msg ~colorize ~verbose ~env msg_expr json
  | Halt -> perform (Halt 0)
  | Halt_error exit_code -> perform (Halt (Option.value exit_code ~default:1))
  | Isempty expr -> isempty ~colorize ~verbose ~env expr json
  | Del expr -> del ~colorize ~verbose ~env expr json
  | Getpath expr -> getpath ~colorize ~verbose ~env expr json
  | Setpath (path_expr, value_expr) ->
      setpath ~colorize ~verbose ~env path_expr value_expr json
  | Paths -> paths json
  | Paths_filter expr -> paths_filter ~colorize ~verbose ~env expr json
  | Assign (path, value_expr) ->
      assign ~colorize ~verbose ~env path value_expr json
  | Foreach (_, _, _, _) ->
      Error.message ~colorize "foreach is not yet implemented"
  | Label (_, _) -> Error.message ~colorize "label is not yet implemented"

and operation ~colorize ~verbose ~env left_expr right_expr op json =
  let left_handler =
    {
      effc =
        (fun (type a) (eff : a Effect.t) ->
          match eff with
          | Yield l_val ->
              Some
                (fun (k : (a, _) continuation) ->
                  let right_handler =
                    {
                      effc =
                        (fun (type a) (eff : a Effect.t) ->
                          match eff with
                          | Yield r_val ->
                              Some
                                (fun (k : (a, _) continuation) ->
                                  let res =
                                    match op with
                                    | Add -> Operators.add ~colorize l_val r_val
                                    | Subtract ->
                                        Operators.subtract ~colorize l_val r_val
                                    | Multiply ->
                                        Operators.multiply ~colorize l_val r_val
                                    | Divide ->
                                        Operators.divide ~colorize l_val r_val
                                    | Modulo ->
                                        Operators.modulo ~colorize l_val r_val
                                    | Greater_than ->
                                        Operators.gt ~colorize l_val r_val
                                    | Greater_than_or_equal ->
                                        Operators.gte ~colorize l_val r_val
                                    | Less_than ->
                                        Operators.lt ~colorize l_val r_val
                                    | Less_than_or_equal ->
                                        Operators.lte ~colorize l_val r_val
                                    | Equal -> Operators.equal l_val r_val
                                    | Not_equal ->
                                        Operators.not_equal l_val r_val
                                    | And ->
                                        Operators.and_ ~colorize l_val r_val
                                    | Or -> Operators.or_ ~colorize l_val r_val
                                  in
                                  perform (Yield res);
                                  continue k ())
                          | _ -> None);
                    }
                  in
                  try_with
                    (fun () -> interp ~colorize ~verbose ~env right_expr json)
                    () right_handler;
                  continue k ())
          | _ -> None);
    }
  in
  try_with
    (fun () -> interp ~colorize ~verbose ~env left_expr json)
    () left_handler

and map ~colorize ~verbose ~env (expr : expression) (json : Json.t) =
  match json with
  | `List list when List.length list > 0 ->
      let collected =
        List.concat_map
          (fun item ->
            collect_results (fun () -> interp ~colorize ~verbose ~env expr item))
          list
      in
      perform (Yield (`List collected))
  | `List _ -> perform (Yield (`List []))
  | _ -> Error.make ~colorize "map" json

and sort_by ~colorize ~verbose ~env expr json =
  match json with
  | `List l ->
      let compare_by a b =
        let res_a =
          collect_results (fun () -> interp ~colorize ~verbose ~env expr a)
        in
        let res_b =
          collect_results (fun () -> interp ~colorize ~verbose ~env expr b)
        in
        match (res_a, res_b) with
        | [ av ], [ bv ] -> (
            match (av, bv) with
            | `Int x, `Int y -> compare x y
            | `Float x, `Float y -> compare x y
            | `Int x, `Float y -> compare (float_of_int x) y
            | `Float x, `Int y -> compare x (float_of_int y)
            | `String x, `String y -> compare x y
            | _ -> 0)
        | _ -> 0
      in
      perform (Yield (`List (List.sort compare_by l)))
  | _ -> Error.make ~colorize "sort_by" json

and min_by ~colorize ~verbose ~env expr json =
  match json with
  | `List [] -> Error.empty_list ~colorize "min_by"
  | `List l ->
      let compare_by a b =
        let res_a =
          collect_results (fun () -> interp ~colorize ~verbose ~env expr a)
        in
        let res_b =
          collect_results (fun () -> interp ~colorize ~verbose ~env expr b)
        in
        match (res_a, res_b) with
        | [ av ], [ bv ] -> (
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
      perform (Yield min_elem)
  | _ -> Error.make ~colorize "min_by" json

and max_by ~colorize ~verbose ~env expr json =
  match json with
  | `List [] -> Error.empty_list ~colorize "max_by"
  | `List l ->
      let compare_by a b =
        let res_a =
          collect_results (fun () -> interp ~colorize ~verbose ~env expr a)
        in
        let res_b =
          collect_results (fun () -> interp ~colorize ~verbose ~env expr b)
        in
        match (res_a, res_b) with
        | [ av ], [ bv ] -> (
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
      perform (Yield max_elem)
  | _ -> Error.make ~colorize "max_by" json

and unique_by ~colorize ~verbose ~env expr json =
  match json with
  | `List l ->
      let rec unique acc seen = function
        | [] -> List.rev acc
        | x :: xs -> (
            let keys =
              collect_results (fun () -> interp ~colorize ~verbose ~env expr x)
            in
            match keys with
            | [ key ] ->
                if List.mem key seen then unique acc seen xs
                else unique (x :: acc) (key :: seen) xs
            | _ -> unique (x :: acc) seen xs)
      in
      perform (Yield (`List (unique [] [] l)))
  | _ -> Error.make ~colorize "unique_by" json

and objects ~colorize ~verbose ~env list json =
  let interp_field (left_expr, right_expr) =
    let keys_res =
      match left_expr with
      | Literal (String s) -> [ `String s ]
      | expr ->
          collect_results (fun () -> interp ~colorize ~verbose ~env expr json)
    in
    let values_res =
      match right_expr with
      | None -> (
          match left_expr with
          | Literal (String s) -> (
              match json with
              | `Null -> [ `Null ]
              | _ -> [ member ~colorize s json ])
          | _ ->
              Error.message ~colorize
                "Object shorthand only allowed for string keys")
      | Some expr ->
          collect_results (fun () -> interp ~colorize ~verbose ~env expr json)
    in
    List.concat_map
      (fun k ->
        match k with
        | `String k_str -> List.map (fun v -> (k_str, v)) values_res
        | _ -> Error.message ~colorize "object key must be string")
      keys_res
  in
  let field_options_list = List.map interp_field list in
  let rec cartesian_product lists =
    match lists with
    | [] -> [ [] ]
    | first_field_options :: rest_fields ->
        let rest_product = cartesian_product rest_fields in
        List.concat_map
          (fun pair -> List.map (fun rest -> pair :: rest) rest_product)
          first_field_options
  in
  let all_combinations = cartesian_product field_options_list in
  List.iter (fun pairs -> perform (Yield (`Assoc pairs))) all_combinations

and builtin_functions ~colorize builtin json =
  match builtin with
  | Absolute -> (
      match json with
      | `Int n -> perform (Yield (`Int (abs n)))
      | `Float j -> perform (Yield (`Float (abs_float j)))
      | _ -> Error.make ~colorize "absolute" json)
  | Add -> (
      match json with
      | `List [] -> perform (Yield `Null)
      | `List l ->
          let sum =
            List.fold_left
              (fun acc el -> Operators.add ~colorize acc el)
              `Null l
          in
          perform (Yield sum)
      | _ -> Error.make ~colorize "add" json)
  | Sin -> (
      match json with
      | `Float f -> perform (Yield (`Float (sin f)))
      | `Int n -> perform (Yield (`Float (sin (float_of_int n))))
      | _ -> Error.make ~colorize "sin" json)
  | Cos -> (
      match json with
      | `Float f -> perform (Yield (`Float (cos f)))
      | `Int n -> perform (Yield (`Float (cos (float_of_int n))))
      | _ -> Error.make ~colorize "cos" json)
  | Tan -> (
      match json with
      | `Float f -> perform (Yield (`Float (tan f)))
      | `Int n -> perform (Yield (`Float (tan (float_of_int n))))
      | _ -> Error.make ~colorize "tan" json)
  | Asin -> (
      match json with
      | `Float f -> perform (Yield (`Float (asin f)))
      | `Int n -> perform (Yield (`Float (asin (float_of_int n))))
      | _ -> Error.make ~colorize "asin" json)
  | Acos -> (
      match json with
      | `Float f -> perform (Yield (`Float (acos f)))
      | `Int n -> perform (Yield (`Float (acos (float_of_int n))))
      | _ -> Error.make ~colorize "acos" json)
  | Atan -> (
      match json with
      | `Float f -> perform (Yield (`Float (atan f)))
      | `Int n -> perform (Yield (`Float (atan (float_of_int n))))
      | _ -> Error.make ~colorize "atan" json)
  | Log -> (
      match json with
      | `Float f -> perform (Yield (`Float (log f)))
      | `Int n -> perform (Yield (`Float (log (float_of_int n))))
      | _ -> Error.make ~colorize "log" json)
  | Log10 -> (
      match json with
      | `Float f -> perform (Yield (`Float (log10 f)))
      | `Int n -> perform (Yield (`Float (log10 (float_of_int n))))
      | _ -> Error.make ~colorize "log10" json)
  | Exp -> (
      match json with
      | `Float f -> perform (Yield (`Float (exp f)))
      | `Int n -> perform (Yield (`Float (exp (float_of_int n))))
      | _ -> Error.make ~colorize "exp" json)
  | Pow -> (
      match json with
      | `Float f -> perform (Yield (`Float (f ** 2.0)))
      | `Int n -> perform (Yield (`Float (float_of_int n ** 2.0)))
      | _ -> Error.make ~colorize "pow" json)
  | Ceil -> (
      match json with
      | `Float f -> perform (Yield (`Int (int_of_float (ceil f))))
      | `Int n -> perform (Yield (`Int n))
      | _ -> Error.make ~colorize "ceil" json)
  | Round -> (
      match json with
      | `Float f -> perform (Yield (`Float (Float.round f)))
      | `Int n -> perform (Yield (`Int n))
      | _ -> Error.make ~colorize "round" json)
  | Infinite ->
      let rec infinite_gen n =
        perform (Yield (`Int n));
        infinite_gen (n + 1)
      in
      infinite_gen 0
  | Now -> perform (Yield (`Float (Unix.gettimeofday ())))

and flat_map ~colorize ~verbose ~env expr json =
  match json with
  | `List list when List.length list > 0 ->
      let collected =
        List.concat_map
          (fun item ->
            collect_results (fun () -> interp ~colorize ~verbose ~env expr item))
          list
      in
      let flattened =
        List.concat_map (function `List l -> l | other -> [ other ]) collected
      in
      perform (Yield (`List flattened))
  | `List _ -> Error.empty_list ~colorize "flat_map"
  | _ -> Error.make ~colorize "flat_map" json

and find ~colorize ~verbose ~env expr json =
  match json with
  | `List list ->
      let rec find_first = function
        | [] -> perform (Yield `Null)
        | x :: xs -> (
            match
              collect_results (fun () -> interp ~colorize ~verbose ~env expr x)
            with
            | [ `Bool true ] -> perform (Yield x)
            | [ `Bool false ] -> find_first xs
            | [ other ] ->
                if other = `Null || other = `Bool false then find_first xs
                else perform (Yield x)
            | _ -> find_first xs)
      in
      find_first list
  | _ -> Error.make ~colorize "find" json

and some ~colorize ~verbose ~env expr json =
  match json with
  | `List list ->
      let rec check_some = function
        | [] -> perform (Yield (`Bool false))
        | x :: xs -> (
            match
              collect_results (fun () -> interp ~colorize ~verbose ~env expr x)
            with
            | [ `Bool true ] -> perform (Yield (`Bool true))
            | [ `Bool false ] -> check_some xs
            | [ other ] ->
                if other = `Null || other = `Bool false then check_some xs
                else perform (Yield (`Bool true))
            | _ -> check_some xs)
      in
      check_some list
  | _ -> Error.make ~colorize "some" json

and any_with_condition ~colorize ~verbose ~env expr json =
  match json with
  | `List list ->
      let is_truthy = function `Bool false | `Null -> false | _ -> true in
      let rec check_any = function
        | [] -> perform (Yield (`Bool false))
        | x :: xs -> (
            try
              let results =
                collect_results (fun () ->
                    interp ~colorize ~verbose ~env expr x)
              in
              if List.exists is_truthy results then perform (Yield (`Bool true))
              else check_any xs
            with _ -> check_any xs)
      in
      check_any list
  | _ -> Error.make ~colorize "any" json

and all_with_condition ~colorize ~verbose ~env expr json =
  match json with
  | `List list ->
      let is_truthy = function `Bool false | `Null -> false | _ -> true in
      let rec check_all = function
        | [] -> perform (Yield (`Bool true))
        | x :: xs -> (
            try
              let results =
                collect_results (fun () ->
                    interp ~colorize ~verbose ~env expr x)
              in
              if List.for_all is_truthy results then check_all xs
              else perform (Yield (`Bool false))
            with _ -> perform (Yield (`Bool false)))
      in
      check_all list
  | _ -> Error.make ~colorize "all" json

and path_of ~colorize ~verbose ~env expr json =
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
    | Pipe (left, right) ->
        let selected_values =
          collect_results (fun () -> interp ~colorize ~verbose ~env left value)
        in
        List.concat_map
          (fun selected ->
            match extract_path_for_value value selected with
            | Some left_path ->
                extract_paths (current_path @ left_path) right selected
            | None -> [])
          selected_values
    | _ -> []
  and extract_path_for_value parent child =
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
  List.iter (fun p -> perform (Yield p)) path_jsons

and reduce ~colorize ~verbose ~env generator var_name init_expr update_expr json
    =
  let init_values =
    collect_results (fun () -> interp ~colorize ~verbose ~env init_expr json)
  in
  match init_values with
  | [ init_val ] ->
      let acc = ref init_val in
      let handler =
        {
          effc =
            (fun (type a) (eff : a Effect.t) ->
              match eff with
              | Yield elem ->
                  Some
                    (fun (k : (a, _) continuation) ->
                      let env_with_var = (var_name, elem) :: env in
                      let res =
                        collect_results (fun () ->
                            interp ~colorize ~verbose ~env:env_with_var
                              update_expr !acc)
                      in
                      (match res with
                      | [ new_acc ] -> acc := new_acc
                      | _ ->
                          Error.message ~colorize
                            "reduce update expression must return single value");
                      continue k ())
              | _ -> None);
        }
      in
      try_with
        (fun () -> interp ~colorize ~verbose ~env generator json)
        () handler;
      perform (Yield !acc)
  | _ ->
      Error.message ~colorize
        "reduce init expression must return a single value"

and in_ ~colorize ~verbose ~env json expr =
  let container_results =
    collect_results (fun () -> interp ~colorize ~verbose ~env expr json)
  in
  match container_results with
  | [ container ] -> (
      match (json, container) with
      | `Int n, `List l -> perform (Yield (`Bool (n >= 0 && n < List.length l)))
      | `String key, `Assoc list ->
          perform (Yield (`Bool (List.mem_assoc key list)))
      | _ -> Error.make ~colorize "in" json)
  | _ -> Error.message ~colorize "in expects single container"

and starts_with ~colorize ~verbose ~env ~is_deprecated expr json =
  let name = if is_deprecated then "startwith/startswith" else "starts_with" in
  if is_deprecated then
    emit_warning ~verbose
      "Using deprecated 'startwith' or 'startswith'. Use 'starts_with' \
       instead. This may not be supported in future versions.";
  let patterns =
    collect_results (fun () -> interp ~colorize ~verbose ~env expr json)
  in
  List.iter
    (fun pattern ->
      match (json, pattern) with
      | `String s, `String prefix ->
          perform (Yield (`Bool (String.starts_with ~prefix s)))
      | _ -> Error.make ~colorize name json)
    patterns

and ends_with ~colorize ~verbose ~env ~is_deprecated expr json =
  let name = if is_deprecated then "endwith/endswith" else "ends_with" in
  if is_deprecated then
    emit_warning ~verbose
      "Using deprecated 'endwith' or 'endswith'. Use 'ends_with' instead. This \
       may not be supported in future versions.";
  let patterns =
    collect_results (fun () -> interp ~colorize ~verbose ~env expr json)
  in
  List.iter
    (fun pattern ->
      match (json, pattern) with
      | `String s, `String suffix ->
          perform (Yield (`Bool (String.ends_with ~suffix s)))
      | _ -> Error.make ~colorize name json)
    patterns

and with_entries ~colorize ~verbose ~env expr json =
  let update_entry_field key transform_expr fields entry =
    match List.assoc_opt key fields with
    | Some value -> (
        match
          collect_results (fun () ->
              interp ~colorize ~verbose ~env transform_expr value)
        with
        | [ new_value ] ->
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
        match expr with
        | Update (Key key, transform_expr) ->
            update_entry_field key transform_expr fields entry
        | _ -> (
            match
              collect_results (fun () ->
                  interp ~colorize ~verbose ~env expr entry)
            with
            | [ res ] -> res
            | _ -> entry))
    | _ -> entry
  in
  match to_entries ~colorize json with
  | `List entries ->
      let transformed =
        List.map (fun entry -> transform_single_entry expr entry) entries
      in
      perform (Yield (from_entries ~colorize (`List transformed)))
  | _ -> Error.make ~colorize "to_entries failed" json

and alternative ~colorize ~verbose ~env left right json =
  try
    let left_results =
      collect_results (fun () -> interp ~colorize ~verbose ~env left json)
    in
    let is_valid value =
      match value with `Null | `Bool false -> false | _ -> true
    in
    let valid_results = List.filter is_valid left_results in
    match valid_results with
    | [] -> interp ~colorize ~verbose ~env right json
    | _ -> List.iter (fun x -> perform (Yield x)) valid_results
  with Query_error _ -> interp ~colorize ~verbose ~env right json

and contains ~colorize ~verbose ~env expr json =
  let needles =
    collect_results (fun () -> interp ~colorize ~verbose ~env expr json)
  in
  match needles with
  | [ needle ] -> (
      match (json, needle) with
      | `String s, `String sub -> (
          try
            let _ = Str.search_forward (Str.regexp_string sub) s 0 in
            perform (Yield (`Bool true))
          with Not_found -> perform (Yield (`Bool false)))
      | `List haystack, `List needles_list ->
          let json_equal a b =
            match (a, b) with
            | `Int x, `Int y -> x = y
            | `Float x, `Float y -> x = y
            | `Int x, `Float y -> float_of_int x = y
            | `Float x, `Int y -> x = float_of_int y
            | _ -> a = b
          in
          perform
            (Yield
               (`Bool
                  (List.for_all
                     (fun n -> List.exists (json_equal n) haystack)
                     needles_list)))
      | _ -> Error.make ~colorize "contains" json)
  | _ -> Error.message ~colorize "contains expects single value"

and index_of ~colorize ~verbose ~env expr json =
  let needles =
    collect_results (fun () -> interp ~colorize ~verbose ~env expr json)
  in
  List.iter
    (fun needle ->
      match (json, needle) with
      | `String haystack, `String needle -> (
          try
            let pos =
              Str.search_forward (Str.regexp_string needle) haystack 0
            in
            perform (Yield (`Int pos))
          with Not_found -> perform (Yield `Null))
      | _ -> Error.make ~colorize "index" json)
    needles

and rindex_of ~colorize ~verbose ~env expr json =
  let needles =
    collect_results (fun () -> interp ~colorize ~verbose ~env expr json)
  in
  List.iter
    (fun needle ->
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
          | Some pos -> perform (Yield (`Int pos))
          | None -> perform (Yield `Null))
      | _ -> Error.make ~colorize "rindex" json)
    needles

and group_by ~colorize ~verbose ~env expr json =
  match json with
  | `List l ->
      let groups = Hashtbl.create 10 in
      List.iter
        (fun item ->
          let keys =
            collect_results (fun () -> interp ~colorize ~verbose ~env expr item)
          in
          match keys with
          | [ key ] ->
              let key_str =
                Json.to_string ~colorize:false ~summarize:false ~raw:false key
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
      perform (Yield (`List (List.map (fun items -> `List items) result)))
  | _ -> Error.make ~colorize "group_by" json

and while_loop ~colorize ~verbose ~env cond update json =
  let rec loop acc current =
    let cond_res =
      collect_results (fun () -> interp ~colorize ~verbose ~env cond current)
    in
    match cond_res with
    | [ `Bool true ] -> (
        let next_res =
          collect_results (fun () ->
              interp ~colorize ~verbose ~env update current)
        in
        match next_res with
        | [ next ] -> loop (current :: acc) next
        | _ -> List.rev acc)
    | [ `Bool false ] -> List.rev acc
    | _ -> List.rev acc
  in
  List.iter (fun x -> perform (Yield x)) (loop [] json)

and until_loop ~colorize ~verbose ~env cond update json =
  let rec loop acc current =
    let acc_with_current = current :: acc in
    let cond_res =
      collect_results (fun () -> interp ~colorize ~verbose ~env cond current)
    in
    match cond_res with
    | [ `Bool true ] -> List.rev acc_with_current
    | [ `Bool false ] -> (
        let next_res =
          collect_results (fun () ->
              interp ~colorize ~verbose ~env update current)
        in
        match next_res with
        | [ next ] -> loop acc_with_current next
        | _ -> List.rev acc_with_current)
    | _ -> List.rev acc_with_current
  in
  List.iter (fun x -> perform (Yield x)) (loop [] json)

and recurse_simple ~colorize ~verbose json =
  let rec recurse acc current =
    try
      let children =
        collect_results (fun () ->
            interp ~colorize ~verbose (Key "children") current)
      in
      match children with
      | [] -> current :: acc
      | list ->
          let new_acc = current :: acc in
          List.fold_left (fun a child -> recurse a child) new_acc list
    with _ -> current :: acc
  in
  recurse [] json

and recurse_with_cond ~colorize ~verbose ~env f cond json =
  let rec loop acc current =
    let cond_res =
      collect_results (fun () -> interp ~colorize ~verbose ~env cond current)
    in
    match cond_res with
    | [ `Bool true ] -> (
        let acc_with_current = current :: acc in
        let next_res =
          collect_results (fun () -> interp ~colorize ~verbose ~env f current)
        in
        match next_res with
        | [ next ] -> loop acc_with_current next
        | _ -> List.rev acc_with_current)
    | [ `Bool false ] -> List.rev acc
    | _ -> List.rev acc
  in
  List.iter (fun x -> perform (Yield x)) (loop [] json)

and walk_tree ~colorize ~verbose ~env expr json =
  let rec walk json =
    let walked_json =
      match json with
      | `List l -> `List (List.map walk l)
      | `Assoc obj -> `Assoc (List.map (fun (k, v) -> (k, walk v)) obj)
      | other -> other
    in
    match
      collect_results (fun () ->
          interp ~colorize ~verbose ~env expr walked_json)
    with
    | [ result ] -> result
    | _ -> walked_json
  in
  perform (Yield (walk json))

and try_catch ~colorize ~verbose ~env expr handler_opt json =
  try interp ~colorize ~verbose ~env expr json
  with Query_error _ -> (
    match handler_opt with
    | None -> ()
    | Some handler -> interp ~colorize ~verbose ~env handler json)

and limit ~colorize ~verbose ~env n expr json =
  let count = ref 0 in
  let handler =
    {
      effc =
        (fun (type a) (eff : a Effect.t) ->
          match eff with
          | Yield v ->
              Some
                (fun (k : (a, _) continuation) ->
                  if !count < n then (
                    incr count;
                    perform (Yield v);
                    continue k ())
                  else ())
          | _ -> None);
    }
  in
  try_with (fun () -> interp ~colorize ~verbose ~env expr json) () handler

and error_msg ~colorize ~verbose ~env msg_expr json =
  match msg_expr with
  | None -> Error.message ~colorize "error"
  | Some expr -> (
      let results =
        collect_results (fun () -> interp ~colorize ~verbose ~env expr json)
      in
      match results with
      | [ `String msg ] -> Error.message ~colorize msg
      | [ other ] ->
          Error.message ~colorize
            (Json.to_string ~colorize:false ~summarize:false ~raw:false other)
      | _ -> Error.message ~colorize "error expects single string")

and isempty ~colorize ~verbose ~env expr json =
  let results =
    collect_results (fun () -> interp ~colorize ~verbose ~env expr json)
  in
  match results with
  | [] -> perform (Yield (`Bool true))
  | _ -> perform (Yield (`Bool false))

and del ~colorize:_ ~verbose:_ ~env:_ path_expr json =
  match (path_expr, json) with
  | Key key, `Assoc fields ->
      let filtered = List.filter (fun (k, _) -> k <> key) fields in
      perform (Yield (`Assoc filtered))
  | Pipe (Identity, Index indices), `List items when indices <> [] ->
      let filtered = List.filteri (fun i _ -> not (List.mem i indices)) items in
      perform (Yield (`List filtered))
  | Index indices, `List items when indices <> [] ->
      let filtered = List.filteri (fun i _ -> not (List.mem i indices)) items in
      perform (Yield (`List filtered))
  | _ -> perform (Yield json)

and getpath ~colorize ~verbose ~env path_expr json =
  let paths =
    collect_results (fun () -> interp ~colorize ~verbose ~env path_expr json)
  in
  match paths with
  | [ `List path_components ] ->
      let rec navigate value = function
        | [] -> value
        | `String key :: rest -> (
            match value with
            | `Assoc fields -> (
                match List.assoc_opt key fields with
                | Some v -> navigate v rest
                | None -> `Null)
            | _ -> `Null)
        | `Int idx :: rest -> (
            match value with
            | `List items ->
                if idx >= 0 && idx < List.length items then
                  navigate (List.nth items idx) rest
                else `Null
            | _ -> `Null)
        | _ :: rest -> navigate value rest
      in
      perform (Yield (navigate json path_components))
  | _ -> Error.message ~colorize "getpath expects array path"

and setpath ~colorize ~verbose ~env path_expr value_expr json =
  let paths =
    collect_results (fun () -> interp ~colorize ~verbose ~env path_expr json)
  in
  let values =
    collect_results (fun () -> interp ~colorize ~verbose ~env value_expr json)
  in
  match (paths, values) with
  | [ `List path_components ], [ new_value ] ->
      let rec set_at value = function
        | [] -> new_value
        | `String key :: rest -> (
            match value with
            | `Assoc fields ->
                let updated =
                  List.map
                    (fun (k, v) ->
                      if k = key then (k, set_at v rest) else (k, v))
                    fields
                in
                let exists = List.mem_assoc key fields in
                if exists then `Assoc updated
                else `Assoc (fields @ [ (key, set_at `Null rest) ])
            | `Null -> `Assoc [ (key, set_at `Null rest) ]
            | _ -> value)
        | `Int idx :: rest -> (
            match value with
            | `List items ->
                let rec update_list i = function
                  | [] -> if i = idx then [ set_at `Null rest ] else []
                  | x :: xs ->
                      if i = idx then set_at x rest :: xs
                      else x :: update_list (i + 1) xs
                in
                `List (update_list 0 items)
            | `Null -> `List [ set_at `Null rest ]
            | _ -> value)
        | _ :: rest -> set_at value rest
      in
      perform (Yield (set_at json path_components))
  | _ -> Error.message ~colorize "setpath expects (path_array, value)"

and paths json =
  let rec all_paths current_path value =
    match value with
    | `Assoc fields ->
        List.concat_map
          (fun (k, v) ->
            let new_path = current_path @ [ `String k ] in
            `List new_path :: all_paths new_path v)
          fields
    | `List items ->
        List.concat_map
          (fun (i, v) ->
            let new_path = current_path @ [ `Int i ] in
            `List new_path :: all_paths new_path v)
          (List.mapi (fun i v -> (i, v)) items)
    | _ -> []
  in
  List.iter (fun p -> perform (Yield p)) (all_paths [] json)

and paths_filter ~colorize ~verbose ~env filter_expr json =
  let all = all_paths_list json in
  let rec navigate value = function
    | [] -> value
    | `String key :: rest -> (
        match value with
        | `Assoc fields -> (
            match List.assoc_opt key fields with
            | Some v -> navigate v rest
            | None -> `Null)
        | _ -> `Null)
    | `Int idx :: rest -> (
        match value with
        | `List items ->
            if idx >= 0 && idx < List.length items then
              navigate (List.nth items idx) rest
            else `Null
        | _ -> `Null)
    | _ :: rest -> navigate value rest
  in
  List.iter
    (fun path_components ->
      let value = navigate json path_components in
      let results =
        collect_results (fun () ->
            interp ~colorize ~verbose ~env filter_expr value)
      in
      let is_truthy = function `Bool false | `Null -> false | _ -> true in
      if List.exists is_truthy results then
        perform
          (Yield
             (`List
                (List.map
                   (function
                     | `String s -> `String s | `Int i -> `Int i | _ -> `Null)
                   path_components))))
    all

and all_paths_list json =
  let rec all_paths current_path value =
    match value with
    | `Assoc fields ->
        List.concat_map
          (fun (k, v) ->
            let new_path = current_path @ [ `String k ] in
            new_path :: all_paths new_path v)
          fields
    | `List items ->
        List.concat_map
          (fun (i, v) ->
            let new_path = current_path @ [ `Int i ] in
            new_path :: all_paths new_path v)
          (List.mapi (fun i v -> (i, v)) items)
    | _ -> []
  in
  all_paths [] json

and assign ~colorize ~verbose ~env path value_expr json =
  (* Assignment is like setpath but path is an AST expression, not a value *)
  (* For simple cases like .foo = 42, we can extract the path from AST *)
  match path with
  | Key key -> (
      let values =
        collect_results (fun () ->
            interp ~colorize ~verbose ~env value_expr json)
      in
      match values with
      | [ new_value ] -> (
          match json with
          | `Assoc fields ->
              let updated =
                List.map
                  (fun (k, v) -> if k = key then (k, new_value) else (k, v))
                  fields
              in
              let exists = List.mem_assoc key fields in
              if exists then perform (Yield (`Assoc updated))
              else perform (Yield (`Assoc (fields @ [ (key, new_value) ])))
          | `Null -> perform (Yield (`Assoc [ (key, new_value) ]))
          | _ -> Error.make ~colorize "assignment" json)
      | _ -> Error.message ~colorize "assignment value must be single")
  | _ ->
      Error.message ~colorize
        "complex path assignment not yet fully implemented"

let execute ~colorize ~verbose ?(env = []) expr json =
  let unhandled_effect_handler =
    {
      effc =
        (fun (type a) (eff : a Effect.t) ->
          match eff with
          | Break ->
              Some
                (fun (_ : (a, _) continuation) ->
                  Error.message ~colorize "break used outside of loop context")
          | Halt exit_code ->
              Some (fun (_ : (a, _) continuation) -> exit exit_code)
          | _ -> None);
    }
  in
  try
    Ok
      (collect_results (fun () ->
           try_with
             (fun () -> interp ~colorize ~verbose ~env expr json)
             () unhandled_effect_handler))
  with
  | Query_error msg -> Error msg
  | e -> Error (Printexc.to_string e)
