open Ast

type _ Effect.t += Yield : Json.t -> unit Effect.t
type _ Effect.t += Break : unit Effect.t
type _ Effect.t += Halt : int -> unit Effect.t
type _ Effect.t += Fail : string -> unit Effect.t
type _ Effect.t += User_error : Json.t -> unit Effect.t
type fn_definition = { params : string list; body : expression }

type ctx = {
  colorize : bool;
  verbose : bool;
  env : (string * Json.t) list;
  fns : (string * fn_definition) list;
}

let yield v = Effect.perform (Yield v)
let break () = Effect.perform Break
let halt ?(code = 0) () = Effect.perform (Halt code)

let fail msg =
  Effect.perform (Fail msg);
  assert false (* unreachable - handler never continues *)

let user_error value =
  Effect.perform (User_error value);
  assert false (* unreachable - handler never continues *)

let yield_many items = List.iter yield items

let rec get_path value components =
  match components with
  | [] -> value
  | `String key :: rest -> (
      match value with
      | `Assoc fields -> (
          match List.assoc_opt key fields with
          | Some v -> get_path v rest
          | None -> `Null)
      | _ -> `Null)
  | `Int idx :: rest -> (
      match value with
      | `List items ->
          if idx >= 0 && idx < List.length items then
            get_path (List.nth items idx) rest
          else `Null
      | _ -> `Null)
  | _ :: rest -> get_path value rest

