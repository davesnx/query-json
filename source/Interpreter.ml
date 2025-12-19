open Ast

type _ Effect.t += Yield : Json.t -> unit Effect.t
type _ Effect.t += Break : unit Effect.t
type _ Effect.t += Halt : int -> unit Effect.t
type _ Effect.t += Fail : string -> unit Effect.t
type ctx = { colorize : bool; verbose : bool; env : (string * Json.t) list }

let yield v = Effect.perform (Yield v)
let break () = Effect.perform Break
let halt ?(code = 0) () = Effect.perform (Halt code)

let fail msg =
  Effect.perform (Fail msg);
  assert false (* unreachable - handler never continues *)

let yield_many items = List.iter yield items

let run fn ?and_then ?on_fail () =
  let handler : 'a Effect.Deep.effect_handler =
    {
      effc =
        (fun (type a) (eff : a Effect.t) ->
          match eff with
          | Yield json -> (
              match and_then with
              | Some f ->
                  Some
                    (fun (k : (a, _) continuation) ->
                      f json;
                      Effect.Deep.continue k ())
              | None -> None)
          | Fail msg -> (
              match on_fail with
              | Some f -> Some (fun (_ : (a, _) continuation) -> f msg)
              | None -> None)
          | _ -> None);
    }
  in
  Effect.Deep.try_with fn () handler

let run_while fn ~when_ =
  let handler : 'a Effect.Deep.effect_handler =
    {
      effc =
        (fun (type a) (eff : a Effect.t) ->
          match eff with
          | Yield v ->
              Some
                (fun (k : (a, _) continuation) ->
                  if when_ v then Effect.Deep.continue k () else ())
          | _ -> None);
    }
  in
  Effect.Deep.try_with fn () handler

let run_and_collect_results fn =
  let handler : (unit, Json.t list) Effect.Deep.handler =
    {
      retc = (fun () -> []);
      exnc = (fun e -> raise e);
      effc =
        (fun (type a) (eff : a Effect.t) ->
          match eff with
          | Yield v ->
              Some
                (fun (k : (a, _) continuation) ->
                  v :: Effect.Deep.continue k ())
          | _ -> None);
    }
  in
  Effect.Deep.match_with fn () handler

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

  let empty_list ~ctx op =
    let open Formatting in
    let open Ansi.To_string (struct
      let colorize = ctx.colorize
    end) in
    fail ("Trying to " ^ single_quotes (bold op) ^ " on an empty array.")

  let structure ~ctx op msg actual_value =
    let open Formatting in
    let open Ansi.To_string (struct
      let colorize = ctx.colorize
    end) in
    fail
      ("Invalid structure for "
      ^ single_quotes (bold op)
      ^ ": " ^ msg ^ "." ^ enter 1
      ^ gray
          (Json.to_string actual_value ~colorize:ctx.colorize ~summarize:true
             ~raw:false))

  let message ~ctx msg =
    let open Ansi.To_string (struct
      let colorize = ctx.colorize
    end) in
    fail (red "Error: " ^ msg)

  let make ~ctx (name : string) (json : Json.t) =
    let open Formatting in
    let open Ansi.To_string (struct
      let colorize = ctx.colorize
    end) in
    fail
      ("Trying to "
      ^ single_quotes (bold name)
      ^ " on "
      ^ bold (prepend_article (Json.type_of json))
      ^ ":" ^ enter 1
      ^ gray
          (Json.to_string json ~colorize:ctx.colorize ~summarize:true ~raw:false)
      )

  let missing_member ~ctx op key (value : Json.t) =
    let open Formatting in
    let open Ansi.To_string (struct
      let colorize = ctx.colorize
    end) in
    fail
      ("Trying to "
      ^ double_quotes (bold op)
      ^ " on an object, that don't have the field " ^ double_quotes key ^ ":"
      ^ enter 1
      ^ gray
          (Json.to_string value ~colorize:ctx.colorize ~summarize:true
             ~raw:false))
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

  let rec add ~ctx str (left : Json.t) (right : Json.t) : Json.t =
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
          let result = add ~ctx str v1 v2 in
          (key, result)
        in
        let f (key, v) = (key, v) in
        `Assoc (merge_map ~f ~eq cmp l r)
    | `Null, `Assoc r | `Assoc r, `Null -> `Assoc r
    | `List l, `List r -> `List (l @ r)
    | `Null, `List r | `List r, `Null -> `List r
    | `Null, `Null -> `Null
    | _ -> Error.make ~ctx str left

  let apply_operation ~ctx str fn (left : Json.t) (right : Json.t) =
    match (left, right) with
    | `Float l, `Float r -> `Float (fn l r)
    | `Int l, `Float r -> `Float (fn (Int.to_float l) r)
    | `Float l, `Int r -> `Float (fn l (Int.to_float r))
    | `Int l, `Int r -> `Float (fn (Int.to_float l) (Int.to_float r))
    | _ -> Error.make ~ctx str left

  let compare ~ctx str fn (left : Json.t) (right : Json.t) =
    match (left, right) with
    | `Float l, `Float r -> `Bool (fn l r)
    | `Int l, `Float r -> `Bool (fn (Int.to_float l) r)
    | `Float l, `Int r -> `Bool (fn l (Int.to_float r))
    | `Int l, `Int r -> `Bool (fn (Int.to_float l) (Int.to_float r))
    | _ -> Error.make ~ctx str right

  let condition ~ctx (str : string) (fn : bool -> bool -> bool) (left : Json.t)
      (right : Json.t) =
    match (left, right) with
    | `Bool l, `Bool r -> `Bool (fn l r)
    | _ -> Error.make ~ctx str right

  let gt ~ctx = compare ~ctx ">" ( > )
  let gte ~ctx = compare ~ctx ">=" ( >= )
  let lt ~ctx = compare ~ctx "<" ( < )
  let lte ~ctx = compare ~ctx "<=" ( <= )
  let and_ ~ctx = condition ~ctx "and" ( && )
  let or_ ~ctx = condition ~ctx "or" ( || )
  let equal l r = `Bool (l = r)
  let not_equal l r = `Bool (l <> r)
  let add ~ctx = add ~ctx "+"
  let subtract ~ctx = apply_operation ~ctx "-" (fun l r -> l -. r)
  let multiply ~ctx = apply_operation ~ctx "*" (fun l r -> l *. r)
  let divide ~ctx = apply_operation ~ctx "/" (fun l r -> l /. r)
  let modulo ~ctx = apply_operation ~ctx "%" (fun l r -> mod_float l r)

  let apply_to_number ~ctx name f json =
    match json with
    | `Float x -> `Float (f x)
    | `Int n -> `Float (f (Float.of_int n))
    | _ -> Error.make ~ctx name json

  let sin_ ~ctx = apply_to_number ~ctx "sin" Stdlib.sin
  let cos_ ~ctx = apply_to_number ~ctx "cos" Stdlib.cos
  let tan_ ~ctx = apply_to_number ~ctx "tan" Stdlib.tan
  let asin_ ~ctx = apply_to_number ~ctx "asin" Stdlib.asin
  let acos_ ~ctx = apply_to_number ~ctx "acos" Stdlib.acos
  let atan_ ~ctx = apply_to_number ~ctx "atan" Stdlib.atan
  let log_ ~ctx = apply_to_number ~ctx "log" Stdlib.log
  let log10_ ~ctx = apply_to_number ~ctx "log10" Stdlib.log10
  let exp_ ~ctx = apply_to_number ~ctx "exp" Stdlib.exp