let rec set_path value path_components new_value =
  match path_components with
  | [] -> new_value
  | `String key :: rest -> (
      match value with
      | `Assoc fields ->
          let updated =
            List.map
              (fun (k, v) ->
                if k = key then (k, set_path v rest new_value) else (k, v))
              fields
          in
          let exists = List.mem_assoc key fields in
          if exists then `Assoc updated
          else `Assoc (fields @ [ (key, set_path `Null rest new_value) ])
      | `Null -> `Assoc [ (key, set_path `Null rest new_value) ]
      | _ -> value)
  | ((`Int _ | `Float _) as num) :: rest -> (
      let idx =
        match num with `Int i -> i | `Float f -> Float.to_int f | _ -> 0
      in
      match value with
      | `List items ->
          let rec update_list i = function
            | [] -> if i = idx then [ set_path `Null rest new_value ] else []
            | x :: xs ->
                if i = idx then set_path x rest new_value :: xs
                else x :: update_list (i + 1) xs
          in
          `List (update_list 0 items)
      | `Null ->
          let arr =
            List.init (idx + 1) (fun i ->
                if i = idx then set_path `Null rest new_value else `Null)
          in
          `List arr
      | _ -> value)
  | _ :: rest -> set_path value rest new_value

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
                    (fun (k : (a, _) Effect.Deep.continuation) ->
                      f json;
                      Effect.Deep.continue k ())
              | None -> None)
          | Fail msg -> (
              match on_fail with
              | Some f -> Some (fun (_ : (a, _) Effect.Deep.continuation) -> f msg)
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
                (fun (k : (a, _) Effect.Deep.continuation) ->
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
                (fun (k : (a, _) Effect.Deep.continuation) ->
                  v :: Effect.Deep.continue k ())
          | _ -> None);
    }
  in
  Effect.Deep.match_with fn () handler

let rec substitute_params (params : string list) (args : expression list)
    (expr : expression) : expression =
  let sub = substitute_params params args in
  let sub_opt = Option.map sub in
  let find_param name =
    let rec find idx = function
      | [] -> None
      | p :: _ when p = name -> Some (List.nth args idx)
      | _ :: rest -> find (idx + 1) rest
    in
    find 0 params
  in
  match expr with
  (* nullary calls to a parameter name gets substituted with the argument expression *)
  | Apply (name, []) -> (
      match find_param name with Some arg_expr -> arg_expr | None -> expr)
  (* all other expressions substitute in sub-expressions *)
  | Identity | Empty | Keys | Keys_unsorted | Leaf_paths | Builtins | Formats
  | Localtime | Gmtime | Mktime | Debug | Stderr | Floor | Sqrt | Type | Sort
  | Unique | Reverse | Explode | Implode | Any | All | Recurse | Recurse_down
  | To_entries | From_entries | Nan | Is_nan | Not | Ascii_upcase
  | Ascii_downcase | Trim | Ltrim | Rtrim | Head | Tail | Length
  | Utf8bytelength | Min | Max | To_number | Tonumber | To_string | Tostring
  | Env | Break | Paths | Halt | Iterator | Combinations | Fun _ | Literal _
  | Variable _ | Key _ | Test _ | Match _ | Scan _ | Capture _ | Env_var _ ->
      expr
  | Index indices -> Index indices
  | Dynamic_access e -> Dynamic_access (sub e)
  | Slice (a, b) -> Slice (a, b)
  | Slice_expr (a, b) -> Slice_expr (Option.map sub a, Option.map sub b)
  | Sub (a, b) -> Sub (a, b)
  | Gsub (a, b) -> Gsub (a, b)
  | Limit (n, e) -> Limit (n, sub e)
  | Skip (n, e) -> Skip (n, sub e)
  | Halt_error n -> Halt_error n
  | Pipe (l, r) -> Pipe (sub l, sub r)
  | Update (l, r) -> Update (sub l, sub r)
  | Alternative (l, r) -> Alternative (sub l, sub r)
  | Comma (l, r) -> Comma (sub l, sub r)
  | Operation (l, op, r) -> Operation (sub l, op, sub r)
  | Optional e -> Optional (sub e)
  | List e -> List (sub_opt e)
  | Object pairs -> Object (List.map (fun (k, v) -> (sub k, sub_opt v)) pairs)
  | Walk e -> Walk (sub e)
  | Transpose e -> Transpose (sub e)
  | Has e -> Has (sub e)
  | In e -> In (sub e)
  | Recurse_expr e -> Recurse_expr (sub e)
  | Recurse_with (e1, e2) -> Recurse_with (sub e1, sub e2)
  | With_entries e -> With_entries (sub e)
  | Range (e1, e2, e3) -> Range (sub e1, sub_opt e2, sub_opt e3)
  | Flatten e -> Flatten (sub_opt e)
  | Map e -> Map (sub e)
  | Map_values e -> Map_values (sub e)
  | Flat_map e -> Flat_map (sub e)
  | Reduce (e, var, init, update) -> Reduce (sub e, var, sub init, sub update)
  | As (e, var, body) -> As (sub e, var, sub body)
  | Select e -> Select (sub e)
  | Sort_by e -> Sort_by (sub e)
  | Group_by e -> Group_by (sub e)
  | Unique_by e -> Unique_by (sub e)
  | Min_by e -> Min_by (sub e)
  | Max_by e -> Max_by (sub e)
  | All_with_condition e -> All_with_condition (sub e)
  | Any_with_condition e -> Any_with_condition (sub e)
  | Any_with_generator (g, c) -> Any_with_generator (sub g, sub c)
  | All_with_generator (g, c) -> All_with_generator (sub g, sub c)
  | Some_ e -> Some_ (sub e)
  | Find e -> Find (sub e)
  | Contains e -> Contains (sub e)
  | Starts_with e -> Starts_with (sub e)
  | Startwith e -> Startwith (sub e)
  | Ends_with e -> Ends_with (sub e)
  | Endwith e -> Endwith (sub e)
  | Index_of e -> Index_of (sub e)
  | Rindex_of e -> Rindex_of (sub e)
  | Indices e -> Indices (sub e)
  | Inside e -> Inside (sub e)
  | Ltrimstr e -> Ltrimstr (sub e)
  | Rtrimstr e -> Rtrimstr (sub e)
  | Split e -> Split (sub e)
  | Join e -> Join (sub e)
  | Bsearch e -> Bsearch (sub e)
  | Combinations_n e -> Combinations_n (sub e)
  | Repeat e -> Repeat (sub e)
  | Add_expr e -> Add_expr (sub e)
  | First e -> First (sub_opt e)
  | Last e -> Last (sub_opt e)
  | Nth (e1, e2) -> Nth (sub e1, sub e2)
  | Path e -> Path (sub e)
  | If_then_else (c, t, e) -> If_then_else (sub c, sub t, sub e)
  | While (c, u) -> While (sub c, sub u)
  | Until (c, u) -> Until (sub c, sub u)
  | Atan2 (e1, e2) -> Atan2 (sub e1, sub e2)
  | Copysign (e1, e2) -> Copysign (sub e1, sub e2)
  | Ldexp (e1, e2) -> Ldexp (sub e1, sub e2)
  | Fdim (e1, e2) -> Fdim (sub e1, sub e2)
  | Remainder (e1, e2) -> Remainder (sub e1, sub e2)
  | Scalbn (e1, e2) -> Scalbn (sub e1, sub e2)
  | Pow2 (e1, e2) -> Pow2 (sub e1, sub e2)
  | Fma (e1, e2, e3) -> Fma (sub e1, sub e2, sub e3)
  | Try (e, h) -> Try (sub e, sub_opt h)
  | Error_msg e -> Error_msg (sub_opt e)
  | Isempty e -> Isempty (sub e)
  | Foreach (e, var, init, update, extract) ->
      Foreach (sub e, var, sub init, sub update, sub extract)
  | Label (name, e) -> Label (name, sub e)
  | Del e -> Del (sub e)
  | Delpaths e -> Delpaths (sub e)
  | Pick e -> Pick (sub e)
  | Assign (l, r) -> Assign (sub l, sub r)
  | Getpath e -> Getpath (sub e)
  | Setpath (e1, e2) -> Setpath (sub e1, sub e2)
  | Paths_filter e -> Paths_filter (sub e)
  | Def (name, params', body) -> Def (name, params', sub body)
  | Apply (name, call_args) -> Apply (name, List.map sub call_args)

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
end

module Operators = struct
  let not (json : Json.t) =
    match json with `Bool false | `Null -> `Bool true | _ -> `Bool false

  let add ~ctx str (left : Json.t) (right : Json.t) : Json.t =
    match (left, right) with
    | `Float l, `Float r -> `Float (l +. r)
    | `Int l, `Float r -> `Float (Int.to_float l +. r)
    | `Float l, `Int r -> `Float (l +. Int.to_float r)
    | `Int l, `Int r -> `Float (Int.to_float l +. Int.to_float r)
    | `Null, `Int r | `Int r, `Null -> `Float (Int.to_float r)
    | `Null, `Float r | `Float r, `Null -> `Float r
    | `String l, `String r -> `String (l ^ r)
    | `Null, `String r | `String r, `Null -> `String r
    | `Assoc l_entries, `Assoc r_entries ->
        (* right side wins for duplicate keys (override, not merge) *)
        let updated_l =
          List.map
            (fun (k, v) ->
              match List.assoc_opt k r_entries with
              | Some v' -> (k, v')
              | None -> (k, v))
            l_entries
        in
        (* Then add new keys from r that weren't in l *)
        let new_keys =
          List.filter
            (fun (k, _) -> Stdlib.not (List.mem_assoc k l_entries))
            r_entries
        in
        `Assoc (updated_l @ new_keys)
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

  let gt ~ctx = compare ~ctx ">" ( > )
  let gte ~ctx = compare ~ctx ">=" ( >= )
  let lt ~ctx = compare ~ctx "<" ( < )
  let lte ~ctx = compare ~ctx "<=" ( <= )

  let is_truthy (json : Json.t) : bool =
    (* in jq, false and null are falsy, everything else is truthy *)
    match json with
    | `Bool false | `Null -> false
    | _ -> true

  let and_ ~ctx:_ (left : Json.t) (right : Json.t) : Json.t =
    `Bool (is_truthy left && is_truthy right)

  let or_ ~ctx:_ (left : Json.t) (right : Json.t) : Json.t =
    `Bool (is_truthy left || is_truthy right)

  let equal l r = `Bool (Json.equal l r)
  let not_equal l r = `Bool (Stdlib.not (Json.equal l r))
  let add ~ctx = add ~ctx "+"

  let subtract ~ctx (left : Json.t) (right : Json.t) : Json.t =
    match (left, right) with
    | `Float l, `Float r -> `Float (l -. r)
    | `Int l, `Float r -> `Float (Int.to_float l -. r)
    | `Float l, `Int r -> `Float (l -. Int.to_float r)
    | `Int l, `Int r -> `Float (Int.to_float l -. Int.to_float r)
    | `List l, `List r ->
        let in_r x = List.exists (fun y -> Json.equal x y) r in
        `List (List.filter (fun x -> Stdlib.not (in_r x)) l)
    | _ -> Error.make ~ctx "-" left

  let rec deep_merge (left : Json.t) (right : Json.t) : Json.t =
    match (left, right) with
    | `Assoc l_entries, `Assoc r_entries ->
        (* Preserve key order: update existing keys from l with recursive merge from r *)
        let updated_l =
          List.map
            (fun (k, v) ->
              match List.assoc_opt k r_entries with
              | Some r_val -> (k, deep_merge v r_val)
              | None -> (k, v))
            l_entries
        in
        (* Add new keys from r that weren't in l *)
        let new_keys =
          List.filter
            (fun (k, _) -> Stdlib.not (List.mem_assoc k l_entries))
            r_entries
        in
        `Assoc (updated_l @ new_keys)
    | _, r -> r

  let multiply ~ctx (left : Json.t) (right : Json.t) : Json.t =
    match (left, right) with
    | `Float l, `Float r -> `Float (l *. r)
    | `Int l, `Float r -> `Float (Int.to_float l *. r)
    | `Float l, `Int r -> `Float (l *. Int.to_float r)
    | `Int l, `Int r -> `Float (Int.to_float l *. Int.to_float r)
    | `String s, `Int n ->
        if n <= 0 then `String ""
        else `String (String.concat "" (List.init n (fun _ -> s)))
    | `String s, `Float f ->
        let count = Int.of_float f in
        if count <= 0 then `String ""
        else `String (String.concat "" (List.init count (fun _ -> s)))
    | `Assoc _, `Assoc _ -> deep_merge left right
    | `Null, r | r, `Null -> r
    | _ -> Error.make ~ctx "*" left

  let divide ~ctx (left : Json.t) (right : Json.t) : Json.t =
    match (left, right) with
    | `Float l, `Float r -> `Float (l /. r)
    | `Int l, `Float r -> `Float (Int.to_float l /. r)
    | `Float l, `Int r -> `Float (l /. Int.to_float r)
    | `Int l, `Int r -> `Float (Int.to_float l /. Int.to_float r)
    | `String s, `String delim ->
        `List
          (Str.split_delim (Str.regexp_string delim) s
          |> List.map (fun part -> `String part))
    | _ -> Error.make ~ctx "/" left

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
  let sinh_ ~ctx = apply_to_number ~ctx "sinh" Stdlib.sinh
  let cosh_ ~ctx = apply_to_number ~ctx "cosh" Stdlib.cosh
  let tanh_ ~ctx = apply_to_number ~ctx "tanh" Stdlib.tanh
  let asinh_ ~ctx = apply_to_number ~ctx "asinh" Float.asinh
  let acosh_ ~ctx = apply_to_number ~ctx "acosh" Float.acosh
  let atanh_ ~ctx = apply_to_number ~ctx "atanh" Float.atanh
  let trunc_ ~ctx = apply_to_number ~ctx "trunc" Float.trunc
  let cbrt_ ~ctx = apply_to_number ~ctx "cbrt" Float.cbrt
  let expm1_ ~ctx = apply_to_number ~ctx "expm1" Float.expm1
  let exp2_ ~ctx = apply_to_number ~ctx "exp2" Float.exp2
  let log1p_ ~ctx = apply_to_number ~ctx "log1p" Float.log1p
  let log2_ ~ctx = apply_to_number ~ctx "log2" Float.log2

  let isinfinite ~ctx json =
    match json with
    | `Float x -> `Bool (Float.is_infinite x)
    | `Int _ -> `Bool false
    | _ -> Error.make ~ctx "isinfinite" json

  let isnormal ~ctx json =
    match json with
    | `Float x ->
        let is_normal =
          Float.is_finite x && x <> 0.0 && Float.abs x >= Float.min_float
        in
        `Bool is_normal
    | `Int n -> `Bool (n <> 0)
    | _ -> Error.make ~ctx "isnormal" json

  let fabs ~ctx json =
    match json with
    | `Float x -> `Float (Float.abs x)
    | `Int n -> `Float (Float.abs (Float.of_int n))
    | _ -> Error.make ~ctx "fabs" json

  let nearbyint ~ctx json =
    match json with
    | `Float x -> `Float (Float.round x)
    | `Int n -> `Int n
    | _ -> Error.make ~ctx "nearbyint" json

  let logb ~ctx json =
    match json with
    | `Float x -> `Float (Float.floor (Float.log2 (Float.abs x)))
    | `Int n -> `Float (Float.floor (Float.log2 (Float.abs (Float.of_int n))))
    | _ -> Error.make ~ctx "logb" json
end

module Search = struct
  let string_first haystack needle =
    try Some (Str.search_forward (Str.regexp_string needle) haystack 0)
    with Not_found -> None

  let string_last haystack needle =
    let rec search pos last =
      try
        let found =
          Str.search_forward (Str.regexp_string needle) haystack pos
        in
        search (found + 1) (Some found)
      with Not_found -> last
    in
    search 0 None

  let string_all haystack needle =
    let rec search pos acc =
      try
        let found =
          Str.search_forward (Str.regexp_string needle) haystack pos
        in
        search (found + 1) (found :: acc)
      with Not_found -> List.rev acc
    in
    search 0 []

  let sublist_matches_at haystack sublist idx =
    let sublen = List.length sublist in
    let haylen = List.length haystack in
    if idx + sublen > haylen then false
    else
      let slice =
        List.filteri (fun i _ -> i >= idx && i < idx + sublen) haystack
      in
      List.length slice = sublen && List.for_all2 Json.equal slice sublist

  let sublist_first haystack sublist =
    let sublen = List.length sublist in
    let haylen = List.length haystack in
    let rec search idx =
      if idx + sublen > haylen then None
      else if sublist_matches_at haystack sublist idx then Some idx
      else search (idx + 1)
    in
    search 0

  let sublist_last haystack sublist =
    let sublen = List.length sublist in
    let haylen = List.length haystack in
    let rec search idx last =
      if idx + sublen > haylen then last
      else if sublist_matches_at haystack sublist idx then
        search (idx + 1) (Some idx)
      else search (idx + 1) last
    in
    search 0 None

  let sublist_all haystack sublist =
    let sublen = List.length sublist in
    let haylen = List.length haystack in
    let rec search idx acc =
      if idx + sublen > haylen then List.rev acc
      else if sublist_matches_at haystack sublist idx then
        search (idx + 1) (idx :: acc)
      else search (idx + 1) acc
    in
    search 0 []

  let element_first haystack needle =
    let rec search idx = function
      | [] -> None
      | hd :: tl ->
          if Json.equal hd needle then Some idx else search (idx + 1) tl
    in
    search 0 haystack

  let element_last haystack needle =
    let rec search idx last = function
      | [] -> last
      | hd :: tl ->
          let last = if Json.equal hd needle then Some idx else last in
          search (idx + 1) last tl
    in
    search 0 None haystack

  let element_all haystack needle =
    let rec search idx acc = function
      | [] -> List.rev acc
      | hd :: tl ->
          let acc = if Json.equal hd needle then idx :: acc else acc in
          search (idx + 1) acc tl
    in
    search 0 [] haystack
end

let keys ~ctx (json : Json.t) =
  match json with
  | `Assoc _list ->
      let sorted_keys = Json.keys json |> List.sort String.compare in
      `List (sorted_keys |> List.map (fun i -> `String i))
  | `List l ->
      (* return indices 0..length-1 *)
      let len = List.length l in
      `List (List.init len (fun i -> `Int i))
  | _ -> Error.make ~ctx "keys" json

let keys_unsorted ~ctx (json : Json.t) =
  match json with
  | `Assoc list -> `List (List.map (fun (k, _) -> `String k) list)
  | `List l ->
      let len = List.length l in
      `List (List.init len (fun i -> `Int i))
  | _ -> Error.make ~ctx "keys_unsorted" json

let builtins_list () =
  `List
    (List.map
       (fun s -> `String s)
       [
         "add";
         "abs";
         "acos";
         "acosh";
         "all";
         "any";
         "ascii";
         "ascii_downcase";
         "ascii_upcase";
         "asin";
         "asinh";
         "atan";
         "atan2";
         "atanh";
         "bsearch";
         "builtins";
         "cbrt";
         "ceil";
         "combinations";
         "contains";
         "copysign";
         "cos";
         "cosh";
         "del";
         "delpaths";
         "empty";
         "endswith";
         "env";
         "error";
         "exp";
         "exp2";
         "expm1";
         "explode";
         "fabs";
         "fdim";
         "first";
         "flatten";
         "floor";
         "fma";
         "foreach";
         "format";
         "from_entries";
         "getpath";
         "group_by";
         "gsub";
         "halt";
         "halt_error";
         "has";
         "head";
         "if";
         "implode";
         "in";
         "index";
         "indices";
         "infinite";
         "inside";
         "isempty";
         "isinfinite";
         "isnan";
         "isnormal";
         "join";
         "keys";
         "keys_unsorted";
         "last";
         "ldexp";
         "leaf_paths";
         "length";
         "limit";
         "log";
         "log10";
         "log1p";
         "log2";
         "logb";
         "ltrimstr";
         "map";
         "map_values";
         "match";
         "max";
         "max_by";
         "min";
         "min_by";
         "nan";
         "nearbyint";
         "not";
         "now";
         "nth";
         "null";
         "objects";
         "path";
         "paths";
         "pow";
         "range";
         "recurse";
         "recurse_down";
         "reduce";
         "remainder";
         "repeat";
         "reverse";
         "rindex";
         "rint";
         "round";
         "rtrimstr";
         "scalbn";
         "scan";
         "select";
         "setpath";
         "sin";
         "sinh";
         "sort";
         "sort_by";
         "split";
         "sqrt";
         "startswith";
         "sub";
         "tail";
         "tan";
         "tanh";
         "test";
         "to_entries";
         "to_number";
         "to_string";
         "tonumber";
         "tostring";
         "transpose";
         "trim";
         "trunc";
         "type";
         "unique";
         "unique_by";
         "until";
         "utf8bytelength";
         "values";
         "walk";
         "while";
         "with_entries";
       ])

let formats_list () =
  `List
    (List.map
       (fun s -> `String s)
       [
         "text"; "json"; "html"; "uri"; "csv"; "tsv"; "sh"; "base64"; "base64d";
       ])

let tm_to_array (tm : Unix.tm) (is_dst : bool) : Json.t =
  `List
    [
      `Int tm.tm_sec;
      `Int tm.tm_min;
      `Int tm.tm_hour;
      `Int tm.tm_mday;
      `Int tm.tm_mon;
      `Int tm.tm_year;
      `Int tm.tm_wday;
      `Int tm.tm_yday;
      `Int (if is_dst then 1 else 0);
    ]

let localtime_fn ~ctx json =
  match json with
  | `Float f ->
      let tm = Unix.localtime f in
      tm_to_array tm tm.tm_isdst
  | `Int n ->
      let tm = Unix.localtime (Float.of_int n) in
      tm_to_array tm tm.tm_isdst
  | _ -> Error.make ~ctx "localtime" json

let gmtime_fn ~ctx json =
  match json with
  | `Float f ->
      let tm = Unix.gmtime f in
      tm_to_array tm false
  | `Int n ->
      let tm = Unix.gmtime (Float.of_int n) in
      tm_to_array tm false
  | _ -> Error.make ~ctx "gmtime" json

let mktime_fn ~ctx json =
  match json with
  | `List
      [
        `Int sec;
        `Int min;
        `Int hour;
        `Int mday;
        `Int mon;
        `Int year;
        _;
        _;
        `Int isdst;
      ] ->
      let tm =
        {
          Unix.tm_sec = sec;
          tm_min = min;
          tm_hour = hour;
          tm_mday = mday;
          tm_mon = mon;
          tm_year = year;
          tm_wday = 0;
          tm_yday = 0;
          tm_isdst = isdst = 1;
        }
      in
      let time, _ = Unix.mktime tm in
      `Float time
  | `List _ ->
      Error.message ~ctx
        "mktime expects array of 9 integers [sec, min, hour, mday, mon, year, \
         wday, yday, isdst]"
  | _ -> Error.make ~ctx "mktime" json

let debug_fn json =
  let str = Json.to_string ~colorize:false ~summarize:false ~raw:false json in
  Printf.eprintf "[\"DEBUG:\", %s]\n%!" str;
  yield json

let stderr_fn json =
  match json with
  | `String s ->
      Printf.eprintf "%s\n%!" s;
      yield json
  | _ ->
      let str =
        Json.to_string ~colorize:false ~summarize:false ~raw:false json
      in
      Printf.eprintf "%s\n%!" str;
      yield json

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

let range_list ?(step = 1) start stop =
  if step = 0 then []
  else
    let rec loop current =
      if (step > 0 && current >= stop) || (step < 0 && current <= stop) then []
      else current :: loop (current + step)
    in
    loop start

let range ?step from upto =
  match upto with
  | None -> range_list 0 from
  | Some stop -> range_list ?step from stop

let split ~ctx expr json =
  match json with
  | `String s ->
      let delim =
        match expr with
        | Literal (String s) -> s
        | _ ->
            Error.message ~ctx
              "Invalid argument for 'split': expected string literal"
      in
      (* Use split_delim to preserve trailing empty strings, then filter leading empty if not at boundary *)
      let parts = Str.split_delim (Str.regexp_string delim) s in
      `List (List.map (fun s -> `String s) parts)
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
      let to_str = function
        | `String s -> Some s
        | `Null -> None
        | `Bool b -> Some (Bool.to_string b)
        | `Int n -> Some (Int.to_string n)
        | `Float f -> Some (Printf.sprintf "%g" f)
        | other ->
            Some
              (Json.to_string ~colorize:false ~summarize:false ~raw:true other)
      in
      `String (List.filter_map to_str l |> String.concat rcase)
  | _ -> Error.make ~ctx "join" json

let length ~ctx (json : Json.t) =
  match json with
  | `List list -> `Int (List.length list)
  (* TODO: OCaml strings are byte arrays, so this often incorrect *)
  | `String s -> `Int (String.length s)
  | `Assoc obj -> `Int (List.length obj)
  | `Null -> `Int 0
  | `Int n -> `Int (abs n)
  | `Float f -> `Float (Float.abs f)
  | _ -> Error.make ~ctx "length" json