end

let keys ~ctx (json : Json.t) =
  match json with
  | `Assoc _list -> `List (Json.keys json |> List.map (fun i -> `String i))
  | _ -> Error.make ~ctx "keys" json

let has ~ctx (json : Json.t) key =
  match key with
  | String key -> (
      match json with
      | `Assoc list -> `Bool (List.mem_assoc key list)
      | _ -> Error.make ~ctx "has" json)
  | Number n -> (
      match json with
      | `List list -> `Bool (List.length list - 1 >= Int.of_float n)
      | _ -> Error.make ~ctx "has" json)
  | _ -> Error.make ~ctx "has" json

let range ?step from upto =
  let rec range ?(step = 1) start stop =
    if step = 0 then []
    else if (step > 0 && start >= stop) || (step < 0 && start <= stop) then []
    else start :: range ~step (start + step) stop
  in
  match upto with None -> range 1 from | Some upto -> range ?step from upto

let split ~ctx expr json =
  match json with
  | `String s ->
      let rcase =
        match expr with
        | Literal (String s) -> s
        | _ ->
            Error.message ~ctx
              "Invalid argument for 'split': expected string literal"
      in
      `List (Str.split (Str.regexp rcase) s |> List.map (fun s -> `String s))
  | _ -> Error.make ~ctx "split" json