let utf8bytelength ~ctx (json : Json.t) =
  match json with
  | `String s -> `Int (String.length s) (* OCaml strings are byte arrays *)
  | _ -> Error.make ~ctx "utf8bytelength" json

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
  match json with
  (* for strings, return as-is (no extra quotes) *)
  | `String s -> `String s
  | _ ->
      `String (Json.to_string ~colorize:false ~summarize:false ~raw:false json)

let min ~ctx (json : Json.t) =
  match json with
  | `List [] -> Error.empty_list ~ctx "min"
  | `List l ->
      List.fold_left
        (fun acc x -> if Json.compare x acc < 0 then x else acc)
        (List.hd l) (List.tl l)
  | _ -> Error.make ~ctx "min" json

let max ~ctx (json : Json.t) =
  match json with
  | `List [] -> Error.empty_list ~ctx "max"
  | `List l ->
      List.fold_left
        (fun acc x -> if Json.compare x acc > 0 then x else acc)
        (List.hd l) (List.tl l)
  | _ -> Error.make ~ctx "max" json

let flatten ~ctx depth (json : Json.t) =
  match json with
  | `List l ->
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
  | `List l -> `List (List.sort Json.compare l)
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
                (* jq accepts both "key"/"name" and "value"/"values" *)
                let key =
                  match List.assoc_opt "key" fields with
                  | Some k -> Some k
                  | None -> List.assoc_opt "name" fields
                in
                let value =
                  match List.assoc_opt "value" fields with
                  | Some v -> Some v
                  | None -> List.assoc_opt "values" fields
                in
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

let get_envs () =
  (* TODO: Do I need to escape stuff here? *)
  Unix.environment () |> Array.to_list
  |> List.filter_map (fun s ->
      match String.split_on_char '=' s with
      | k :: rest -> Some (k, `String (String.concat "=" rest))
      | [] -> None)

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
          List.map
            (fun row ->
              match row with
              | `List l when i < List.length l -> List.nth l i
              | _ -> `Null)
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

let member ~ctx:_ (key : string) (json : Json.t) =
  match json with
  | `Assoc _assoc -> Json.member key json
  | `Null -> `Null
  | _ ->
      fail ("Cannot index " ^ Json.type_of json ^ " with string \"" ^ key ^ "\"")

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
  | Keys_unsorted -> yield (keys_unsorted ~ctx json)
  | Leaf_paths -> leaf_paths json
  | Builtins -> yield (builtins_list ())
  | Formats -> yield (formats_list ())
  | Localtime -> yield (localtime_fn ~ctx json)
  | Gmtime -> yield (gmtime_fn ~ctx json)
  | Mktime -> yield (mktime_fn ~ctx json)
  | Debug -> debug_fn json
  | Stderr -> stderr_fn json
  | Key key -> yield (member ~ctx key json)
  | Optional expr ->
      run (fun () -> interp ~ctx expr json) ~on_fail:(fun _ -> ()) ()
  | Index idx -> index ~ctx idx json
  | Dynamic_access expr -> dynamic_access ~ctx expr json
  | Iterator -> iterator ~ctx json
  | Slice (start, finish) -> slice ~ctx start finish json
  | Slice_expr (start_expr, end_expr) ->
      slice_expr ~ctx start_expr end_expr json
  | Head -> yield (head ~ctx json)
  | Tail -> yield (tail ~ctx json)
  | Length -> yield (length ~ctx json)
  | Utf8bytelength -> yield (utf8bytelength ~ctx json)
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
  | Flatten None -> yield (flatten ~ctx max_int json)
  | Flatten (Some expr) ->
      collect ~ctx expr json
      |> List.iter (fun depth ->
          match depth with
          | `Int d -> yield (flatten ~ctx d json)
          | `Float f -> yield (flatten ~ctx (Int.of_float f) json)
          | _ -> Error.make ~ctx "flatten: depth must be a number" depth)
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
  | Map_values expr -> map_values ~ctx expr json
  | Operation (left, op, right) -> operation ~ctx left right op json
  | Literal literal -> (
      match literal with
      | Bool b -> yield (`Bool b)
      | Number f -> yield (`Float f)
      | String s -> yield (`String s)
      | Null -> yield `Null)
  | Pipe (left, right) -> pipe ~ctx left right json
  | Update (path_expr, transform) -> update ~ctx path_expr transform json
  | Alternative (left, right) -> alternative ~ctx left right json
  | Select conditional -> select ~ctx conditional json
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
  | Range (from_expr, upto_expr, step_expr) ->
      range_expr ~ctx from_expr upto_expr step_expr json
  | Reverse -> (
      match json with
      | `List l -> yield (`List (List.rev l))
      | _ -> Error.make ~ctx "reverse" json)
  | Split expr -> yield (split ~ctx expr json)
  | Join expr -> yield (join ~ctx expr json)
  | Fun builtin -> builtin_fns ~ctx builtin json
  | If_then_else (cond, if_branch, else_branch) ->
      if_then_else ~ctx cond if_branch else_branch json
  | Sort_by expr -> sort_by ~ctx expr json
  | Min_by expr -> min_by ~ctx expr json
  | Max_by expr -> max_by ~ctx expr json
  | Unique_by expr -> unique_by ~ctx expr json
  | Index_of expr -> index_of ~ctx expr json
  | Rindex_of expr -> rindex_of ~ctx expr json
  | Indices expr -> indices ~ctx expr json
  | Inside expr -> inside ~ctx expr json
  | Ltrimstr expr -> left_trimstr ~ctx expr json
  | Rtrimstr expr -> right_trimstr ~ctx expr json
  | Trim -> trim ~ctx json
  | Ltrim -> left_trim ~ctx json
  | Rtrim -> right_trim ~ctx json
  | Ascii_upcase -> ascii_upcase ~ctx json
  | Ascii_downcase -> ascii_downcase ~ctx json
  | Bsearch expr -> binary_search ~ctx expr json
  | First None -> first_of_array ~ctx json
  | First (Some expr) -> first_of_expr ~ctx expr json
  | Last None -> last_of_array ~ctx json
  | Last (Some expr) -> last_of_expr ~ctx expr json
  | Nth (n_expr, expr) -> nth ~ctx n_expr expr json
  | Group_by expr -> group_by ~ctx expr json
  | While (cond, update) -> while_loop ~ctx cond update json
  | Until (cond, update) -> until_loop ~ctx cond update json
  | Atan2 (y_expr, x_expr) -> atan2_op ~ctx y_expr x_expr json
  | Copysign (x_expr, y_expr) -> copysign_op ~ctx x_expr y_expr json
  | Ldexp (m_expr, e_expr) -> ldexp_op ~ctx m_expr e_expr json
  | Fdim (x_expr, y_expr) -> fdim_op ~ctx x_expr y_expr json
  | Remainder (x_expr, y_expr) -> remainder_op ~ctx x_expr y_expr json
  | Scalbn (x_expr, n_expr) -> scalbn_op ~ctx x_expr n_expr json
  | Pow2 (x_expr, y_expr) -> pow2_op ~ctx x_expr y_expr json
  | Fma (x_expr, y_expr, z_expr) -> fma_op ~ctx x_expr y_expr z_expr json
  | Recurse -> yield_many (recurse_down json)
  | Recurse_expr f ->
      let rec loop value =
        yield value;
        run (fun () -> interp ~ctx f value) ~and_then:(fun next -> loop next) ()
      in
      loop json
  | Recurse_with (f, cond) ->
      let results = recurse_with_cond ~ctx f cond json in
      yield_many results
  | Recurse_down -> yield_many (recurse_down json)
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
  | Any_with_generator (gen, cond) -> any_with_generator ~ctx gen cond json
  | All_with_generator (gen, cond) -> all_with_generator ~ctx gen cond json
  | Test pattern -> yield (test_regex ~ctx pattern json)
  | Match pattern -> match_regex ~ctx pattern json
  | Scan pattern -> scan_regex ~ctx pattern json
  | Capture pattern -> capture_regex ~ctx pattern json
  | Sub (pattern, replacement) ->
      yield (sub_regex ~ctx pattern replacement json)
  | Gsub (pattern, replacement) ->
      yield (gsub_regex ~ctx pattern replacement json)
  | Path expr -> path_of ~ctx expr json
  | Variable name -> variable ~ctx name
  | Env -> yield (`Assoc (get_envs ()))
  | Env_var name -> (
      match Sys.getenv_opt name with
      | Some v -> yield (`String v)
      | None -> yield `Null)
  | Combinations -> combinations ~ctx json
  | Combinations_n expr -> combinations_n ~ctx expr json
  | Repeat expr -> repeat_expr ~ctx expr json
  | Add_expr expr -> add_expr ~ctx expr json
  | Def (_, _, _) ->
      (* Def on its own (not in a Pipe). IT shouldn't happen in well-formed programs *)
      yield json
  | Apply (fname, args) -> call_function ~ctx fname args json
  | Reduce (expr, var_name, init_expr, update_expr) ->
      reduce ~ctx expr var_name init_expr update_expr json
  | As (expr, var_name, body) -> as_binding ~ctx expr var_name body json
  | Break -> break ()
  | Try (expr, handler) -> try_catch ~ctx expr handler json
  | Limit (n, expr) -> limit ~ctx n expr json
  | Skip (n, expr) -> skip ~ctx n expr json
  | Error_msg msg_expr -> error_msg ~ctx msg_expr json
  | Halt -> halt ()
  | Halt_error exit_code -> halt ~code:(Option.value exit_code ~default:1) ()
  | Isempty expr -> isempty ~ctx expr json
  | Del expr -> del ~ctx expr json
  | Delpaths expr -> delpaths ~ctx expr json
  | Pick expr -> pick ~ctx expr json
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

and dynamic_access ~ctx expr json =
  collect ~ctx expr json
  |> List.iter (fun key_or_idx ->
      match (json, key_or_idx) with
      | `Assoc fields, `String key -> (
          match List.assoc_opt key fields with
          | Some v -> yield v
          | None -> yield `Null)
      | `List items, `Int idx ->
          let len = List.length items in
          let actual_idx = if idx < 0 then len + idx else idx in
          if actual_idx >= 0 && actual_idx < len then
            yield (List.nth items actual_idx)
          else yield `Null
      | `List items, `Float f ->
          let idx = Float.to_int f in
          let len = List.length items in
          let actual_idx = if idx < 0 then len + idx else idx in
          if actual_idx >= 0 && actual_idx < len then
            yield (List.nth items actual_idx)
          else yield `Null
      | `Null, _ -> yield `Null
      | _ ->
          Error.message ~ctx
            ("Cannot index " ^ Json.type_of json ^ " with "
           ^ Json.type_of key_or_idx))

and update ~ctx path_expr transform json =
  (* path |= f means: for each path selected by path_expr, apply f to the value and update *)
  (* try to get existing paths *)
  let paths = collect ~ctx (Path path_expr) json in
  (* if no paths found, extract paths from AST for creation semantics *)
  let paths =
    if paths = [] then
      let rec extract_static_paths expr =
        match expr with
        | Identity -> [ [] ]
        | Key k -> [ [ `String k ] ]
        | Pipe (Identity, right) -> extract_static_paths right
        | Pipe (Key k, right) ->
            List.map (fun p -> `String k :: p) (extract_static_paths right)
        | Comma (left, right) ->
            extract_static_paths left @ extract_static_paths right
        | _ -> []
      in
      List.map (fun p -> `List p) (extract_static_paths path_expr)
    else paths
  in
  let result = ref json in
  List.iter
    (fun path_json ->
      match path_json with
      | `List path_components -> (
          let current_value = get_path !result path_components in
          let new_values = collect ~ctx transform current_value in
          match new_values with
          | new_value :: _ ->
              result := set_path !result path_components new_value
          | [] -> ())
      | _ -> ())
    paths;
  yield !result

and range_expr ~ctx from_expr upto_expr step_expr json =
  let to_int_list results =
    List.filter_map
      (function
        | `Int n -> Some n | `Float f -> Some (Float.to_int f) | _ -> None)
      results
  in
  let froms = to_int_list (collect ~ctx from_expr json) in
  let uptos =
    match upto_expr with
    | None -> [ None ]
    | Some expr ->
        List.map (fun x -> Some x) (to_int_list (collect ~ctx expr json))
  in
  let steps =
    match step_expr with
    | None -> [ None ]
    | Some expr ->
        List.map (fun x -> Some x) (to_int_list (collect ~ctx expr json))
  in
  List.iter
    (fun from ->
      List.iter
        (fun upto ->
          List.iter
            (fun step ->
              let vals = range ?step from upto in
              List.iter (fun i -> yield (`Int i)) vals)
            steps)
        uptos)
    froms

and select ~ctx conditional json =
  run
    (fun () -> interp ~ctx conditional json)
    ~and_then:(fun result ->
      match result with `Bool false | `Null -> () | _ -> yield json)
    ()

and pipe ~ctx left right json =
  match left with
  | Def (name, params, body) ->
      let func = { params; body } in
      let new_ctx = { ctx with fns = (name, func) :: ctx.fns } in
      interp ~ctx:new_ctx right json
  | _ ->
      run
        (fun () -> interp ~ctx left json)
        ~and_then:(fun json -> interp ~ctx right json)
        ()

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

and map_values ~ctx (expr : expression) (json : Json.t) =
  match json with
  | `List list ->
      let mapped =
        List.filter_map
          (fun item ->
            match collect ~ctx expr item with
            | [ v ] -> Some v
            | [] -> None (* filter out when expression produces empty *)
            | vs -> Some (`List vs))
          list
      in
      yield (`List mapped)
  | `Assoc entries ->
      let mapped =
        List.filter_map
          (fun (key, value) ->
            match collect ~ctx expr value with
            | [ v ] -> Some (key, v)
            | [] -> None (* filter out when expression produces empty *)
            | vs -> Some (key, `List vs))
          entries
      in
      yield (`Assoc mapped)
  | _ -> Error.make ~ctx "map_values" json

and sort_by ~ctx expr json =
  match json with
  | `List l ->
      let compare_by a b =
        let res_a = collect ~ctx expr a in
        let res_b = collect ~ctx expr b in
        match (res_a, res_b) with
        | [ av ], [ bv ] -> Json.compare av bv
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
        | [ av ], [ bv ] -> Json.compare av bv
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
        | [ av ], [ bv ] -> Json.compare av bv
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

and builtin_fns ~ctx builtin json =
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
  | Sinh -> yield (Operators.sinh_ ~ctx json)
  | Cosh -> yield (Operators.cosh_ ~ctx json)
  | Tanh -> yield (Operators.tanh_ ~ctx json)
  | Asinh -> yield (Operators.asinh_ ~ctx json)
  | Acosh -> yield (Operators.acosh_ ~ctx json)
  | Atanh -> yield (Operators.atanh_ ~ctx json)
  | Isinfinite -> yield (Operators.isinfinite ~ctx json)
  | Isnormal -> yield (Operators.isnormal ~ctx json)
  | Trunc -> yield (Operators.trunc_ ~ctx json)
  | Fabs -> yield (Operators.fabs ~ctx json)
  | Cbrt -> yield (Operators.cbrt_ ~ctx json)
  | Expm1 -> yield (Operators.expm1_ ~ctx json)
  | Exp2 -> yield (Operators.exp2_ ~ctx json)
  | Log1p -> yield (Operators.log1p_ ~ctx json)
  | Log2 -> yield (Operators.log2_ ~ctx json)
  | Nearbyint -> yield (Operators.nearbyint ~ctx json)
  | Logb -> yield (Operators.logb ~ctx json)

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

and any_with_generator ~ctx gen cond json =
  let is_truthy = function `Bool false | `Null -> false | _ -> true in
  let gen_results = collect ~ctx gen json in
  let rec check = function
    | [] -> yield (`Bool false)
    | x :: xs -> (
        try
          let cond_results = collect ~ctx cond x in
          if List.exists is_truthy cond_results then yield (`Bool true)
          else check xs
        with _ -> check xs)
  in
  check gen_results

and all_with_generator ~ctx gen cond json =
  let is_truthy = function `Bool false | `Null -> false | _ -> true in
  let gen_results = collect ~ctx gen json in
  let rec check = function
    | [] -> yield (`Bool true)
    | x :: xs -> (
        try
          let cond_results = collect ~ctx cond x in
          if List.for_all is_truthy cond_results then check xs
          else yield (`Bool false)
        with _ -> yield (`Bool false))
  in
  check gen_results

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
    | Dynamic_access expr ->
        let keys_or_indices = collect ~ctx expr value in
        List.concat_map
          (fun key_or_idx ->
            match (value, key_or_idx) with
            | `Assoc fields, `String key ->
                if List.mem_assoc key fields then
                  [ current_path @ [ `String key ] ]
                else []
            | `List _, `Int idx -> [ current_path @ [ `Int idx ] ]
            | `List _, `Float f -> [ current_path @ [ `Int (Float.to_int f) ] ]
            | _ -> [])
          keys_or_indices
    | Pipe (left, right) ->
        let selected_values = collect ~ctx left value in
        List.concat_map
          (fun selected ->
            match extract_path_for_value value selected with
            | Some left_path ->
                extract_paths (current_path @ left_path) right selected
            | None -> [])
          selected_values
    | Comma (left, right) ->
        extract_paths current_path left value
        @ extract_paths current_path right value
    | _ -> []
  and extract_path_for_value parent child =
    (* First check if parent = child - this is the path [] *)
    if parent = child then Some []
    else
      match (parent, child) with
      | `Assoc fields, _ ->
          List.find_map
            (fun (key, v) -> if v = child then Some [ `String key ] else None)
            fields
      | `List items, _ ->
          List.find_mapi
            (fun i v -> if v = child then Some [ `Int i ] else None)
            items
      | _ -> None
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
  match collect ~ctx expr json with
  | [ container ] -> (
      match (json, container) with
      | `Int n, `List l -> yield (`Bool (n >= 0 && n < List.length l))
      | `String key, `Assoc list -> yield (`Bool (List.mem_assoc key list))
      | _ -> Error.make ~ctx "in" json)
  | _ -> Error.message ~ctx "in expects single container"