let join ~ctx expr json =
  let rcase =
    match expr with
    | Literal (String s) -> s
    | _ ->
        Error.message ~ctx
          "Invalid argument for 'join': expected string literal"
  in
  match json with
  | `List l ->
      `String
        (List.map (function `String s -> s | _ -> "") l |> String.concat rcase)
  | _ -> Error.make ~ctx "join" json

let length ~ctx (json : Json.t) =
  match json with
  | `List list -> `Int (List.length list)
  | `String s -> `Int (String.length s)
  | `Assoc obj -> `Int (List.length obj)
  | `Null -> `Int 0
  | _ -> Error.make ~ctx "length" json

let emit_warning ~verbose message =
  if verbose then Printf.eprintf "Warning: %s\n%!" message else ()

let floor ~ctx (json : Json.t) =
  match json with
  | `Float f -> `Int (Int.of_float (floor f))
  | `Int n -> `Int n
  | _ -> Error.make ~ctx "floor" json

let sqrt ~ctx (json : Json.t) =
  match json with
  | `Float f -> `Float (sqrt f)
  | `Int n -> `Float (sqrt (Float.of_int n))
  | _ -> Error.make ~ctx "sqrt" json

let to_number ~ctx ~deprecated (json : Json.t) =
  let name = if deprecated then "tonumber" else "to_number" in
  if deprecated then
    emit_warning ~verbose:ctx.verbose
      "Using deprecated 'tonumber'. Use 'to_number' instead. This may not be \
       supported in future versions.";
  match json with
  | `String s -> (
      match Float.of_string_opt s with
      | Some f -> `Float f
      | None -> Error.make ~ctx name json)
  | `Int _ | `Float _ -> json
  | _ -> Error.make ~ctx name json

let to_string ~ctx ~deprecated (json : Json.t) =
  if deprecated then
    emit_warning ~verbose:ctx.verbose
      "Using deprecated 'tostring'. Use 'to_string' instead. This may not be \
       supported in future versions.";
  `String (Json.to_string ~colorize:false ~summarize:false ~raw:false json)

let min ~ctx (json : Json.t) =
  match json with
  | `List [] -> Error.empty_list ~ctx "min"
  | `List l ->
      let compare_json a b =
        match (a, b) with
        | `Int x, `Int y -> compare x y
        | `Float x, `Float y -> compare x y
        | `Int x, `Float y -> compare (Float.of_int x) y
        | `Float x, `Int y -> compare x (Float.of_int y)
        | _ -> 0
      in
      List.fold_left
        (fun acc x -> if compare_json x acc < 0 then x else acc)
        (List.hd l) (List.tl l)
  | _ -> Error.make ~ctx "min" json

let max ~ctx (json : Json.t) =
  match json with
  | `List [] -> Error.empty_list ~ctx "max"
  | `List l ->
      let compare_json a b =
        match (a, b) with
        | `Int x, `Int y -> compare x y
        | `Float x, `Float y -> compare x y
        | `Int x, `Float y -> compare (Float.of_int x) y
        | `Float x, `Int y -> compare x (Float.of_int y)
        | _ -> 0
      in
      List.fold_left
        (fun acc x -> if compare_json x acc > 0 then x else acc)
        (List.hd l) (List.tl l)
  | _ -> Error.make ~ctx "max" json

let flatten ~ctx depth_opt (json : Json.t) =
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
  | _ -> Error.make ~ctx "flatten" json

let sort ~ctx (json : Json.t) =
  match json with
  | `List l ->
      let compare_json a b =
        match (a, b) with
        | `Int x, `Int y -> compare x y
        | `Float x, `Float y -> compare x y
        | `Int x, `Float y -> compare (Float.of_int x) y
        | `Float x, `Int y -> compare x (Float.of_int y)
        | `String x, `String y -> compare x y
        | _ -> 0
      in
      `List (List.sort compare_json l)
  | _ -> Error.make ~ctx "sort" json

let unique ~ctx (json : Json.t) =
  match json with
  | `List l ->
      let rec unique acc = function
        | [] -> List.rev acc
        | x :: xs ->
            if List.mem x acc then unique acc xs else unique (x :: acc) xs
      in
      `List (unique [] l)
  | _ -> Error.make ~ctx "unique" json

let any ~ctx (json : Json.t) =
  match json with
  | `List l ->
      let is_truthy = function `Bool false | `Null -> false | _ -> true in
      `Bool (List.exists is_truthy l)
  | _ -> Error.make ~ctx "any" json

let all ~ctx (json : Json.t) =
  match json with
  | `List l ->
      let is_truthy = function `Bool false | `Null -> false | _ -> true in
      `Bool (List.for_all is_truthy l)
  | _ -> Error.make ~ctx "all" json

let to_entries ~ctx (json : Json.t) =
  match json with
  | `Assoc obj ->
      let entries =
        List.map
          (fun (key, value) ->
            `Assoc [ ("key", `String key); ("value", value) ])
          obj
      in
      `List entries
  | _ -> Error.structure ~ctx "to_entries" "requires an object" json

let from_entries ~ctx (json : Json.t) =
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
                    Error.structure ~ctx "from_entries"
                      "requires objects with 'key' (string) and 'value' fields"
                      json)
            | _ ->
                Error.structure ~ctx "from_entries"
                  "requires an array of objects" json)
      in
      `Assoc (convert [] entries)
  | _ -> Error.make ~ctx "from_entries" json

let explode ~ctx (json : Json.t) =
  match json with
  | `String s ->
      let codepoints =
        List.init (String.length s) (fun i -> `Int (Char.code (String.get s i)))
      in
      `List codepoints
  | _ -> Error.make ~ctx "explode" json

let implode ~ctx (json : Json.t) =
  match json with
  | `List l ->
      let chars =
        List.map (function `Int n -> Char.chr n | _ -> Char.chr 0) l
      in
      `String (String.of_seq (List.to_seq chars))
  | _ -> Error.make ~ctx "implode" json

let is_nan ~ctx (json : Json.t) =
  match json with
  | `Float f -> `Bool (Float.is_nan f)
  | `Int _ -> `Bool false
  | _ -> Error.make ~ctx "is_nan" json

let transpose ~ctx (json : Json.t) =
  match json with
  | `List [] -> `List []
  | `List rows ->
      let get_length row =
        match row with `List l -> Some (List.length l) | _ -> None
      in
      let lengths = List.filter_map get_length rows in
      if List.length lengths <> List.length rows then
        Error.structure ~ctx "transpose" "requires an array of arrays" json
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
  | _ -> Error.make ~ctx "transpose" json

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

let test_regex ~ctx pattern json =
  match json with
  | `String s -> (
      try
        let regex = Str.regexp pattern in
        let _ = Str.search_forward regex s 0 in
        `Bool true
      with Not_found -> `Bool false)
  | _ -> Error.make ~ctx "test" json

let match_regex ~ctx pattern json =
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
        yield result
      with Not_found -> ())
  | _ -> Error.make ~ctx "match" json

let scan_regex ~ctx pattern json =
  match json with
  | `String s ->
      let regex = Str.regexp pattern in
      let rec scan_all pos =
        try
          let _ = Str.search_forward regex s pos in
          let matched = Str.matched_string s in
          yield (`String matched);
          scan_all (Str.match_end ())
        with Not_found -> ()
      in
      scan_all 0
  | _ -> Error.make ~ctx "scan" json

let capture_regex ~ctx pattern json =
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
        yield (`List (List.rev_map (fun c -> `String c) !captures))
      with Not_found -> yield (`List []))
  | _ -> Error.make ~ctx "capture" json

let sub_regex ~ctx pattern replacement json =
  match json with
  | `String s -> (
      try
        let regex = Str.regexp pattern in
        `String (Str.replace_first regex replacement s)
      with _ -> json)
  | _ -> Error.make ~ctx "sub" json

let gsub_regex ~ctx pattern replacement json =
  match json with
  | `String s -> (
      try
        let regex = Str.regexp pattern in
        `String (Str.global_replace regex replacement s)
      with _ -> json)
  | _ -> Error.make ~ctx "gsub" json

let head ~ctx (json : Json.t) =
  match json with
  | `List list -> (
      match List.length list > 0 with
      | true -> Json.index 0 json
      | false -> Error.empty_list ~ctx "head")
  | _ -> Error.make ~ctx "head" json

let tail ~ctx (json : Json.t) =
  match json with
  | `List list -> (
      match List.length list > 0 with
      | true ->
          let last_index = List.length list - 1 in
          Json.index last_index json
      | false -> Error.empty_list ~ctx "tail")
  | _ -> Error.make ~ctx "tail" json

let member ~ctx (key : string) (json : Json.t) =
  match json with
  | `Assoc _assoc -> (
      let access_member = Json.member key json in
      match access_member with
      | `Null -> Error.missing_member ~ctx ("." ^ key) key json
      | _ -> access_member)
  | _ -> Error.make ~ctx ("." ^ key) json

let iterator ~ctx (json : Json.t) =
  match json with
  | `List [] -> ()
  | `List items -> yield_many items
  | `Assoc obj -> List.iter (fun (_, x) -> yield x) obj
  | _ -> Error.make ~ctx "[]" json

let rec index ~ctx (indices : int list) (json : Json.t) =
  match indices with
  | [] -> iterator ~ctx json
  | [ value ] -> (
      match json with
      | `List list when List.length list > value ->
          yield (Json.index value json)
      | `List _ -> yield `Null
      | _ -> Error.make ~ctx ("[" ^ Int.to_string value ^ "]") json)
  | multiple -> List.iter (fun idx -> index ~ctx [ idx ] json) multiple

let slice ~ctx (start : int option) (finish : int option) (json : Json.t) =
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
  | `String _s when finish < start -> yield (`String "")
  | `String s -> yield (`String (String.sub s start (finish - start)))
  | `List _l when finish < start -> yield (`List [])
  | `List l ->
      let sliced =
        List.fold_left
          (fun (acc, i) x ->
            if i >= start && i < finish then (x :: acc, i + 1) else (acc, i + 1))
          ([], 0) l
        |> fst |> List.rev
      in
      yield (`List sliced)
  | _ ->
      Error.make ~ctx
        ("[" ^ Int.to_string start ^ ":" ^ Int.to_string finish ^ "]")
        json

let rec interp ~ctx expression json : unit =
  match expression with
  | Identity -> yield json
  | Empty -> ()
  | Keys -> yield (keys ~ctx json)
  | Key key -> yield (member ~ctx key json)
  | Optional expr ->
      run (fun () -> interp ~ctx expr json) ~on_fail:(fun _ -> yield `Null) ()
  | Index idx -> index ~ctx idx json
  | Iterator -> iterator ~ctx json
  | Slice (start, finish) -> slice ~ctx start finish json
  | Head -> yield (head ~ctx json)
  | Tail -> yield (tail ~ctx json)
  | Length -> yield (length ~ctx json)
  | Not -> yield (Operators.not json)
  | Type -> yield (`String (Json.type_of json))
  | Floor -> yield (floor ~ctx json)
  | Sqrt -> yield (sqrt ~ctx json)
  | To_number -> yield (to_number ~ctx ~deprecated:false json)
  | Tonumber -> yield (to_number ~ctx ~deprecated:true json)
  | To_string -> yield (to_string ~ctx ~deprecated:false json)
  | Tostring -> yield (to_string ~ctx ~deprecated:true json)
  | Min -> yield (min ~ctx json)
  | Max -> yield (max ~ctx json)
  | Flatten depth -> yield (flatten ~ctx depth json)
  | Sort -> yield (sort ~ctx json)
  | Unique -> yield (unique ~ctx json)
  | Any -> yield (any ~ctx json)
  | All -> yield (all ~ctx json)
  | Starts_with expr -> starts_with ~ctx ~is_deprecated:false expr json
  | Startwith expr -> starts_with ~ctx ~is_deprecated:true expr json
  | Ends_with expr -> ends_with ~ctx ~is_deprecated:false expr json
  | Endwith expr -> ends_with ~ctx ~is_deprecated:true expr json
  | To_entries -> yield (to_entries ~ctx json)
  | From_entries -> yield (from_entries ~ctx json)
  | With_entries expr -> with_entries ~ctx expr json
  | Contains expr -> contains ~ctx expr json
  | Explode -> yield (explode ~ctx json)
  | Implode -> yield (implode ~ctx json)
  | Map expr -> map ~ctx expr json
  | Operation (left, op, right) -> operation ~ctx left right op json
  | Literal literal -> (
      match literal with
      | Bool b -> yield (`Bool b)
      | Number f -> yield (`Float f)
      | String s -> yield (`String s)
      | Null -> yield `Null)
  | Pipe (left, right) ->
      run
        (fun () -> interp ~ctx left json)
        ~and_then:(fun json -> interp ~ctx right json)
        ()
  | Update (path, transform) ->
      run
        (fun () -> interp ~ctx path json)
        ~and_then:(fun json -> interp ~ctx transform json)
        ()
  | Alternative (left, right) -> alternative ~ctx left right json
  | Select conditional ->
      run
        (fun () -> interp ~ctx conditional json)
        ~and_then:(fun result ->
          match result with `Bool false | `Null -> () | _ -> yield json)
        ()
  | List None -> yield (`List [])
  | List (Some expr) ->
      let results = collect ~ctx expr json in
      yield (`List results)
  | Comma (left_expr, right_expr) ->
      interp ~ctx left_expr json;
      interp ~ctx right_expr json
  | Object [] -> yield (`Assoc [])
  | Object list -> objects ~ctx list json
  | Has expr -> (
      match expr with
      | Literal ((String _ | Number _) as lit) -> yield (has ~ctx json lit)
      | _ -> Error.message ~ctx (show_expression expr ^ " is not allowed"))
  | In expr -> in_ ~ctx json expr
  | Range (from, upto, step) ->
      let vals = range ?step from upto in
      List.iter (fun i -> yield (`Int i)) vals
  | Reverse -> (
      match json with
      | `List l -> yield (`List (List.rev l))
      | _ -> Error.make ~ctx "reverse" json)
  | Split expr -> yield (split ~ctx expr json)
  | Join expr -> yield (join ~ctx expr json)
  | Fun builtin -> builtin_functions ~ctx builtin json
  | If_then_else (cond, if_branch, else_branch) ->
      run
        (fun () -> interp ~ctx cond json)
        ~and_then:(function
          | `Bool true -> interp ~ctx if_branch json
          | `Bool false | `Null -> interp ~ctx else_branch json
          | v -> Error.make ~ctx "if condition should be a bool" v)
        ()
  | Sort_by expr -> sort_by ~ctx expr json
  | Min_by expr -> min_by ~ctx expr json
  | Max_by expr -> max_by ~ctx expr json
  | Unique_by expr -> unique_by ~ctx expr json
  | Index_of expr -> index_of ~ctx expr json
  | Rindex_of expr -> rindex_of ~ctx expr json
  | Group_by expr -> group_by ~ctx expr json
  | While (cond, update) -> while_loop ~ctx cond update json
  | Until (cond, update) -> until_loop ~ctx cond update json
  | Recurse ->
      let results = recurse ~ctx json in
      yield_many results
  | Recurse_with (f, cond) ->
      let results = recurse_with_cond ~ctx f cond json in
      yield_many results
  | Recurse_down ->
      let results = recurse_down json in
      yield_many results
  | Walk expr -> walk_tree ~ctx expr json
  | Transpose expr ->
      run
        (fun () -> interp ~ctx expr json)
        ~and_then:(fun json -> yield (transpose ~ctx json))
        ()
  | Nan -> yield (`Float nan)
  | Is_nan -> yield (is_nan ~ctx json)
  | Flat_map expr -> flat_map ~ctx expr json
  | Find expr -> find ~ctx expr json
  | Some_ expr -> some ~ctx expr json
  | Any_with_condition expr -> any_with_condition ~ctx expr json
  | All_with_condition expr -> all_with_condition ~ctx expr json
  | Test pattern -> yield (test_regex ~ctx pattern json)
  | Match pattern -> match_regex ~ctx pattern json
  | Scan pattern -> scan_regex ~ctx pattern json
  | Capture pattern -> capture_regex ~ctx pattern json
  | Sub (pattern, replacement) ->
      yield (sub_regex ~ctx pattern replacement json)
  | Gsub (pattern, replacement) ->
      yield (gsub_regex ~ctx pattern replacement json)
  | Path expr -> path_of ~ctx expr json
  | Variable var_name -> (
      match List.assoc_opt var_name ctx.env with
      | Some value -> yield value
      | None -> Error.message ~ctx ("Undefined variable: $" ^ var_name))
  | Def (name, _params, _body) ->
      Error.message ~ctx
        ("def " ^ name
       ^ " is not yet fully implemented - definitions should be at program top \
          level")
  | Call (fname, _args) ->
      Error.message ~ctx
        ("calling function " ^ fname ^ " - custom functions not yet implemented")
  | Reduce (expr, var_name, init_expr, update_expr) ->
      reduce ~ctx expr var_name init_expr update_expr json
  | Break -> break ()
  | Try (expr, handler) -> try_catch ~ctx expr handler json
  | Limit (n, expr) -> limit ~ctx n expr json
  | Error_msg msg_expr -> error_msg ~ctx msg_expr json
  | Halt -> halt ()
  | Halt_error exit_code -> halt ~code:(Option.value exit_code ~default:1) ()
  | Isempty expr -> isempty ~ctx expr json
  | Del expr -> del ~ctx expr json
  | Getpath expr -> getpath ~ctx expr json
  | Setpath (path, value_expr) -> setpath ~ctx path value_expr json
  | Paths -> paths json
  | Paths_filter expr -> paths_filter ~ctx expr json
  | Assign (path, value_expr) -> assign ~ctx path value_expr json
  | Foreach (expr, var_name, init_expr, update_expr, extract_expr) ->
      foreach ~ctx expr var_name init_expr update_expr extract_expr json
  | Label (_, _) -> Error.message ~ctx "label is not yet implemented"

and collect ~ctx expr json =
  run_and_collect_results (fun () -> interp ~ctx expr json)

and operation ~ctx left_expr right_expr op json =
  let apply_op l_val r_val =
    match op with
    | Add -> Operators.add ~ctx l_val r_val
    | Subtract -> Operators.subtract ~ctx l_val r_val
    | Multiply -> Operators.multiply ~ctx l_val r_val
    | Divide -> Operators.divide ~ctx l_val r_val
    | Modulo -> Operators.modulo ~ctx l_val r_val
    | Greater_than -> Operators.gt ~ctx l_val r_val
    | Greater_than_or_equal -> Operators.gte ~ctx l_val r_val
    | Less_than -> Operators.lt ~ctx l_val r_val
    | Less_than_or_equal -> Operators.lte ~ctx l_val r_val
    | Equal -> Operators.equal l_val r_val
    | Not_equal -> Operators.not_equal l_val r_val
    | And -> Operators.and_ ~ctx l_val r_val
    | Or -> Operators.or_ ~ctx l_val r_val
  in
  run
    (fun () -> interp ~ctx left_expr json)
    ~and_then:(fun l_val ->
      run
        (fun () -> interp ~ctx right_expr json)
        ~and_then:(fun r_val -> yield (apply_op l_val r_val))
        ())
    ()

and map ~ctx (expr : expression) (json : Json.t) =
  match json with
  | `List list when List.length list > 0 ->
      let collected =
        List.concat_map (fun item -> collect ~ctx expr item) list
      in
      yield (`List collected)
  | `List _ -> yield (`List [])
  | _ -> Error.make ~ctx "map" json

and sort_by ~ctx expr json =
  match json with
  | `List l ->
      let compare_by a b =
        let res_a = collect ~ctx expr a in
        let res_b = collect ~ctx expr b in
        match (res_a, res_b) with
        | [ av ], [ bv ] -> (
            match (av, bv) with
            | `Int x, `Int y -> compare x y
            | `Float x, `Float y -> compare x y
            | `Int x, `Float y -> compare (Float.of_int x) y
            | `Float x, `Int y -> compare x (Float.of_int y)
            | `String x, `String y -> compare x y
            | _ -> 0)
        | _ -> 0
      in
      let sorted = List.sort compare_by l in
      yield (`List sorted)
  | _ -> Error.make ~ctx "sort_by" json

and min_by ~ctx expr json =
  match json with
  | `List [] -> Error.empty_list ~ctx "min_by"
  | `List l ->
      let compare_by a b =
        let res_a = collect ~ctx expr a in
        let res_b = collect ~ctx expr b in
        match (res_a, res_b) with
        | [ av ], [ bv ] -> (
            match (av, bv) with
            | `Int x, `Int y -> compare x y
            | `Float x, `Float y -> compare x y
            | `Int x, `Float y -> compare (Float.of_int x) y
            | `Float x, `Int y -> compare x (Float.of_int y)
            | _ -> 0)
        | _ -> 0
      in
      let min_elem =
        List.fold_left
          (fun acc x -> if compare_by x acc < 0 then x else acc)
          (List.hd l) (List.tl l)
      in
      yield min_elem
  | _ -> Error.make ~ctx "min_by" json

and max_by ~ctx expr json =
  match json with
  | `List [] -> Error.empty_list ~ctx "max_by"
  | `List l ->
      let compare_by a b =
        let res_a = collect ~ctx expr a in
        let res_b = collect ~ctx expr b in
        match (res_a, res_b) with
        | [ av ], [ bv ] -> (
            match (av, bv) with
            | `Int x, `Int y -> compare x y
            | `Float x, `Float y -> compare x y
            | `Int x, `Float y -> compare (Float.of_int x) y
            | `Float x, `Int y -> compare x (Float.of_int y)
            | _ -> 0)
        | _ -> 0
      in
      let max_elem =
        List.fold_left
          (fun acc x -> if compare_by x acc > 0 then x else acc)
          (List.hd l) (List.tl l)
      in
      yield max_elem
  | _ -> Error.make ~ctx "max_by" json

and unique_by ~ctx expr json =
  match json with
  | `List l ->
      let rec unique acc seen = function
        | [] -> List.rev acc
        | x :: xs -> (
            let keys = collect ~ctx expr x in
            match keys with
            | [ key ] ->
                if List.mem key seen then unique acc seen xs
                else unique (x :: acc) (key :: seen) xs
            | _ -> unique (x :: acc) seen xs)
      in
      yield (`List (unique [] [] l))
  | _ -> Error.make ~ctx "unique_by" json

and objects ~ctx list json =
  let interp_field (left_expr, right_expr) =
    let keys_res =
      match left_expr with
      | Literal (String s) -> [ `String s ]
      | expr -> collect ~ctx expr json
    in
    let values_res =
      match right_expr with
      | None -> (
          match left_expr with
          | Literal (String s) -> (
              match json with `Null -> [ `Null ] | _ -> [ member ~ctx s json ])
          | _ ->
              Error.message ~ctx "Object shorthand only allowed for string keys"
          )
      | Some expr -> collect ~ctx expr json
    in
    List.concat_map
      (fun k ->
        match k with
        | `String k_str -> List.map (fun v -> (k_str, v)) values_res
        | _ -> Error.message ~ctx "object key must be string")
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
  List.iter (fun pairs -> yield (`Assoc pairs)) all_combinations

and builtin_functions ~ctx builtin json =
  match builtin with
  | Absolute -> (
      match json with
      | `Int n -> yield (`Int (abs n))
      | `Float j -> yield (`Float (abs_float j))
      | _ -> Error.make ~ctx "absolute" json)
  | Add -> (
      match json with
      | `List [] -> yield `Null
      | `List l ->
          let sum =
            List.fold_left (fun acc el -> Operators.add ~ctx acc el) `Null l
          in
          yield sum
      | _ -> Error.make ~ctx "add" json)
  | Sin -> yield (Operators.sin_ ~ctx json)
  | Cos -> yield (Operators.cos_ ~ctx json)
  | Tan -> yield (Operators.tan_ ~ctx json)
  | Asin -> yield (Operators.asin_ ~ctx json)
  | Acos -> yield (Operators.acos_ ~ctx json)
  | Atan -> yield (Operators.atan_ ~ctx json)
  | Log -> yield (Operators.log_ ~ctx json)
  | Log10 -> yield (Operators.log10_ ~ctx json)
  | Exp -> yield (Operators.exp_ ~ctx json)
  | Pow -> (
      match json with
      | `Float f -> yield (`Float (f ** 2.0))
      | `Int n -> yield (`Float (Float.of_int n ** 2.0))
      | _ -> Error.make ~ctx "pow" json)
  | Ceil -> (
      match json with
      | `Float f -> yield (`Int (Int.of_float (ceil f)))
      | `Int n -> yield (`Int n)
      | _ -> Error.make ~ctx "ceil" json)
  | Round -> (
      match json with
      | `Float f -> yield (`Float (Float.round f))
      | `Int n -> yield (`Int n)
      | _ -> Error.make ~ctx "round" json)
  | Infinite ->
      let rec infinite_gen n =
        yield (`Int n);
        infinite_gen (n + 1)
      in
      infinite_gen 0
  | Now -> yield (`Float (Unix.gettimeofday ()))

and flat_map ~ctx expr json =
  match json with
  | `List list when List.length list > 0 ->
      let collected =
        List.concat_map (fun item -> collect ~ctx expr item) list
      in
      let flattened =
        List.concat_map (function `List l -> l | other -> [ other ]) collected
      in
      yield (`List flattened)
  | `List _ -> Error.empty_list ~ctx "flat_map"
  | _ -> Error.make ~ctx "flat_map" json

and find ~ctx expr json =
  match json with
  | `List list ->
      let rec find_first = function
        | [] -> yield `Null
        | x :: xs -> (
            match collect ~ctx expr x with
            | [ `Bool true ] -> yield x
            | [ `Bool false ] -> find_first xs
            | [ other ] ->
                if other = `Null || other = `Bool false then find_first xs
                else yield x
            | _ -> find_first xs)
      in
      find_first list
  | _ -> Error.make ~ctx "find" json

and some ~ctx expr json =
  match json with
  | `List list ->
      let rec check_some = function
        | [] -> yield (`Bool false)
        | x :: xs -> (
            match collect ~ctx expr x with
            | [ `Bool true ] -> yield (`Bool true)
            | [ `Bool false ] -> check_some xs
            | [ other ] ->
                if other = `Null || other = `Bool false then check_some xs
                else yield (`Bool true)
            | _ -> check_some xs)
      in
      check_some list
  | _ -> Error.make ~ctx "some" json

and any_with_condition ~ctx expr json =
  match json with
  | `List list ->
      let is_truthy = function `Bool false | `Null -> false | _ -> true in
      let rec check_any = function
        | [] -> yield (`Bool false)
        | x :: xs -> (
            try
              let results = collect ~ctx expr x in
              if List.exists is_truthy results then yield (`Bool true)
              else check_any xs
            with _ -> check_any xs)
      in
      check_any list
  | _ -> Error.make ~ctx "any" json

and all_with_condition ~ctx expr json =
  match json with
  | `List list ->
      let is_truthy = function `Bool false | `Null -> false | _ -> true in
      let rec check_all = function
        | [] -> yield (`Bool true)
        | x :: xs -> (
            try
              let results = collect ~ctx expr x in
              if List.for_all is_truthy results then check_all xs
              else yield (`Bool false)
            with _ -> yield (`Bool false))
      in
      check_all list
  | _ -> Error.make ~ctx "all" json

and path_of ~ctx expr json =
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
        let selected_values = collect ~ctx left value in
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
  let path_jsons : Json.t list =
    List.map
      (fun path ->
        `List
          (List.map
             (function `String s -> `String s | `Int i -> `Int i | _ -> `Null)
             path))
      paths
  in
  yield_many path_jsons

and reduce ~ctx generator var_name init_expr update_expr json =
  let init_values = collect ~ctx init_expr json in
  match init_values with
  | [ init_val ] ->
      let acc = ref init_val in
      run
        (fun () -> interp ~ctx generator json)
        ~and_then:(fun elem ->
          let env_with_var = (var_name, elem) :: ctx.env in
          let res =
            collect ~ctx:{ ctx with env = env_with_var } update_expr !acc
          in
          match res with
          | [ new_acc ] -> acc := new_acc
          | _ ->
              Error.message ~ctx
                "reduce update expression must return single value")
        ();
      yield !acc
  | _ -> Error.message ~ctx "reduce init expression must return a single value"

and foreach ~ctx generator var_name init_expr update_expr extract_expr json =
  let init_values = collect ~ctx init_expr json in
  match init_values with
  | [ init_val ] ->
      let acc = ref init_val in
      run
        (fun () -> interp ~ctx generator json)
        ~and_then:(fun elem ->
          let new_ctx = { ctx with env = (var_name, elem) :: ctx.env } in
          let update_res = collect ~ctx:new_ctx update_expr !acc in
          (match update_res with
          | [ new_acc ] -> acc := new_acc
          | _ ->
              Error.message ~ctx
                "foreach update expression must return single value");
          let extract_res = collect ~ctx:new_ctx extract_expr !acc in
          List.iter yield extract_res)
        ()
  | _ -> Error.message ~ctx "foreach init expression must return a single value"

and in_ ~ctx json expr =
  let container_results = collect ~ctx expr json in
  match container_results with
  | [ container ] -> (
      match (json, container) with
      | `Int n, `List l -> yield (`Bool (n >= 0 && n < List.length l))
      | `String key, `Assoc list -> yield (`Bool (List.mem_assoc key list))
      | _ -> Error.make ~ctx "in" json)
  | _ -> Error.message ~ctx "in expects single container"

and starts_with ~ctx ~is_deprecated expr json =
  let name = if is_deprecated then "startwith/startswith" else "starts_with" in
  if is_deprecated then
    emit_warning ~verbose:ctx.verbose
      "Using deprecated 'startwith' or 'startswith'. Use 'starts_with' \
       instead. This may not be supported in future versions.";
  let patterns = collect ~ctx expr json in
  List.iter
    (fun pattern ->
      match (json, pattern) with
      | `String s, `String prefix ->
          yield (`Bool (String.starts_with ~prefix s))
      | _ -> Error.make ~ctx name json)
    patterns

and ends_with ~ctx ~is_deprecated expr json =
  let name = if is_deprecated then "endwith/endswith" else "ends_with" in
  if is_deprecated then
    emit_warning ~verbose:ctx.verbose
      "Using deprecated 'endwith' or 'endswith'. Use 'ends_with' instead. This \
       may not be supported in future versions.";
  let patterns = collect ~ctx expr json in
  List.iter
    (fun pattern ->
      match (json, pattern) with
      | `String s, `String suffix -> yield (`Bool (String.ends_with ~suffix s))
      | _ -> Error.make ~ctx name json)
    patterns

and with_entries ~ctx expr json =
  let update_entry_field key transform_expr fields entry =
    match List.assoc_opt key fields with
    | Some value -> (
        match collect ~ctx transform_expr value with
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
            match collect ~ctx expr entry with [ res ] -> res | _ -> entry))
    | _ -> entry
  in
  match to_entries ~ctx json with
  | `List entries ->
      let transformed =
        List.map (fun entry -> transform_single_entry expr entry) entries
      in
      yield (from_entries ~ctx (`List transformed))
  | _ -> Error.make ~ctx "to_entries failed" json

and alternative ~ctx left right json =
  run
    (fun () ->
      let left_results = collect ~ctx left json in
      let is_valid value =
        match value with `Null | `Bool false -> false | _ -> true
      in
      let valid_results = List.filter is_valid left_results in
      match valid_results with
      | [] -> interp ~ctx right json
      | _ -> yield_many valid_results)
    ~on_fail:(fun _ -> interp ~ctx right json)
    ()

and contains ~ctx expr json =
  let needles = collect ~ctx expr json in
  match needles with
  | [ needle ] -> (
      match (json, needle) with
      | `String s, `String sub -> (
          try
            let _ = Str.search_forward (Str.regexp_string sub) s 0 in
            yield (`Bool true)
          with Not_found -> yield (`Bool false))
      | `List haystack, `List needles_list ->
          yield
            (`Bool
               (List.for_all
                  (fun n -> List.exists (Json.equal n) haystack)
                  needles_list))
      | _ -> Error.make ~ctx "contains" json)
  | _ -> Error.message ~ctx "contains expects single value"

and index_of ~ctx expr json =
  let needles = collect ~ctx expr json in
  List.iter
    (fun needle ->
      match (json, needle) with
      | `String haystack, `String needle -> (
          try
            let pos =
              Str.search_forward (Str.regexp_string needle) haystack 0
            in
            yield (`Int pos)
          with Not_found -> yield `Null)
      | _ -> Error.make ~ctx "index" json)
    needles

and rindex_of ~ctx expr json =
  let needles = collect ~ctx expr json in
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
          | Some pos -> yield (`Int pos)
          | None -> yield `Null)
      | _ -> Error.make ~ctx "rindex" json)
    needles

and group_by ~ctx expr json =
  match json with
  | `List l ->
      let estimated_groups = Int.max 16 (List.length l / 4) in
      let groups = Hashtbl.create estimated_groups in
      List.iter
        (fun item ->
          let keys = collect ~ctx expr item in
          match keys with
          | [ key ] ->
              let key_str =
                Json.to_string ~colorize:false ~summarize:false ~raw:false key
              in
              let existing =
                match Hashtbl.find_opt groups key_str with
                | Some items -> items
                | None -> []
              in
              Hashtbl.replace groups key_str (item :: existing)
          | _ -> ())
        l;
      let result =
        Hashtbl.fold (fun _ items acc -> List.rev items :: acc) groups []
      in
      yield (`List (List.map (fun items -> `List items) result))
  | _ -> Error.make ~ctx "group_by" json

and while_loop ~ctx cond update json =
  let rec loop acc current =
    let cond_res = collect ~ctx cond current in
    match cond_res with
    | [ `Bool true ] -> (
        let next_res = collect ~ctx update current in
        match next_res with
        | [ next ] -> loop (current :: acc) next
        | _ -> List.rev acc)
    | [ `Bool false ] -> List.rev acc
    | _ -> List.rev acc
  in
  yield_many (loop [] json)

and until_loop ~ctx cond update json =
  let rec loop acc current =
    let acc_with_current = current :: acc in
    let cond_res = collect ~ctx cond current in
    match cond_res with
    | [ `Bool true ] -> List.rev acc_with_current
    | [ `Bool false ] -> (
        let next_res = collect ~ctx update current in
        match next_res with
        | [ next ] -> loop acc_with_current next
        | _ -> List.rev acc_with_current)
    | _ -> List.rev acc_with_current
  in
  yield_many (loop [] json)

and recurse ~ctx json =
  let rec loop acc current =
    try
      let children = collect ~ctx (Key "children") current in
      match children with
      | [] -> current :: acc
      | list ->
          let new_acc = current :: acc in
          List.fold_left (fun a child -> loop a child) new_acc list
    with _ -> current :: acc
  in
  loop [] json

and recurse_with_cond ~ctx f cond json =
  let rec loop acc current =
    let cond_res = collect ~ctx cond current in
    match cond_res with
    | [ `Bool true ] -> (
        let acc_with_current = current :: acc in
        let next_res = collect ~ctx f current in
        match next_res with
        | [ next ] -> loop acc_with_current next
        | _ -> List.rev acc_with_current)
    | [ `Bool false ] -> List.rev acc
    | _ -> List.rev acc
  in
  loop [] json

and walk_tree ~ctx expr json =
  let rec walk json =
    let walked_json =
      match json with
      | `List l -> `List (List.map walk l)
      | `Assoc obj -> `Assoc (List.map (fun (k, v) -> (k, walk v)) obj)
      | other -> other
    in
    match collect ~ctx expr walked_json with
    | [ result ] -> result
    | _ -> walked_json
  in
  yield (walk json)

and try_catch ~ctx expr handler json =
  run
    (fun () -> interp ~ctx expr json)
    ~on_fail:(fun _ ->
      match handler with None -> () | Some handler -> interp ~ctx handler json)
    ()

and limit ~ctx n expr json =
  let count = ref 0 in
  run_while
    (fun () -> interp ~ctx expr json)
    ~when_:(fun result ->
      if !count < n then (
        incr count;
        yield result;
        true)
      else false)

and error_msg ~ctx msg_expr json =
  match msg_expr with
  | None -> Error.message ~ctx "error"
  | Some expr -> (
      let results = collect ~ctx expr json in
      match results with
      | [ `String msg ] -> Error.message ~ctx msg
      | [ other ] ->
          Error.message ~ctx
            (Json.to_string ~colorize:false ~summarize:false ~raw:false other)
      | _ -> Error.message ~ctx "error expects single string")

and isempty ~ctx expr json =
  let results = collect ~ctx expr json in
  match results with [] -> yield (`Bool true) | _ -> yield (`Bool false)

and del ~ctx:_ path json =
  match (path, json) with
  | Key key, `Assoc fields ->
      let filtered = List.filter (fun (k, _) -> k <> key) fields in
      yield (`Assoc filtered)
  | Pipe (Identity, Index indices), `List items when indices <> [] ->
      let filtered = List.filteri (fun i _ -> not (List.mem i indices)) items in
      yield (`List filtered)
  | Index indices, `List items when indices <> [] ->
      let filtered = List.filteri (fun i _ -> not (List.mem i indices)) items in
      yield (`List filtered)
  | _ -> yield json

and getpath ~ctx path json =
  let paths = collect ~ctx path json in
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
      yield (navigate json path_components)
  | _ -> Error.message ~ctx "getpath expects array path"

and setpath ~ctx path value_expr json =
  let paths = collect ~ctx path json in
  let values = collect ~ctx value_expr json in
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
      yield (set_at json path_components)
  | _ -> Error.message ~ctx "setpath expects (path_array, value)"

and paths json = yield_many (List.map (fun p -> `List p) (all_paths_list json))

and paths_filter ~ctx filter_expr json =
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
      let results = collect ~ctx filter_expr value in
      let is_truthy = function `Bool false | `Null -> false | _ -> true in
      if List.exists is_truthy results then
        yield
          (`List
             (List.map
                (function
                  | `String s -> `String s | `Int i -> `Int i | _ -> `Null)
                path_components)))
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

and assign ~ctx path value_expr json =
  (* Assignment is like setpath but path is an AST expression, not a value *)
  (* For simple cases like .foo = 42, we can extract the path from AST *)
  match path with
  | Key key -> (
      let values = collect ~ctx value_expr json in
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
              if exists then yield (`Assoc updated)
              else yield (`Assoc (fields @ [ (key, new_value) ]))
          | `Null -> yield (`Assoc [ (key, new_value) ])
          | _ -> Error.make ~ctx "assignment" json)
      | _ -> Error.message ~ctx "assignment value must be single")
  | _ -> Error.message ~ctx "complex path assignment not yet fully implemented"

let execute ~colorize ~verbose ?(env = []) expr json =
  let ctx = { colorize; verbose; env } in
  let open Ansi.To_string (struct
    let colorize = colorize
  end) in
  let handler : ('a, ('a, string) result) Effect.Deep.handler =
    {
      retc = (fun results -> Ok results);
      exnc = (fun e -> Error (Printexc.to_string e));
      effc =
        (fun (type a) (eff : a Effect.t) ->
          match eff with
          | Fail msg -> Some (fun _ -> Error msg)
          | Break ->
              Some
                (fun (_ : (a, _) continuation) ->
                  Error (red "Error: " ^ "break used outside of loop context"))
          | Halt exit_code -> Some (fun _ -> exit exit_code)
          | _ -> None);
    }
  in
  Effect.Deep.match_with (fun () -> collect ~ctx expr json) () handler