and variable ~ctx var_name =
  if var_name = "ENV" then
    let env_pairs = get_envs () in
    yield (`Assoc env_pairs)
  else
    match List.assoc_opt var_name ctx.env with
    | Some value -> yield value
    | None -> Error.message ~ctx ("Undefined variable: $" ^ var_name)

and as_binding ~ctx expr var_name body json =
  (* expr as $var | body: for each value from expr, bind to var and run body *)
  run
    (fun () -> interp ~ctx expr json)
    ~and_then:(fun elem ->
      let new_ctx = { ctx with env = (var_name, elem) :: ctx.env } in
      interp ~ctx:new_ctx body json)
    ()

and if_then_else ~ctx cond if_branch else_branch json =
  run
    (fun () -> interp ~ctx cond json)
    ~and_then:(function
      | `Bool true -> interp ~ctx if_branch json
      | `Bool false | `Null -> interp ~ctx else_branch json
      | v -> Error.make ~ctx "if condition should be a bool" v)
    ()

and call_function ~ctx fname args json =
  match List.assoc_opt fname ctx.fns with
  | None -> Error.message ~ctx ("undefined function: " ^ fname)
  | Some { params; body } ->
      if List.length params <> List.length args then
        Error.message ~ctx
          ("wrong number of arguments for " ^ fname ^ ": expected "
          ^ Int.to_string (List.length params)
          ^ " but got "
          ^ Int.to_string (List.length args))
      else
        (* Separate value params ($x) from filter params (x) *)
        let is_value_param p = String.length p > 0 && p.[0] = '$' in
        let filter_params, filter_args, value_params, value_args =
          List.fold_left2
            (fun (fp, fa, vp, va) param arg ->
              if is_value_param param then (fp, fa, param :: vp, arg :: va)
              else (param :: fp, arg :: fa, vp, va))
            ([], [], [], []) params args
        in
        let filter_params = List.rev filter_params in
        let filter_args = List.rev filter_args in
        let value_params = List.rev value_params in
        let value_args = List.rev value_args in
        (* Substitute filter params in body *)
        let new_body = substitute_params filter_params filter_args body in
        (* Evaluate value params and bind them as variables (strip the $ prefix for env lookup) *)
        let value_bindings =
          List.map2
            (fun param arg ->
              let var_name = String.sub param 1 (String.length param - 1) in
              let values = collect ~ctx arg json in
              match values with
              | [ v ] -> (var_name, v)
              | [] -> (var_name, `Null)
              | _ ->
                  Error.message ~ctx
                    ("value parameter " ^ param ^ " produced multiple values"))
            value_params value_args
        in
        let new_ctx = { ctx with env = value_bindings @ ctx.env } in
        interp ~ctx:new_ctx new_body json

and starts_with ~ctx ~is_deprecated expr json =
  let name = if is_deprecated then "startwith/startswith" else "starts_with" in
  if is_deprecated then
    emit_warning ~verbose:ctx.verbose
      "Using deprecated 'startwith' or 'startswith'. Use 'starts_with' \
       instead. This may not be supported in future versions.";
  collect ~ctx expr json
  |> List.iter (fun pattern ->
      match (json, pattern) with
      | `String s, `String prefix ->
          yield (`Bool (String.starts_with ~prefix s))
      | _ -> Error.make ~ctx name json)

and ends_with ~ctx ~is_deprecated expr json =
  let name = if is_deprecated then "endwith/endswith" else "ends_with" in
  if is_deprecated then
    emit_warning ~verbose:ctx.verbose
      "Using deprecated 'endwith' or 'endswith'. Use 'ends_with' instead. This \
       may not be supported in future versions.";
  collect ~ctx expr json
  |> List.iter (fun pattern ->
      match (json, pattern) with
      | `String s, `String suffix -> yield (`Bool (String.ends_with ~suffix s))
      | _ -> Error.make ~ctx name json)

and with_entries ~ctx expr json =
  match to_entries ~ctx json with
  | `List entries ->
      let transformed =
        List.filter_map
          (fun entry ->
            match collect ~ctx expr entry with
            | [ res ] -> Some res
            | [] -> None
            | _ -> Some entry)
          entries
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
  let rec value_contains haystack needle =
    match (haystack, needle) with
    | `String s, `String sub -> (
        try
          let _ = Str.search_forward (Str.regexp_string sub) s 0 in
          true
        with Not_found -> false)
    | `List haystack, `List needle ->
        (* Every element in needle must be contained by some element in haystack *)
        List.for_all
          (fun n -> List.exists (fun h -> value_contains h n) haystack)
          needle
    | `Assoc haystack, `Assoc needle ->
        (* every key in needle must exist in haystack with contained value *)
        List.for_all
          (fun (k, v) ->
            match List.assoc_opt k haystack with
            | Some h_val -> value_contains h_val v
            | None -> false)
          needle
    | h, n -> Json.equal h n
  in
  match collect ~ctx expr json with
  | [ needle ] -> yield (`Bool (value_contains json needle))
  | _ -> Error.message ~ctx "contains expects single value"

and index_of ~ctx expr json =
  let yield_opt = function Some p -> yield (`Int p) | None -> yield `Null in
  collect ~ctx expr json
  |> List.iter (fun needle ->
      match (json, needle) with
      | `String haystack, `String needle ->
          yield_opt (Search.string_first haystack needle)
      | `List haystack, `List sublist ->
          yield_opt (Search.sublist_first haystack sublist)
      | `List haystack, needle ->
          yield_opt (Search.element_first haystack needle)
      | _ -> Error.make ~ctx "index" json)

and rindex_of ~ctx expr json =
  let yield_opt = function Some p -> yield (`Int p) | None -> yield `Null in
  collect ~ctx expr json
  |> List.iter (fun needle ->
      match (json, needle) with
      | `String haystack, `String needle ->
          yield_opt (Search.string_last haystack needle)
      | `List haystack, `List sublist ->
          yield_opt (Search.sublist_last haystack sublist)
      | `List haystack, needle ->
          yield_opt (Search.element_last haystack needle)
      | _ -> Error.make ~ctx "rindex" json)

and indices ~ctx expr json =
  let yield_positions positions =
    yield (`List (List.map (fun p -> `Int p) positions))
  in
  collect ~ctx expr json
  |> List.iter (fun needle ->
      match (json, needle) with
      | `String haystack, `String needle ->
          yield_positions (Search.string_all haystack needle)
      | `List haystack, `List sublist ->
          yield_positions (Search.sublist_all haystack sublist)
      | `List haystack, needle ->
          yield_positions (Search.element_all haystack needle)
      | _ -> Error.make ~ctx "indices" json)

and inside ~ctx expr json =
  collect ~ctx expr json
  |> List.iter (fun container ->
      match (json, container) with
      | `String needle, `String haystack -> (
          try
            let _ = Str.search_forward (Str.regexp_string needle) haystack 0 in
            yield (`Bool true)
          with Not_found -> yield (`Bool false))
      | `List needles, `List haystack ->
          yield
            (`Bool
               (List.for_all
                  (fun n -> List.exists (fun h -> Json.contains n h) haystack)
                  needles))
      | `Assoc _, `Assoc _ -> yield (`Bool (Json.contains json container))
      | _ -> Error.make ~ctx "inside" json)

and left_trimstr ~ctx expr json =
  collect ~ctx expr json
  |> List.iter (fun prefix ->
      match (json, prefix) with
      | `String s, `String prefix ->
          if String.starts_with ~prefix s then
            let prefix_len = String.length prefix in
            yield
              (`String (String.sub s prefix_len (String.length s - prefix_len)))
          else yield json
      | _ -> Error.make ~ctx "ltrimstr" json)

and right_trimstr ~ctx expr json =
  collect ~ctx expr json
  |> List.iter (fun suffix ->
      match (json, suffix) with
      | `String s, `String suffix ->
          if String.ends_with ~suffix s then
            let suffix_len = String.length suffix in
            yield (`String (String.sub s 0 (String.length s - suffix_len)))
          else yield json
      | _ -> Error.make ~ctx "rtrimstr" json)

and trim ~ctx json =
  match json with
  | `String s -> yield (`String (String.trim s))
  | _ -> Error.make ~ctx "trim" json

and left_trim ~ctx json =
  match json with
  | `String s ->
      let len = String.length s in
      let i = ref 0 in
      while
        !i < len
        && (s.[!i] = ' ' || s.[!i] = '\t' || s.[!i] = '\n' || s.[!i] = '\r')
      do
        incr i
      done;
      yield (`String (String.sub s !i (len - !i)))
  | _ -> Error.make ~ctx "ltrim" json

and right_trim ~ctx json =
  match json with
  | `String s ->
      let len = String.length s in
      let i = ref (len - 1) in
      while
        !i >= 0
        && (s.[!i] = ' ' || s.[!i] = '\t' || s.[!i] = '\n' || s.[!i] = '\r')
      do
        decr i
      done;
      yield (`String (String.sub s 0 (!i + 1)))
  | _ -> Error.make ~ctx "rtrim" json

and combinations ~ctx json =
  (* combinations: input is array of arrays, output all combinations *)
  match json with
  | `List arrays ->
      let arrays =
        List.map (fun a -> match a with `List l -> l | _ -> [ a ]) arrays
      in
      let rec cartesian = function
        | [] -> [ [] ]
        | hd :: tl ->
            let rest = cartesian tl in
            List.concat_map (fun x -> List.map (fun r -> x :: r) rest) hd
      in
      List.iter (fun combo -> yield (`List combo)) (cartesian arrays)
  | _ -> Error.make ~ctx "combinations" json

and combinations_n ~ctx expr json =
  (* combinations(n): generates n-way combinations from input array *)
  match (json, collect ~ctx expr json) with
  | `List arr, [ n_val ] ->
      let n =
        match n_val with `Float f -> Float.to_int f | `Int i -> i | _ -> 0
      in
      let rec repeat_arr count =
        if count <= 0 then [] else arr :: repeat_arr (count - 1)
      in
      let arrays = repeat_arr n in
      let rec cartesian = function
        | [] -> [ [] ]
        | hd :: tl ->
            let rest = cartesian tl in
            List.concat_map (fun x -> List.map (fun r -> x :: r) rest) hd
      in
      List.iter (fun combo -> yield (`List combo)) (cartesian arrays)
  | _ -> Error.message ~ctx "combinations(n) expects array input and number n"

and repeat_expr ~ctx expr json =
  (* repeat(f): generates infinite stream f, f|f, f|f|f, ... stopping on error *)
  let current = ref json in
  let continue = ref true in
  while !continue do
    run
      (fun () -> interp ~ctx expr !current)
      ~on_fail:(fun _ -> continue := false)
      ~and_then:(fun result ->
        yield result;
        current := result)
      ()
  done

and add_expr ~ctx expr json =
  match collect ~ctx expr json with
  | [] -> yield `Null
  | first :: rest ->
      let sum = List.fold_left (Operators.add ~ctx) first rest in
      yield sum

and ascii_upcase ~ctx json =
  match json with
  | `String s -> yield (`String (String.uppercase_ascii s))
  | _ -> Error.make ~ctx "ascii_upcase" json

and ascii_downcase ~ctx json =
  match json with
  | `String s -> yield (`String (String.lowercase_ascii s))
  | _ -> Error.make ~ctx "ascii_downcase" json

and binary_search ~ctx expr json =
  match json with
  | `List l ->
      collect ~ctx expr json
      |> List.iter (fun target ->
          let arr = Array.of_list l in
          let len = Array.length arr in
          let rec search lo hi =
            if lo >= hi then -(lo + 1)
            else
              let mid = (lo + hi) / 2 in
              let cmp = Json.compare arr.(mid) target in
              if cmp < 0 then search (mid + 1) hi
              else if cmp > 0 then search lo mid
              else mid
          in
          yield (`Int (search 0 len)))
  | _ -> Error.make ~ctx "bsearch" json

and first_of_array ~ctx json =
  match json with
  | `List [] -> ()
  | `List (hd :: _) -> yield hd
  | _ -> Error.make ~ctx "first" json

and first_of_expr ~ctx expr json =
  match collect ~ctx expr json with [] -> () | hd :: _ -> yield hd

and last_of_array ~ctx json =
  match json with
  | `List [] -> ()
  | `List l -> yield (List.hd (List.rev l))
  | _ -> Error.make ~ctx "last" json

and last_of_expr ~ctx expr json =
  match collect ~ctx expr json with
  | [] -> ()
  | l -> yield (List.hd (List.rev l))

and nth ~ctx n_expr expr json =
  let n_results = collect ~ctx n_expr json in
  let n_opt =
    match n_results with
    | [ `Int n ] -> Some n
    | [ `Float f ] -> Some (Int.of_float f)
    | _ -> None
  in
  match n_opt with
  | Some n ->
      let results = collect ~ctx expr json in
      if n >= 0 && n < List.length results then yield (List.nth results n)
      else () (* out of bounds returns empty *)
  | None -> Error.make ~ctx "nth: first argument must be a number" json

and group_by ~ctx expr json =
  match json with
  | `List l ->
      let estimated_groups = Int.max 16 (List.length l / 4) in
      let groups = Hashtbl.create estimated_groups in
      let group_keys = ref [] in
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
                | None ->
                    group_keys := (key_str, key) :: !group_keys;
                    []
              in
              Hashtbl.replace groups key_str (item :: existing)
          | _ -> ())
        l;
      let sorted_keys =
        List.sort (fun (_, k1) (_, k2) -> Json.compare k1 k2) !group_keys
      in
      let result =
        List.map
          (fun (key_str, _) ->
            match Hashtbl.find_opt groups key_str with
            | Some items -> `List (List.rev items)
            | None -> `List [])
          sorted_keys
      in
      yield (`List result)
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
  (* until(cond; update): loop until cond is true, yield only final value *)
  let rec loop current =
    let cond_res = collect ~ctx cond current in
    match cond_res with
    | [ `Bool true ] -> yield current
    | [ `Bool false ] -> (
        let next_res = collect ~ctx update current in
        match next_res with [ next ] -> loop next | _ -> yield current)
    | _ -> yield current
  in
  loop json

and atan2_op ~ctx y_expr x_expr json =
  let y_vals = collect ~ctx y_expr json in
  let x_vals = collect ~ctx x_expr json in
  match (y_vals, x_vals) with
  | [ y ], [ x ] -> (
      match (y, x) with
      | (`Float _ | `Int _), (`Float _ | `Int _) ->
          let yf =
            match y with `Float f -> f | `Int n -> Float.of_int n | _ -> 0.0
          in
          let xf =
            match x with `Float f -> f | `Int n -> Float.of_int n | _ -> 0.0
          in
          yield (`Float (Float.atan2 yf xf))
      | _ -> Error.message ~ctx "atan2 requires two numbers")
  | _ -> Error.message ~ctx "atan2 requires two single values"

and copysign_op ~ctx x_expr y_expr json =
  let x_vals = collect ~ctx x_expr json in
  let y_vals = collect ~ctx y_expr json in
  match (x_vals, y_vals) with
  | [ x ], [ y ] -> (
      match (x, y) with
      | (`Float _ | `Int _), (`Float _ | `Int _) ->
          let xf =
            match x with `Float f -> f | `Int n -> Float.of_int n | _ -> 0.0
          in
          let yf =
            match y with `Float f -> f | `Int n -> Float.of_int n | _ -> 0.0
          in
          yield (`Float (Float.copy_sign xf yf))
      | _ -> Error.message ~ctx "copysign requires two numbers")
  | _ -> Error.message ~ctx "copysign requires two single values"

and ldexp_op ~ctx m_expr e_expr json =
  let m_vals = collect ~ctx m_expr json in
  let e_vals = collect ~ctx e_expr json in
  match (m_vals, e_vals) with
  | [ m ], [ e ] -> (
      match (m, e) with
      | (`Float _ | `Int _), (`Float _ | `Int _) ->
          let mf =
            match m with `Float f -> f | `Int n -> Float.of_int n | _ -> 0.0
          in
          let ei =
            match e with `Int n -> n | `Float f -> Float.to_int f | _ -> 0
          in
          yield (`Float (Float.ldexp mf ei))
      | _ -> Error.message ~ctx "ldexp requires two numbers")
  | _ -> Error.message ~ctx "ldexp requires two single values"

and fdim_op ~ctx x_expr y_expr json =
  let x_vals = collect ~ctx x_expr json in
  let y_vals = collect ~ctx y_expr json in
  match (x_vals, y_vals) with
  | [ x ], [ y ] -> (
      match (x, y) with
      | (`Float _ | `Int _), (`Float _ | `Int _) ->
          let xf =
            match x with `Float f -> f | `Int n -> Float.of_int n | _ -> 0.0
          in
          let yf =
            match y with `Float f -> f | `Int n -> Float.of_int n | _ -> 0.0
          in
          yield (`Float (Float.max 0.0 (xf -. yf)))
      | _ -> Error.message ~ctx "fdim requires two numbers")
  | _ -> Error.message ~ctx "fdim requires two single values"

and remainder_op ~ctx x_expr y_expr json =
  let x_vals = collect ~ctx x_expr json in
  let y_vals = collect ~ctx y_expr json in
  match (x_vals, y_vals) with
  | [ x ], [ y ] -> (
      match (x, y) with
      | (`Float _ | `Int _), (`Float _ | `Int _) ->
          let xf =
            match x with `Float f -> f | `Int n -> Float.of_int n | _ -> 0.0
          in
          let yf =
            match y with `Float f -> f | `Int n -> Float.of_int n | _ -> 0.0
          in
          yield (`Float (mod_float xf yf))
      | _ -> Error.message ~ctx "remainder requires two numbers")
  | _ -> Error.message ~ctx "remainder requires two single values"

and scalbn_op ~ctx x_expr n_expr json =
  let x_vals = collect ~ctx x_expr json in
  let n_vals = collect ~ctx n_expr json in
  match (x_vals, n_vals) with
  | [ x ], [ n ] -> (
      match (x, n) with
      | (`Float _ | `Int _), (`Float _ | `Int _) ->
          let xf =
            match x with `Float f -> f | `Int n -> Float.of_int n | _ -> 0.0
          in
          let ni =
            match n with `Int n -> n | `Float f -> Float.to_int f | _ -> 0
          in
          yield (`Float (Float.ldexp xf ni))
      | _ -> Error.message ~ctx "scalbn requires two numbers")
  | _ -> Error.message ~ctx "scalbn requires two single values"

and pow2_op ~ctx x_expr y_expr json =
  let x_vals = collect ~ctx x_expr json in
  let y_vals = collect ~ctx y_expr json in
  match (x_vals, y_vals) with
  | [ x ], [ y ] -> (
      match (x, y) with
      | (`Float _ | `Int _), (`Float _ | `Int _) ->
          let xf =
            match x with `Float f -> f | `Int n -> Float.of_int n | _ -> 0.0
          in
          let yf =
            match y with `Float f -> f | `Int n -> Float.of_int n | _ -> 0.0
          in
          yield (`Float (xf ** yf))
      | _ -> Error.message ~ctx "pow requires two numbers")
  | _ -> Error.message ~ctx "pow requires two single values"

and fma_op ~ctx x_expr y_expr z_expr json =
  let x_vals = collect ~ctx x_expr json in
  let y_vals = collect ~ctx y_expr json in
  let z_vals = collect ~ctx z_expr json in
  match (x_vals, y_vals, z_vals) with
  | [ x ], [ y ], [ z ] -> (
      match (x, y, z) with
      | (`Float _ | `Int _), (`Float _ | `Int _), (`Float _ | `Int _) ->
          let xf =
            match x with `Float f -> f | `Int n -> Float.of_int n | _ -> 0.0
          in
          let yf =
            match y with `Float f -> f | `Int n -> Float.of_int n | _ -> 0.0
          in
          let zf =
            match z with `Float f -> f | `Int n -> Float.of_int n | _ -> 0.0
          in
          yield (`Float (Float.fma xf yf zf))
      | _ -> Error.message ~ctx "fma requires three numbers")
  | _ -> Error.message ~ctx "fma requires three single values"

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
  let try_handler : unit Effect.Deep.effect_handler =
    {
      effc =
        (fun (type a) (eff : a Effect.t) ->
          match eff with
          | User_error value ->
              Some
                (fun (_ : (a, _) Effect.Deep.continuation) ->
                  match handler with
                  | None -> () (* No catch handler, error is silently ignored *)
                  | Some handler_expr -> interp ~ctx handler_expr value)
          | Fail _ ->
              Some
                (fun (_ : (a, _) Effect.Deep.continuation) ->
                  match handler with
                  | None -> ()
                  | Some handler_expr -> interp ~ctx handler_expr json)
          | _ -> None);
    }
  in
  Effect.Deep.try_with (fun () -> interp ~ctx expr json) () try_handler

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

and skip ~ctx n expr json =
  let count = ref 0 in
  run
    (fun () -> interp ~ctx expr json)
    ~and_then:(fun result ->
      incr count;
      if !count > n then yield result)
    ()

and error_msg ~ctx msg_expr json =
  match msg_expr with
  | None -> user_error json
  | Some expr -> (
      match collect ~ctx expr json with
      | [ value ] -> user_error value
      | _ -> Error.message ~ctx "error expects single value")

and isempty ~ctx expr json =
  match collect ~ctx expr json with
  | [] -> yield (`Bool true)
  | _ -> yield (`Bool false)

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

and delete_path value path_components =
  let rec del_at value = function
    | [] -> `Null (* Path points to root, delete returns null *)
    | [ `String key ] -> (
        match value with
        | `Assoc fields -> `Assoc (List.filter (fun (k, _) -> k <> key) fields)
        | _ -> value)
    | [ ((`Int _ | `Float _) as num) ] -> (
        let idx =
          match num with `Int i -> i | `Float f -> Float.to_int f | _ -> 0
        in
        match value with
        | `List items -> `List (List.filteri (fun i _ -> i <> idx) items)
        | _ -> value)
    | `String key :: rest -> (
        match value with
        | `Assoc fields ->
            `Assoc
              (List.map
                 (fun (k, v) -> if k = key then (k, del_at v rest) else (k, v))
                 fields)
        | _ -> value)
    | ((`Int _ | `Float _) as num) :: rest -> (
        let idx =
          match num with `Int i -> i | `Float f -> Float.to_int f | _ -> 0
        in
        match value with
        | `List items ->
            `List
              (List.mapi
                 (fun i v -> if i = idx then del_at v rest else v)
                 items)
        | _ -> value)
    | _ -> value
  in
  match path_components with `List comps -> del_at value comps | _ -> value

and delpaths ~ctx expr json =
  match collect ~ctx expr json with
  | [ `List paths ] ->
      let result = List.fold_left delete_path json paths in
      yield result
  | _ -> Error.message ~ctx "delpaths expects array of paths"

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
        | ((`Int _ | `Float _) as num) :: rest -> (
            let idx =
              match num with `Int i -> i | `Float f -> Float.to_int f | _ -> 0
            in
            match value with
            | `List items ->
                let rec update_list i = function
                  | [] -> if i = idx then [ set_at `Null rest ] else []
                  | x :: xs ->
                      if i = idx then set_at x rest :: xs
                      else x :: update_list (i + 1) xs
                in
                `List (update_list 0 items)
            | `Null ->
                (* Create array with nulls up to idx, then set value at idx *)
                let arr =
                  List.init (idx + 1) (fun i ->
                      if i = idx then set_at `Null rest else `Null)
                in
                `List arr
            | _ -> value)
        | _ :: rest -> set_at value rest
      in
      yield (set_at json path_components)
  | _ -> Error.message ~ctx "setpath expects (path_array, value)"

and pick ~ctx expr json =
  (* extract path structure from expressions, even for non-existent paths *)
  let rec extract_path_expr = function
    | Identity -> [ [] ]
    | Key key -> [ [ `String key ] ]
    | Index [ idx ] -> [ [ `Int idx ] ]
    | Pipe (left, right) ->
        let left_paths = extract_path_expr left in
        let right_paths = extract_path_expr right in
        List.concat_map
          (fun lp -> List.map (fun rp -> lp @ rp) right_paths)
          left_paths
    | Comma (left, right) -> extract_path_expr left @ extract_path_expr right
    | Dynamic_access inner ->
        (* For dynamic access like .[$var], evaluate to get the key/index *)
        let keys = collect ~ctx inner json in
        List.filter_map
          (function
            | `String s -> Some [ `String s ]
            | `Int i -> Some [ `Int i ]
            | `Float f -> Some [ `Int (Float.to_int f) ]
            | _ -> None)
          keys
    | _ -> []
  in
  let paths = extract_path_expr expr in
  let result =
    List.fold_left
      (fun acc path_components ->
        let value = get_path json path_components in
        set_path acc path_components value)
      `Null paths
  in
  yield result

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

and leaf_paths json =
  let rec find_leaf_paths current_path value =
    match value with
    | `Assoc fields ->
        List.concat_map
          (fun (k, v) -> find_leaf_paths (current_path @ [ `String k ]) v)
          fields
    | `List items ->
        List.concat_map
          (fun (i, v) -> find_leaf_paths (current_path @ [ `Int i ]) v)
          (List.mapi (fun i v -> (i, v)) items)
    | _ -> [ current_path ]
  in
  yield_many (List.map (fun p -> `List p) (find_leaf_paths [] json))

and slice_expr ~ctx (start_expr : expression option)
    (end_expr : expression option) (json : Json.t) =
  let eval_to_int expr =
    match collect ~ctx expr json with
    | [ `Int n ] -> n
    | [ `Float f ] -> int_of_float f
    | _ -> failwith "slice index must evaluate to a number"
  in
  let start = Option.map eval_to_int start_expr in
  let finish = Option.map eval_to_int end_expr in
  slice ~ctx start finish json

and assign ~ctx path value_expr json =
  (* Assignment is like setpath but path is an AST expression, not a value *)
  let values = collect ~ctx value_expr json in
  let new_value = match values with [] -> `Null | v :: _ -> v in
  let rec assign_path result p =
    match p with
    | Key key -> (
        match result with
        | `Assoc fields ->
            let updated =
              List.map
                (fun (k, v) -> if k = key then (k, new_value) else (k, v))
                fields
            in
            let exists = List.mem_assoc key fields in
            if exists then `Assoc updated
            else `Assoc (fields @ [ (key, new_value) ])
        | `Null -> `Assoc [ (key, new_value) ]
        | _ -> result)
    | Pipe (Identity, right) -> assign_path result right
    | Comma (left, right) ->
        let result' = assign_path result left in
        assign_path result' right
    | _ -> result
  in
  yield (assign_path json path)

let execute ~colorize ~verbose ?(env = []) expr json =
  let ctx = { colorize; verbose; env; fns = [] } in
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
                (fun (_ : (a, _) Effect.Deep.continuation) ->
                  Error (red "Error: " ^ "break used outside of loop context"))
          | Halt exit_code -> Some (fun _ -> exit exit_code)
          | _ -> None);
    }
  in
  Effect.Deep.match_with (fun () -> collect ~ctx expr json) () handler
