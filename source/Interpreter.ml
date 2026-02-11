open Ast

module Runtime_error : sig
  type t
  type _ Effect.t += Fail : t -> unit Effect.t

  val to_json : t -> Json.t
  val kind_string : t -> string
  val message : t -> string
  val value : t -> Json.t option
  val suggestion : t -> string option
  val key_not_found : key:string -> value:Json.t -> 'a
  val null_access : key:string -> value:Json.t -> 'a
  val type_mismatch : value:Json.t -> ?suggestion:string -> string -> 'a
  val index_out_of_bounds : index:int -> length:int -> value:Json.t -> 'a
  val empty_array : string -> 'a
  val invalid_argument : fn:string -> expected:string -> found:string -> 'a
  val undefined_function : name:string -> 'a
  val empty_result : op:string -> ?suggestion:string -> unit -> 'a
  val assertion_error : value:Json.t -> string -> 'a
  val custom : kind:string -> value:Json.t -> string -> 'a
end = struct
  type error_kind =
    | Key_not_found
    | Null_access
    | Type_mismatch
    | Index_out_of_bounds
    | Empty_array
    | Undefined_function
    | Empty_result
    | Assertion_error
    | Invalid_argument
    | Custom of string

  let error_kind_to_string = function
    | Key_not_found -> "key_not_found"
    | Null_access -> "null_access"
    | Type_mismatch -> "type_mismatch"
    | Index_out_of_bounds -> "index_out_of_bounds"
    | Empty_array -> "empty_array"
    | Undefined_function -> "undefined_function"
    | Empty_result -> "empty_result"
    | Assertion_error -> "assertion_error"
    | Invalid_argument -> "invalid_argument"
    | Custom s -> s

  type t = {
    kind : error_kind;
    message : string;
    value : Json.t option;
    suggestion : string option;
  }

  type _ Effect.t += Fail : t -> unit Effect.t

  let to_json { kind; message; value; suggestion } : Json.t =
    let fields =
      [
        ("kind", `String (error_kind_to_string kind));
        ("message", `String message);
      ]
    in
    let fields =
      match value with Some v -> fields @ [ ("value", v) ] | None -> fields
    in
    let fields =
      match suggestion with
      | Some s -> fields @ [ ("suggestion", `String s) ]
      | None -> fields
    in
    `Assoc fields

  let kind_string err = error_kind_to_string err.kind
  let message err = err.message
  let value err = err.value
  let suggestion err = err.suggestion

  let fail ~kind ?value ?suggestion message =
    Effect.perform (Fail { kind; message; value; suggestion });
    assert false

  let key_not_found ~key ~value =
    let suggestion =
      match value with
      | `Assoc assoc -> (
          let keys = List.map fst assoc in
          let hyphenated_match =
            List.find_opt
              (fun k ->
                let key_len = String.length key in
                String.length k > key_len
                && String.sub k 0 key_len = key
                && String.get k key_len = '-')
              keys
          in
          match hyphenated_match with
          | Some hk ->
              Printf.sprintf
                "Did you mean \"%s\"? Use .[\"...\"] or .\"...\" for keys with \
                 hyphens"
                hk
          | None -> "Use ." ^ key ^ "? for optional access")
      | _ -> "Use ." ^ key ^ "? for optional access"
    in
    fail ~kind:Key_not_found ~value ~suggestion
      ("Key '" ^ key ^ "' not found in object")

  let null_access ~key ~value =
    fail ~kind:Null_access ~value ("Cannot access key '" ^ key ^ "' on null")

  let type_mismatch ~value ?suggestion message =
    fail ~kind:Type_mismatch ~value ?suggestion message

  let index_out_of_bounds ~index ~length ~value =
    fail ~kind:Index_out_of_bounds ~value
      ~suggestion:("Use .[" ^ Int.to_string index ^ "]? for optional access")
      ("Index " ^ Int.to_string index ^ " out of bounds (array has "
     ^ Int.to_string length ^ " elements)")

  let empty_array op =
    fail ~kind:Empty_array
      ~suggestion:("Use " ^ op ^ "? for optional access")
      (op ^ ": empty array")

  let invalid_argument ~fn ~expected ~found =
    fail ~kind:Invalid_argument
      (Printf.sprintf "`%s`: expected %s, found %s" fn expected found)

  let undefined_function ~name =
    fail ~kind:Undefined_function
      ~suggestion:"check function name or define it with 'fn'"
      ("undefined function: `" ^ name ^ "`")

  let empty_result ~op ?suggestion () =
    let suggestion =
      match suggestion with
      | Some s -> Some s
      | None -> Some ("Use " ^ op ^ "? for optional access")
    in
    fail ~kind:Empty_result ?suggestion (op ^ ": empty expression result")

  let assertion_error ~value message =
    fail ~kind:Assertion_error ~value
      ~suggestion:"Check the condition in your assert() call" message

  let custom ~kind ~value message = fail ~kind:(Custom kind) ~value message
end

type _ Effect.t +=
  | Yield : Json.t -> unit Effect.t
  | Break : unit Effect.t
  | Halt : int -> unit Effect.t
  | User_error : Json.t -> unit Effect.t

type fn_definition = { params : string list; body : expression }

type ctx = {
  colorize : bool;
  verbose : bool; [@warning "-69"]
  env : (string * Json.t) list;
  fns : (string * fn_definition) list;
}

let yield v = Effect.perform (Yield v)
let break () = Effect.perform Break
let halt ?(code = 0) () = Effect.perform (Halt code)

let user_error value =
  Effect.perform (User_error value);
  assert false

let yield_many items = List.iter yield items

let run fn ?and_then ?on_fail () =
  let fn =
    match and_then with
    | None -> fn
    | Some f -> (
        fun () ->
          match fn () with
          | () -> ()
          | effect Yield json, k ->
              f json;
              Effect.Deep.continue k ())
  in
  match on_fail with
  | None -> fn ()
  | Some f -> (
      match fn () with () -> () | effect Runtime_error.Fail err, _ -> f err)

let run_while fn ~when_ =
  match fn () with
  | () -> ()
  | effect Yield v, k -> if when_ v then Effect.Deep.continue k () else ()

let run_and_collect_results fn =
  match fn () with
  | () -> []
  | effect Yield v, k -> v :: Effect.Deep.continue k ()

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
  | Fn0 _ -> expr
  | Fn1 fn1 -> (
      match fn1 with
      | With_pattern _ -> expr
      | With_separator _ -> expr
      | With_expr (f, e) -> Fn1 (With_expr (f, sub e)))
  | Fn2 (f, e1, e2) -> Fn2 (f, sub e1, sub e2)
  | Identity | Literal _ | Variable _ | Key _ | Env_var _ | Index _ | Slice _ ->
      expr
  | Pipe (l, r) -> Pipe (sub l, sub r)
  | Update (l, r) -> Update (sub l, sub r)
  | Alternative (l, r) -> Alternative (sub l, sub r)
  | Comma (l, r) -> Comma (sub l, sub r)
  | Operation (l, op, r) -> Operation (sub l, op, sub r)
  | Assign (l, r) -> Assign (sub l, sub r)
  | List e -> List (sub_opt e)
  | Object pairs -> Object (List.map (fun (k, v) -> (sub k, sub_opt v)) pairs)
  | Optional e -> Optional (sub e)
  | Dynamic_access e -> Dynamic_access (sub e)
  | Slice_expr (a, b) -> Slice_expr (sub_opt a, sub_opt b)
  | If_then_else (c, t, e) -> If_then_else (sub c, sub t, sub e)
  | Range (e1, e2, e3) -> Range (sub e1, sub_opt e2, sub_opt e3)
  | Reduce (e, var, init, update) -> Reduce (sub e, var, sub init, sub update)
  | Foreach (e, var, init, update, extract) ->
      Foreach (sub e, var, sub init, sub update, sub extract)
  | As (e, var, body) -> As (sub e, var, sub body)
  | Try (e, h, f) -> Try (sub e, sub_opt h, sub_opt f)
  | Fma (e1, e2, e3) -> Fma (sub e1, sub e2, sub e3)
  | Fn (name, params', body) -> Fn (name, params', sub body)
  | Apply (name, call_args) -> Apply (name, List.map sub call_args)

let fail_invalid_type ~ctx op json =
  let type_desc =
    match json with
    | `List _ | `Assoc _ -> "an " ^ Json.type_of json
    | `String _ -> "a " ^ Json.type_of json
    | `Bool _ -> "a boolean"
    | `Float _ | `Int _ | `Int64 _ | `Big_int _ -> "a number"
    | `Null -> "null"
  in
  let t = Console_style.make ~colorize:ctx.colorize in
  Runtime_error.type_mismatch ~value:json
    ("Cannot apply "
    ^ Console_style.single_quotes (t.bold op)
    ^ " to " ^ type_desc)

module Operators = struct
  let not (json : Json.t) =
    match json with `Bool false | `Null -> `Bool true | _ -> `Bool false

  let to_float = function
    | `Float f -> Some f
    | `Int n -> Some (Float.of_int n)
    | `Int64 n -> Some (Int64.to_float n)
    | `Big_int z -> Some (Z.to_float z)
    | _ -> None

  let add ~ctx str (left : Json.t) (right : Json.t) : Json.t =
    match (left, right) with
    | `Big_int l, `Big_int r -> `Big_int (Z.add l r)
    | `Big_int l, `Int r -> `Big_int (Z.add l (Z.of_int r))
    | `Int l, `Big_int r -> `Big_int (Z.add (Z.of_int l) r)
    | `Big_int l, `Int64 r -> `Big_int (Z.add l (Z.of_int64 r))
    | `Int64 l, `Big_int r -> `Big_int (Z.add (Z.of_int64 l) r)
    | `Big_int l, `Float r -> `Float (Z.to_float l +. r)
    | `Float l, `Big_int r -> `Float (l +. Z.to_float r)
    | `Int64 l, `Int64 r -> `Int64 (Int64.add l r)
    | `Int64 l, `Int r -> `Int64 (Int64.add l (Int64.of_int r))
    | `Int l, `Int64 r -> `Int64 (Int64.add (Int64.of_int l) r)
    | `Int l, `Int r -> `Int64 (Int64.add (Int64.of_int l) (Int64.of_int r))
    | `Float l, `Float r -> `Float (l +. r)
    | `Int l, `Float r -> `Float (Int.to_float l +. r)
    | `Float l, `Int r -> `Float (l +. Int.to_float r)
    | `Int64 l, `Float r -> `Float (Int64.to_float l +. r)
    | `Float l, `Int64 r -> `Float (l +. Int64.to_float r)
    | `String l, `String r -> `String (l ^ r)
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
        (* then add new keys from r that weren't in l *)
        let new_keys =
          List.filter
            (fun (k, _) -> Stdlib.not (List.mem_assoc k l_entries))
            r_entries
        in
        `Assoc (updated_l @ new_keys)
    | `List l, `List r -> `List (l @ r)
    | `Null, r ->
        Runtime_error.type_mismatch ~value:r
          ~suggestion:"Use (.x ?? 0) for explicit null handling"
          ("Cannot add null to " ^ Json.type_of r)
    | l, `Null ->
        Runtime_error.type_mismatch ~value:l
          ~suggestion:"Use (.x ?? 0) for explicit null handling"
          ("Cannot add " ^ Json.type_of l ^ " to null")
    | _ -> fail_invalid_type ~ctx str left

  let apply_float_operation ~ctx str fn (left : Json.t) (right : Json.t) =
    match (to_float left, to_float right) with
    | Some l, Some r -> `Float (fn l r)
    | _ -> fail_invalid_type ~ctx str left

  let compare ~ctx:_ str int_fn (left : Json.t) (right : Json.t) =
    match (left, right) with
    | ( (`Int _ | `Int64 _ | `Big_int _ | `Float _),
        (`Int _ | `Int64 _ | `Big_int _ | `Float _) ) ->
        `Bool (int_fn (Json.compare left right) 0)
    | _ ->
        Runtime_error.invalid_argument ~fn:str ~expected:"numbers"
          ~found:(Json.type_of left ^ " and " ^ Json.type_of right)

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
    | `Big_int l, `Big_int r -> `Big_int (Z.sub l r)
    | `Big_int l, `Int r -> `Big_int (Z.sub l (Z.of_int r))
    | `Int l, `Big_int r -> `Big_int (Z.sub (Z.of_int l) r)
    | `Big_int l, `Int64 r -> `Big_int (Z.sub l (Z.of_int64 r))
    | `Int64 l, `Big_int r -> `Big_int (Z.sub (Z.of_int64 l) r)
    | `Big_int l, `Float r -> `Float (Z.to_float l -. r)
    | `Float l, `Big_int r -> `Float (l -. Z.to_float r)
    | `Int64 l, `Int64 r -> `Int64 (Int64.sub l r)
    | `Int64 l, `Int r -> `Int64 (Int64.sub l (Int64.of_int r))
    | `Int l, `Int64 r -> `Int64 (Int64.sub (Int64.of_int l) r)
    | `Int l, `Int r -> `Int64 (Int64.sub (Int64.of_int l) (Int64.of_int r))
    | `Float l, `Float r -> `Float (l -. r)
    | `Int l, `Float r -> `Float (Int.to_float l -. r)
    | `Float l, `Int r -> `Float (l -. Int.to_float r)
    | `Int64 l, `Float r -> `Float (Int64.to_float l -. r)
    | `Float l, `Int64 r -> `Float (l -. Int64.to_float r)
    | `List l, `List r ->
        let in_r x = List.exists (fun y -> Json.equal x y) r in
        `List (List.filter (fun x -> Stdlib.not (in_r x)) l)
    | _ -> fail_invalid_type ~ctx "-" left

  let rec deep_merge (left : Json.t) (right : Json.t) : Json.t =
    match (left, right) with
    | `Assoc l_entries, `Assoc r_entries ->
        (* preserve key order: update existing keys from l with recursive merge from r *)
        let updated_l =
          List.map
            (fun (k, v) ->
              match List.assoc_opt k r_entries with
              | Some r_val -> (k, deep_merge v r_val)
              | None -> (k, v))
            l_entries
        in
        (* add new keys from r that weren't in l *)
        let new_keys =
          List.filter
            (fun (k, _) -> Stdlib.not (List.mem_assoc k l_entries))
            r_entries
        in
        `Assoc (updated_l @ new_keys)
    | _, r -> r

  let multiply ~ctx (left : Json.t) (right : Json.t) : Json.t =
    match (left, right) with
    | `Big_int l, `Big_int r -> `Big_int (Z.mul l r)
    | `Big_int l, `Int r -> `Big_int (Z.mul l (Z.of_int r))
    | `Int l, `Big_int r -> `Big_int (Z.mul (Z.of_int l) r)
    | `Big_int l, `Int64 r -> `Big_int (Z.mul l (Z.of_int64 r))
    | `Int64 l, `Big_int r -> `Big_int (Z.mul (Z.of_int64 l) r)
    | `Big_int l, `Float r -> `Float (Z.to_float l *. r)
    | `Float l, `Big_int r -> `Float (l *. Z.to_float r)
    | `Int64 l, `Int64 r -> `Int64 (Int64.mul l r)
    | `Int64 l, `Int r -> `Int64 (Int64.mul l (Int64.of_int r))
    | `Int l, `Int64 r -> `Int64 (Int64.mul (Int64.of_int l) r)
    | `Int l, `Int r -> `Int64 (Int64.mul (Int64.of_int l) (Int64.of_int r))
    | `Float l, `Float r -> `Float (l *. r)
    | `Int l, `Float r -> `Float (Int.to_float l *. r)
    | `Float l, `Int r -> `Float (l *. Int.to_float r)
    | `Int64 l, `Float r -> `Float (Int64.to_float l *. r)
    | `Float l, `Int64 r -> `Float (l *. Int64.to_float r)
    | `String s, `Int n ->
        if n <= 0 then `String ""
        else `String (String.concat "" (List.init n (fun _ -> s)))
    | `String s, `Int64 n ->
        let count = Int64.to_int n in
        if count <= 0 then `String ""
        else `String (String.concat "" (List.init count (fun _ -> s)))
    | `String s, `Float f ->
        let count = Int.of_float f in
        if count <= 0 then `String ""
        else `String (String.concat "" (List.init count (fun _ -> s)))
    | `Assoc _, `Assoc _ -> deep_merge left right
    | `Null, r | r, `Null -> r
    | _ -> fail_invalid_type ~ctx "*" left

  let divide ~ctx (left : Json.t) (right : Json.t) : Json.t =
    match (left, right) with
    | `Big_int l, `Big_int r -> `Float (Z.to_float l /. Z.to_float r)
    | `Big_int l, `Int r -> `Float (Z.to_float l /. Int.to_float r)
    | `Int l, `Big_int r -> `Float (Int.to_float l /. Z.to_float r)
    | `Big_int l, `Int64 r -> `Float (Z.to_float l /. Int64.to_float r)
    | `Int64 l, `Big_int r -> `Float (Int64.to_float l /. Z.to_float r)
    | `Big_int l, `Float r -> `Float (Z.to_float l /. r)
    | `Float l, `Big_int r -> `Float (l /. Z.to_float r)
    | `Float l, `Float r -> `Float (l /. r)
    | `Int l, `Float r -> `Float (Int.to_float l /. r)
    | `Float l, `Int r -> `Float (l /. Int.to_float r)
    | `Int l, `Int r -> `Float (Int.to_float l /. Int.to_float r)
    | `Int64 l, `Float r -> `Float (Int64.to_float l /. r)
    | `Float l, `Int64 r -> `Float (l /. Int64.to_float r)
    | `Int64 l, `Int64 r -> `Float (Int64.to_float l /. Int64.to_float r)
    | `Int64 l, `Int r -> `Float (Int64.to_float l /. Int.to_float r)
    | `Int l, `Int64 r -> `Float (Int.to_float l /. Int64.to_float r)
    | `String s, `String delim ->
        `List
          (Str.split_delim (Str.regexp_string delim) s
          |> List.map (fun part -> `String part))
    | _ -> fail_invalid_type ~ctx "/" left

  let modulo ~ctx (left : Json.t) (right : Json.t) : Json.t =
    match (left, right) with
    | `Big_int l, `Big_int r -> `Big_int (Z.rem l r)
    | `Big_int l, `Int r -> `Big_int (Z.rem l (Z.of_int r))
    | `Int l, `Big_int r -> `Big_int (Z.rem (Z.of_int l) r)
    | `Big_int l, `Int64 r -> `Big_int (Z.rem l (Z.of_int64 r))
    | `Int64 l, `Big_int r -> `Big_int (Z.rem (Z.of_int64 l) r)
    | `Big_int l, `Float r -> `Float (mod_float (Z.to_float l) r)
    | `Float l, `Big_int r -> `Float (mod_float l (Z.to_float r))
    | `Int64 l, `Int64 r -> `Int64 (Int64.rem l r)
    | `Int64 l, `Int r -> `Int64 (Int64.rem l (Int64.of_int r))
    | `Int l, `Int64 r -> `Int64 (Int64.rem (Int64.of_int l) r)
    | `Int l, `Int r -> `Int64 (Int64.rem (Int64.of_int l) (Int64.of_int r))
    | _ -> apply_float_operation ~ctx "%" mod_float left right
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
  | `Int64 idx :: rest -> (
      let idx = Int64.to_int idx in
      match value with
      | `List items ->
          if idx >= 0 && idx < List.length items then
            get_path (List.nth items idx) rest
          else `Null
      | _ -> `Null)
  | `Big_int idx :: rest -> (
      let idx = Z.to_int idx in
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
  | ((`Int _ | `Int64 _ | `Big_int _ | `Float _) as num) :: rest -> (
      let idx =
        match num with
        | `Int i -> i
        | `Int64 i -> Int64.to_int i
        | `Big_int z -> Z.to_int z
        | `Float f -> Float.to_int f
        | _ -> 0
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

let keys ~ctx (json : Json.t) =
  match json with
  | `Assoc list -> `List (List.map (fun (k, _) -> `String k) list)
  | `List l ->
      let len = List.length l in
      `List (List.init len (fun i -> `Int64 (Int64.of_int i)))
  | _ -> fail_invalid_type ~ctx "keys" json

let builtins_list () =
  `List (List.map (fun s -> `String s) (Language.all_function_names ()))

let tm_to_array (tm : Unix.tm) (is_dst : bool) : Json.t =
  `List
    [
      `Int64 (Int64.of_int tm.tm_sec);
      `Int64 (Int64.of_int tm.tm_min);
      `Int64 (Int64.of_int tm.tm_hour);
      `Int64 (Int64.of_int tm.tm_mday);
      `Int64 (Int64.of_int tm.tm_mon);
      `Int64 (Int64.of_int tm.tm_year);
      `Int64 (Int64.of_int tm.tm_wday);
      `Int64 (Int64.of_int tm.tm_yday);
      `Int64 (if is_dst then 1L else 0L);
    ]

let json_to_int = function
  | `Int n -> Some n
  | `Int64 n -> Some (Int64.to_int n)
  | `Big_int z -> Some (Z.to_int z)
  | _ -> None

let localtime ~ctx json =
  match json with
  | `Float f ->
      let tm = Unix.localtime f in
      tm_to_array tm tm.tm_isdst
  | `Int n ->
      let tm = Unix.localtime (Float.of_int n) in
      tm_to_array tm tm.tm_isdst
  | `Int64 n ->
      let tm = Unix.localtime (Int64.to_float n) in
      tm_to_array tm tm.tm_isdst
  | _ -> fail_invalid_type ~ctx "localtime" json

let gmtime ~ctx json =
  match json with
  | `Float f ->
      let tm = Unix.gmtime f in
      tm_to_array tm false
  | `Int n ->
      let tm = Unix.gmtime (Float.of_int n) in
      tm_to_array tm false
  | `Int64 n ->
      let tm = Unix.gmtime (Int64.to_float n) in
      tm_to_array tm false
  | _ -> fail_invalid_type ~ctx "gmtime" json

let mktime ~ctx json =
  match json with
  | `List [ sec; min; hour; mday; mon; year; _; _; isdst ] -> (
      match
        ( json_to_int sec,
          json_to_int min,
          json_to_int hour,
          json_to_int mday,
          json_to_int mon,
          json_to_int year,
          json_to_int isdst )
      with
      | ( Some sec,
          Some min,
          Some hour,
          Some mday,
          Some mon,
          Some year,
          Some isdst ) ->
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
      | _ ->
          Runtime_error.invalid_argument ~fn:"mktime"
            ~expected:
              "array of 9 integers [sec, min, hour, mday, mon, year, wday, \
               yday, isdst]"
            ~found:"array with non-integer elements")
  | `List _ ->
      Runtime_error.invalid_argument ~fn:"mktime"
        ~expected:
          "array of 9 integers [sec, min, hour, mday, mon, year, wday, yday, \
           isdst]"
        ~found:"array with wrong length"
  | _ -> fail_invalid_type ~ctx "mktime" json

let debug json =
  let str =
    Json.to_string_pretty ~colorize:false ~summarize:false ~raw:false json
  in
  Printf.eprintf "[\"DEBUG:\", %s]\n%!" str;
  yield json

let stderr json =
  match json with
  | `String s ->
      Printf.eprintf "%s\n%!" s;
      yield json
  | _ ->
      let str =
        Json.to_string_pretty ~colorize:false ~summarize:false ~raw:false json
      in
      Printf.eprintf "%s\n%!" str;
      yield json

let has ~ctx (json : Json.t) key =
  match key with
  | String key -> (
      match json with
      | `Assoc list -> `Bool (List.mem_assoc key list)
      | _ -> fail_invalid_type ~ctx "has" json)
  | Int n -> (
      match json with
      | `List list -> `Bool (List.length list - 1 >= n)
      | _ -> fail_invalid_type ~ctx "has" json)
  | Int64 n -> (
      match json with
      | `List list -> `Bool (List.length list - 1 >= Int64.to_int n)
      | _ -> fail_invalid_type ~ctx "has" json)
  | Big_int n -> (
      match json with
      | `List list -> `Bool (List.length list - 1 >= Z.to_int n)
      | _ -> fail_invalid_type ~ctx "has" json)
  | Float n -> (
      match json with
      | `List list -> `Bool (List.length list - 1 >= Int.of_float n)
      | _ -> fail_invalid_type ~ctx "has" json)
  | _ -> fail_invalid_type ~ctx "has" json

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

let length ~ctx (json : Json.t) =
  let utf8_codepoint_length s =
    (* count the number of Unicode codepoints in a UTF-8 encoded string *)
    let byte_len = String.length s in
    let rec count i n =
      if i >= byte_len then n
      else
        let decode = String.get_utf_8_uchar s i in
        let len = Uchar.utf_decode_length decode in
        count (i + len) (n + 1)
    in
    count 0 0
  in
  match json with
  | `List list -> `Int64 (Int64.of_int (List.length list))
  | `String s -> `Int64 (Int64.of_int (utf8_codepoint_length s))
  | `Assoc obj -> `Int64 (Int64.of_int (List.length obj))
  | `Null -> `Int64 0L
  | `Int n -> `Int64 (Int64.of_int (abs n))
  | `Int64 n -> `Int64 (Int64.abs n)
  | `Big_int z -> `Big_int (Z.abs z)
  | `Float f -> `Float (Float.abs f)
  | _ -> fail_invalid_type ~ctx "length" json

let byte_length ~ctx (json : Json.t) =
  match json with
  | `String s ->
      (* OCaml strings are byte arrays *)
      `Int64 (Int64.of_int (String.length s))
  | _ -> fail_invalid_type ~ctx "byte_length" json

let type_selector ~ctx:_ type_name json =
  (* filter input to only yield if it matches the type *)
  if Json.type_of json = type_name then yield json

let iterables_selector ~ctx:_ json =
  match json with `List _ | `Assoc _ -> yield json | _ -> ()

let scalars_selector ~ctx:_ json =
  match json with `List _ | `Assoc _ -> () | _ -> yield json

let values_selector ~ctx:_ json =
  match json with `Null -> () | _ -> yield json

let math_fn ~ctx fn name json =
  match json with
  | `Float f -> `Float (fn f)
  | `Int n -> `Float (fn (Float.of_int n))
  | `Int64 n -> `Float (fn (Int64.to_float n))
  | `Big_int z -> `Float (fn (Z.to_float z))
  | _ -> fail_invalid_type ~ctx name json

let abs_op ~ctx json =
  match json with
  | `Float f -> `Float (Float.abs f)
  | `Int n -> `Int64 (Int64.of_int (abs n))
  | `Int64 n -> `Int64 (Int64.abs n)
  | `Big_int z -> `Big_int (Z.abs z)
  | _ -> fail_invalid_type ~ctx "abs" json

let ceil_op ~ctx json =
  match json with
  | `Float f -> `Int64 (Int64.of_float (Float.ceil f))
  | `Int n -> `Int64 (Int64.of_int n)
  | `Int64 n -> `Int64 n
  | `Big_int z -> `Big_int z
  | _ -> fail_invalid_type ~ctx "ceil" json

let round_op ~ctx json =
  match json with
  | `Float f -> `Int64 (Int64.of_float (Float.round f))
  | `Int n -> `Int64 (Int64.of_int n)
  | `Int64 n -> `Int64 n
  | `Big_int z -> `Big_int z
  | _ -> fail_invalid_type ~ctx "round" json

let is_normal_op ~ctx json =
  match json with
  | `Float f -> `Bool (Float.is_finite f && not (Float.is_nan f))
  | `Int _ | `Int64 _ | `Big_int _ -> `Bool true
  | _ -> fail_invalid_type ~ctx "is_normal" json

let logb_op ~ctx json =
  match json with
  | `Float f -> `Float (Float.log2 (Float.abs f) |> Float.floor)
  | `Int n -> `Float (Float.log2 (Float.abs (Float.of_int n)) |> Float.floor)
  | `Int64 n -> `Float (Float.log2 (Float.abs (Int64.to_float n)) |> Float.floor)
  | `Big_int z -> `Float (Float.log2 (Float.abs (Z.to_float z)) |> Float.floor)
  | _ -> fail_invalid_type ~ctx "logb" json

let floor ~ctx (json : Json.t) =
  match json with
  | `Float f -> `Int64 (Int64.of_float (floor f))
  | `Int n -> `Int64 (Int64.of_int n)
  | `Int64 n -> `Int64 n
  | `Big_int z -> `Big_int z
  | _ -> fail_invalid_type ~ctx "floor" json

let sqrt ~ctx (json : Json.t) =
  match json with
  | `Float f -> `Float (sqrt f)
  | `Int n -> `Float (sqrt (Float.of_int n))
  | `Int64 n -> `Float (sqrt (Int64.to_float n))
  | `Big_int z -> `Float (sqrt (Z.to_float z))
  | _ -> fail_invalid_type ~ctx "sqrt" json

let to_number ~ctx (json : Json.t) =
  match json with
  | `String s -> (
      (* try to parse as Int64 first, then fall back to float *)
      match Int64.of_string_opt s with
      | Some i -> `Int64 i
      | None -> (
          match Float.of_string_opt s with
          | Some f -> `Float f
          | None -> fail_invalid_type ~ctx "to_number" json))
  | `Int _ | `Int64 _ | `Big_int _ | `Float _ -> json
  | _ -> fail_invalid_type ~ctx "to_number" json

let to_string ~ctx:_ (json : Json.t) =
  match json with
  (* for strings, return as-is (no extra quotes) *)
  | `String s -> `String s
  | _ ->
      `String
        (Json.to_string_pretty ~colorize:false ~summarize:false ~raw:false json)

let min ~ctx (json : Json.t) =
  match json with
  | `List [] -> Runtime_error.empty_array "min"
  | `List l ->
      List.fold_left
        (fun acc x -> if Json.compare x acc < 0 then x else acc)
        (List.hd l) (List.tl l)
  | _ -> fail_invalid_type ~ctx "min" json

let max ~ctx (json : Json.t) =
  match json with
  | `List [] -> Runtime_error.empty_array "max"
  | `List l ->
      List.fold_left
        (fun acc x -> if Json.compare x acc > 0 then x else acc)
        (List.hd l) (List.tl l)
  | _ -> fail_invalid_type ~ctx "max" json

let flatten ~ctx depth (json : Json.t) =
  match json with
  | `List l ->
      let rec flatten_n n lst =
        if n <= 0 then lst
        else
          List.concat_map
            (fun item ->
              match item with
              | `List inner -> flatten_n (n - 1) inner
              | other -> [ other ])
            lst
      in
      `List (flatten_n depth l)
  | _ -> fail_invalid_type ~ctx "flatten" json

let sort ~ctx (json : Json.t) =
  match json with
  | `List l -> `List (List.sort Json.compare l)
  | _ -> fail_invalid_type ~ctx "sort" json

let unique ~ctx (json : Json.t) =
  match json with
  | `List l ->
      let rec unique acc = function
        | [] -> List.rev acc
        | x :: xs ->
            if List.mem x acc then unique acc xs else unique (x :: acc) xs
      in
      `List (unique [] l)
  | _ -> fail_invalid_type ~ctx "unique" json

let any ~ctx (json : Json.t) =
  match json with
  | `List l ->
      let is_truthy = function `Bool false | `Null -> false | _ -> true in
      `Bool (List.exists is_truthy l)
  | _ -> fail_invalid_type ~ctx "any" json

let all ~ctx (json : Json.t) =
  match json with
  | `List l ->
      let is_truthy = function `Bool false | `Null -> false | _ -> true in
      `Bool (List.for_all is_truthy l)
  | _ -> fail_invalid_type ~ctx "all" json

let to_entries ~ctx:_ (json : Json.t) =
  match json with
  | `Assoc obj ->
      let entries =
        List.map
          (fun (key, value) ->
            `Assoc [ ("key", `String key); ("value", value) ])
          obj
      in
      `List entries
  | _ -> Runtime_error.type_mismatch ~value:json "to_entries requires an object"

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
                    Runtime_error.type_mismatch ~value:json
                      "from_entries requires objects with 'key' (string) and \
                       'value' fields")
            | _ ->
                Runtime_error.type_mismatch ~value:json
                  "from_entries requires an array of objects")
      in
      `Assoc (convert [] entries)
  | _ -> fail_invalid_type ~ctx "from_entries" json

let to_codepoints ~ctx:_ (json : Json.t) =
  match json with
  | `String s ->
      let codepoints =
        List.init (String.length s) (fun i ->
            `Int64 (Int64.of_int (Char.code (String.get s i))))
      in
      `List codepoints
  | _ ->
      Runtime_error.type_mismatch ~value:json
        "to_codepoints expects a string, returns array of codepoints"

let from_codepoints ~ctx:_ (json : Json.t) =
  match json with
  | `List l ->
      let chars =
        List.map
          (function
            | `Int n -> Char.chr n
            | `Int64 n -> Char.chr (Int64.to_int n)
            | _ -> Char.chr 0)
          l
      in
      `String (String.of_seq (List.to_seq chars))
  | _ ->
      Runtime_error.type_mismatch ~value:json
        "from_codepoints expects an array of codepoints (numbers), returns a \
         string"

let is_nan ~ctx (json : Json.t) =
  match json with
  | `Float f -> `Bool (Float.is_nan f)
  | `Int _ | `Int64 _ | `Big_int _ -> `Bool false
  | _ -> fail_invalid_type ~ctx "is_nan" json

let get_envs () =
  (* TODO: Do I need to escape stuff here? *)
  try
    Unix.environment () |> Array.to_list
    |> List.filter_map (fun s ->
        match String.split_on_char '=' s with
        | k :: rest -> Some (k, `String (String.concat "=" rest))
        | [] -> None)
    (* Unix.environment is not available in js_of_ocaml, so we catch the failure *)
  with Failure _ -> []

let transpose ~ctx (json : Json.t) =
  match json with
  | `List [] -> `List []
  | `List rows ->
      let get_length row =
        match row with `List l -> Some (List.length l) | _ -> None
      in
      let lengths = List.filter_map get_length rows in
      if List.length lengths <> List.length rows then
        Runtime_error.type_mismatch ~value:json
          "transpose requires an array of arrays"
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
  | _ -> fail_invalid_type ~ctx "transpose" json

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

let descend_breadth_first json =
  let queue = Queue.create () in
  Queue.push json queue;
  let rec loop acc =
    if Queue.is_empty queue then List.rev acc
    else
      let current = Queue.pop queue in
      (match current with
      | `List items -> List.iter (fun item -> Queue.push item queue) items
      | `Assoc fields -> List.iter (fun (_, v) -> Queue.push v queue) fields
      | _ -> ());
      loop (current :: acc)
  in
  loop []

let descend_depth json =
  let rec descend acc current =
    let acc = current :: acc in
    match current with
    | `List items -> List.fold_left descend acc items
    | `Assoc fields -> List.fold_left (fun a (_, v) -> descend a v) acc fields
    | _ -> acc
  in
  List.rev (descend [] json)

let replace_regex ~ctx pattern replacement json =
  match json with
  | `String s -> (
      try
        let regex = Str.regexp pattern in
        `String (Str.replace_first regex replacement s)
      with _ -> json)
  | _ -> fail_invalid_type ~ctx "replace" json

let replace_all_regex ~ctx pattern replacement json =
  match json with
  | `String s -> (
      try
        let regex = Str.regexp pattern in
        `String (Str.global_replace regex replacement s)
      with _ -> json)
  | _ -> fail_invalid_type ~ctx "replace_all" json

let test_compiled_regex ~ctx (compiled : Ast.compiled_regex) json =
  match json with
  | `String s -> (
      try
        let _ = Str.search_forward compiled.regex s 0 in
        `Bool true
      with Not_found -> `Bool false)
  | _ -> fail_invalid_type ~ctx "test" json

let match_compiled_regex ~ctx (compiled : Ast.compiled_regex) json =
  match json with
  | `String s -> (
      try
        let _ = Str.search_forward compiled.regex s 0 in
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
              ("offset", `Int64 (Int64.of_int (Str.match_beginning ())));
              ("length", `Int64 (Int64.of_int (String.length matched)));
              ("string", `String matched);
              ( "captures",
                `List
                  (List.rev_map
                     (fun c ->
                       `Assoc
                         [
                           ("offset", `Int64 (-1L));
                           ("length", `Int64 (Int64.of_int (String.length c)));
                           ("string", `String c);
                           ("name", `Null);
                         ])
                     !captures) );
            ]
        in
        yield result
      with Not_found -> ())
  | _ -> fail_invalid_type ~ctx "match" json

let scan_compiled_regex ~ctx (compiled : Ast.compiled_regex) json =
  match json with
  | `String s ->
      let rec scan_all pos =
        try
          let _ = Str.search_forward compiled.regex s pos in
          let matched = Str.matched_string s in
          yield (`String matched);
          scan_all (Str.match_end ())
        with Not_found -> ()
      in
      scan_all 0
  | _ -> fail_invalid_type ~ctx "scan" json

let capture_compiled_regex ~ctx (compiled : Ast.compiled_regex) json =
  match json with
  | `String s -> (
      try
        let _ = Str.search_forward compiled.regex s 0 in
        let captures = ref [] in
        (try
           for i = 1 to 9 do
             captures := Str.matched_group i s :: !captures
           done
         with Not_found | Invalid_argument _ -> ());
        yield (`List (List.rev_map (fun c -> `String c) !captures))
      with Not_found -> yield (`List []))
  | _ -> fail_invalid_type ~ctx "capture" json

let split_sep ~ctx sep json =
  match json with
  | `String s ->
      let parts = Str.split_delim (Str.regexp_string sep) s in
      `List (List.map (fun p -> `String p) parts)
  | _ -> fail_invalid_type ~ctx "split" json

let join_sep ~ctx sep json =
  match json with
  | `List items ->
      let strings =
        List.filter_map
          (fun item ->
            match item with
            | `String s -> Some s
            | `Null -> None (* null values are filtered out *)
            | `Bool true -> Some "true"
            | `Bool false -> Some "false"
            | `Int i -> Some (Int.to_string i)
            | `Int64 i -> Some (Int64.to_string i)
            | `Big_int z -> Some (Z.to_string z)
            | `Float f ->
                if Float.is_integer f then Some (Int.to_string (Float.to_int f))
                else Some (Float.to_string f)
            | other ->
                Some
                  (Json.to_string_pretty other ~colorize:false ~summarize:false
                     ~raw:true))
          items
      in
      `String (String.concat sep strings)
  | _ -> fail_invalid_type ~ctx "join" json

let member ~ctx:_ (key : string) (json : Json.t) =
  match json with
  | `Assoc assoc -> (
      match List.assoc_opt key assoc with
      | Some value -> value
      | None -> Runtime_error.key_not_found ~key ~value:json)
  | `Null -> Runtime_error.null_access ~key ~value:json
  | _ ->
      Runtime_error.type_mismatch ~value:json
        ("Cannot index " ^ Json.type_of json ^ " with string \"" ^ key ^ "\"")

let iterator ~ctx (json : Json.t) =
  match json with
  | `List [] -> ()
  | `List items -> yield_many items
  | `Assoc obj -> List.iter (fun (_, x) -> yield x) obj
  | _ -> fail_invalid_type ~ctx "[]" json

let rec index ~ctx (indices : int list) (json : Json.t) =
  match indices with
  | [] -> iterator ~ctx json
  | [ value ] -> (
      match json with
      | `List list ->
          let len = List.length list in
          let actual_index = if value < 0 then len + value else value in
          if actual_index >= 0 && actual_index < len then
            yield (List.nth list actual_index)
          else
            Runtime_error.index_out_of_bounds ~index:value ~length:len
              ~value:json
      | _ -> fail_invalid_type ~ctx ("[" ^ Int.to_string value ^ "]") json)
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
      let rec slice_loop acc i = function
        | [] -> List.rev acc
        | x :: xs ->
            if i >= start && i < finish then slice_loop (x :: acc) (i + 1) xs
            else slice_loop acc (i + 1) xs
      in
      yield (`List (slice_loop [] 0 l))
  | _ ->
      fail_invalid_type ~ctx
        ("[" ^ Int.to_string start ^ ":" ^ Int.to_string finish ^ "]")
        json

let rec interp ~ctx expression json : unit =
  match expression with
  | Identity -> yield json
  | Fn0 f -> interp_fn0 ~ctx f json
  | Fn1 fn1 -> interp_fn1 ~ctx fn1 json
  | Fn2 (f, e1, e2) -> interp_fn2 ~ctx f e1 e2 json
  | Literal literal -> (
      match literal with
      | Bool b -> yield (`Bool b)
      | Int i -> yield (`Int i)
      | Int64 i -> yield (`Int64 i)
      | Big_int z -> yield (`Big_int z)
      | Float f -> yield (`Float f)
      | String s -> yield (`String s)
      | Null -> yield `Null)
  | Variable name -> variable ~ctx name
  | Env_var name -> (
      match Sys.getenv_opt name with
      | Some v -> yield (`String v)
      | None -> yield `Null)
  | Key key -> yield (member ~ctx key json)
  | Index idx -> index ~ctx idx json
  | Slice (start, finish) -> slice ~ctx start finish json
  | Pipe (left, right) -> pipe ~ctx left right json
  | Update (path_expr, transform) -> update ~ctx path_expr transform json
  | Alternative (left, right) -> alternative ~ctx left right json
  | Comma (left_expr, right_expr) ->
      interp ~ctx left_expr json;
      interp ~ctx right_expr json
  | Operation (left, op, right) -> operation ~ctx left right op json
  | Assign (path, value_expr) -> assign ~ctx path value_expr json
  | List None -> yield (`List [])
  | List (Some expr) ->
      let results = collect ~ctx expr json in
      yield (`List results)
  | Object [] -> yield (`Assoc [])
  | Object list -> objects ~ctx list json
  | Optional expr ->
      run (fun () -> interp ~ctx expr json) ~on_fail:(fun _ -> yield `Null) ()
  | Dynamic_access expr -> dynamic_access ~ctx expr json
  | Slice_expr (start_expr, end_expr) ->
      slice_expr ~ctx start_expr end_expr json
  | If_then_else (cond, if_branch, else_branch) ->
      if_then_else ~ctx cond if_branch else_branch json
  | Range (from_expr, upto_expr, step_expr) ->
      range_expr ~ctx from_expr upto_expr step_expr json
  | Reduce (expr, var_name, init_expr, update_expr) ->
      reduce ~ctx expr var_name init_expr update_expr json
  | Foreach (expr, var_name, init_expr, update_expr, extract_expr) ->
      foreach ~ctx expr var_name init_expr update_expr extract_expr json
  | As (expr, var_name, body) -> as_binding ~ctx expr var_name body json
  | Try (expr, handler, finally_expr) ->
      try_catch ~ctx expr handler finally_expr json
  | Fma (x_expr, y_expr, z_expr) -> fma_op ~ctx x_expr y_expr z_expr json
  | Fn (_, _, _) ->
      (* fn on its own (not in a Pipe). It shouldn't happen in well-formed programs *)
      yield json
  | Apply (fname, args) -> call_function ~ctx fname args json

and interp_fn0 ~ctx f json =
  match f with
  | Trim -> trim ~ctx json
  | To_uppercase -> to_uppercase ~ctx json
  | To_lowercase -> to_lowercase ~ctx json
  | To_codepoints -> yield (to_codepoints ~ctx json)
  | From_codepoints -> yield (from_codepoints ~ctx json)
  | Sort -> yield (sort ~ctx json)
  | Unique -> yield (unique ~ctx json)
  | Reverse -> (
      match json with
      | `List l -> yield (`List (List.rev l))
      | _ -> fail_invalid_type ~ctx "reverse" json)
  | Min -> yield (min ~ctx json)
  | Max -> yield (max ~ctx json)
  | First -> first_of_array ~ctx json
  | Last -> last_of_array ~ctx json
  | Add -> add_array ~ctx json
  | Any -> yield (any ~ctx json)
  | All -> yield (all ~ctx json)
  | Flatten -> yield (flatten ~ctx max_int json)
  | Combinations -> combinations ~ctx json
  | Transpose -> yield (transpose ~ctx json)
  | Keys -> yield (keys ~ctx json)
  | To_entries -> yield (to_entries ~ctx json)
  | From_entries -> yield (from_entries ~ctx json)
  | Type -> yield (`String (Json.type_of json))
  | To_string -> yield (to_string ~ctx json)
  | To_number -> yield (to_number ~ctx json)
  | Length -> yield (length ~ctx json)
  | Byte_length -> yield (byte_length ~ctx json)
  | Numbers -> type_selector ~ctx "number" json
  | Strings -> type_selector ~ctx "string" json
  | Objects -> type_selector ~ctx "object" json
  | Arrays -> type_selector ~ctx "array" json
  | Booleans -> type_selector ~ctx "boolean" json
  | Nulls -> type_selector ~ctx "null" json
  | Iterables -> iterables_selector ~ctx json
  | Scalars -> scalars_selector ~ctx json
  | Values -> values_selector ~ctx json
  | Floor -> yield (floor ~ctx json)
  | Sqrt -> yield (sqrt ~ctx json)
  | Abs -> yield (abs_op ~ctx json)
  | Ceil -> yield (ceil_op ~ctx json)
  | Round -> yield (round_op ~ctx json)
  | Sin -> yield (math_fn ~ctx Float.sin "sin" json)
  | Cos -> yield (math_fn ~ctx Float.cos "cos" json)
  | Tan -> yield (math_fn ~ctx Float.tan "tan" json)
  | Asin -> yield (math_fn ~ctx Float.asin "asin" json)
  | Acos -> yield (math_fn ~ctx Float.acos "acos" json)
  | Atan -> yield (math_fn ~ctx Float.atan "atan" json)
  | Sinh -> yield (math_fn ~ctx Float.sinh "sinh" json)
  | Cosh -> yield (math_fn ~ctx Float.cosh "cosh" json)
  | Tanh -> yield (math_fn ~ctx Float.tanh "tanh" json)
  | Asinh -> yield (math_fn ~ctx Float.asinh "asinh" json)
  | Acosh -> yield (math_fn ~ctx Float.acosh "acosh" json)
  | Atanh -> yield (math_fn ~ctx Float.atanh "atanh" json)
  | Log -> yield (math_fn ~ctx Float.log "log" json)
  | Log10 -> yield (math_fn ~ctx Float.log10 "log10" json)
  | Log2 -> yield (math_fn ~ctx Float.log2 "log2" json)
  | Exp -> yield (math_fn ~ctx Float.exp "exp" json)
  | Exp2 -> yield (math_fn ~ctx Float.exp2 "exp2" json)
  | Expm1 -> yield (math_fn ~ctx Float.expm1 "expm1" json)
  | Log1p -> yield (math_fn ~ctx Float.log1p "log1p" json)
  | Pow -> yield (math_fn ~ctx (fun x -> x ** 2.0) "pow" json)
  | Cube_root -> yield (math_fn ~ctx Float.cbrt "cube_root" json)
  | Truncate -> yield (math_fn ~ctx Float.trunc "truncate" json)
  | Is_normal -> yield (is_normal_op ~ctx json)
  | Is_nan -> yield (is_nan ~ctx json)
  | Nearbyint -> yield (math_fn ~ctx Float.round "nearbyint" json)
  | Logb -> yield (logb_op ~ctx json)
  | Infinite ->
      let rec infinite_gen n =
        yield (`Int64 n);
        infinite_gen (Int64.add n 1L)
      in
      infinite_gen 0L
  | Nan -> yield (`Float nan)
  | Now -> yield (`Float (Unix.gettimeofday ()))
  | Paths -> paths json
  | Leaf_paths -> leaf_paths json
  | Recurse -> yield_many (recurse_down json)
  | Recurse_down -> yield_many (recurse_down json)
  | Descend -> yield_many (descend_breadth_first json)
  | Dive -> yield_many (descend_depth json)
  | Empty -> ()
  | Not -> yield (Operators.not json)
  | Break -> break ()
  | Halt -> halt ()
  | Env -> yield (`Assoc (get_envs ()))
  | Debug -> debug json
  | Stderr -> stderr json
  | Builtins -> yield (builtins_list ())
  | Localtime -> yield (localtime ~ctx json)
  | Gmtime -> yield (gmtime ~ctx json)
  | Mktime -> yield (mktime ~ctx json)
  | Is_blank -> is_blank ~ctx json
  | Is_empty -> is_empty ~ctx Identity json

and interp_fn1 ~ctx fn1 json =
  match fn1 with
  | With_pattern (pattern_fn, compiled) -> (
      match pattern_fn with
      | Test -> yield (test_compiled_regex ~ctx compiled json)
      | Match -> match_compiled_regex ~ctx compiled json
      | Scan -> scan_compiled_regex ~ctx compiled json
      | Capture -> capture_compiled_regex ~ctx compiled json)
  | With_separator (sep_fn, sep) -> (
      match sep_fn with
      | Split -> yield (split_sep ~ctx sep json)
      | Join -> yield (join_sep ~ctx sep json))
  | With_expr (expr_fn, expr) -> (
      match expr_fn with
      | Map -> map ~ctx expr json
      | Map_values -> map_values ~ctx expr json
      | Flat_map -> flat_map ~ctx expr json
      | Select -> select ~ctx expr json
      | Sort_by -> sort_by ~ctx expr json
      | Group_by -> group_by ~ctx expr json
      | Unique_by -> unique_by ~ctx expr json
      | Min_by -> min_by ~ctx expr json
      | Max_by -> max_by ~ctx expr json
      | Find -> find ~ctx expr json
      | Some_ -> some ~ctx expr json
      | Any_cond -> any_with_condition ~ctx expr json
      | All_cond -> all_with_condition ~ctx expr json
      | Pluck -> pluck ~ctx expr json
      | Partition -> partition ~ctx expr json
      | Flatten_n ->
          collect ~ctx expr json
          |> List.iter (fun depth ->
              match depth with
              | `Int d -> yield (flatten ~ctx d json)
              | `Int64 d -> yield (flatten ~ctx (Int64.to_int d) json)
              | `Float f -> yield (flatten ~ctx (Int.of_float f) json)
              | _ ->
                  fail_invalid_type ~ctx "flatten: depth must be a number" depth)
      | Combinations_n -> combinations_n ~ctx expr json
      | Transpose_expr ->
          run
            (fun () -> interp ~ctx expr json)
            ~and_then:(fun json -> yield (transpose ~ctx json))
            ()
      | First_expr -> first_of_expr ~ctx expr json
      | Last_expr -> last_of_expr ~ctx expr json
      | Nth_array -> nth_array ~ctx expr json
      | Add_expr -> add_expr ~ctx expr json
      | Repeat -> repeat_expr ~ctx expr json
      | Binary_search -> binary_search ~ctx expr json
      | Has -> (
          match expr with
          | Literal ((String _ | Int _ | Int64 _ | Big_int _ | Float _) as lit)
            ->
              yield (has ~ctx json lit)
          | _ ->
              Runtime_error.invalid_argument ~fn:"has"
                ~expected:"string or number literal"
                ~found:(show_expression expr))
      | In -> in_ ~ctx json expr
      | With_entries -> with_entries ~ctx expr json
      | Delete -> del ~ctx expr json
      | Pick -> pick ~ctx expr json
      | Getpath -> getpath ~ctx expr json
      | Delpaths -> delpaths ~ctx expr json
      | Starts_with -> starts_with ~ctx expr json
      | Ends_with -> ends_with ~ctx expr json
      | Index_of -> index_of ~ctx expr json
      | Last_index_of -> last_index_of ~ctx expr json
      | Indices -> indices ~ctx expr json
      | Inside -> inside ~ctx expr json
      | Trim_start -> trim_start_impl ~ctx expr json
      | Trim_end -> trim_end_impl ~ctx expr json
      | Contains -> contains ~ctx expr json
      | Walk -> walk_tree ~ctx expr json
      | Path -> path_of ~ctx expr json
      | Paths_filter -> paths_filter ~ctx expr json
      | Recurse_expr ->
          let rec loop value =
            yield value;
            run
              (fun () -> interp ~ctx expr value)
              ~and_then:(fun next -> loop next)
              ()
          in
          loop json
      | Find_all -> find_all ~ctx expr json
      | Find_first -> find_first ~ctx expr json
      | Paths_to -> paths_to ~ctx expr json
      | Is_empty_expr -> is_empty ~ctx expr json
      | Error_msg -> error_msg ~ctx (Some expr) json
      | Halt_error_n -> (
          match collect ~ctx expr json with
          | [ `Int n ] -> halt ~code:n ()
          | [ `Int64 n ] -> halt ~code:(Int64.to_int n) ()
          | [ `Float f ] -> halt ~code:(Float.to_int f) ()
          | [ v ] ->
              Runtime_error.invalid_argument ~fn:"halt_error" ~expected:"number"
                ~found:(Json.type_of v)
          | _ ->
              Runtime_error.invalid_argument ~fn:"halt_error" ~expected:"number"
                ~found:"multiple values")
      | Debug_msg -> debug_msg ~ctx (Some expr) json
      | Assert_simple -> assert_ ~ctx expr None json)

and interp_fn2 ~ctx f e1 e2 json =
  match f with
  | Replace -> (
      match (e1, e2) with
      | Literal (String pattern), Literal (String replacement) ->
          yield (replace_regex ~ctx pattern replacement json)
      | _ ->
          Runtime_error.invalid_argument ~fn:"replace"
            ~expected:"string pattern and string replacement"
            ~found:"non-string arguments")
  | Replace_all -> (
      match (e1, e2) with
      | Literal (String pattern), Literal (String replacement) ->
          yield (replace_all_regex ~ctx pattern replacement json)
      | _ ->
          Runtime_error.invalid_argument ~fn:"replace_all"
            ~expected:"string pattern and string replacement"
            ~found:"non-string arguments")
  | While -> while_loop ~ctx e1 e2 json
  | Until -> until_loop ~ctx e1 e2 json
  | Limit -> (
      match collect ~ctx e1 json with
      | [ `Int n ] -> limit ~ctx n e2 json
      | [ `Int64 n ] -> limit ~ctx (Int64.to_int n) e2 json
      | [ `Float f ] -> limit ~ctx (Float.to_int f) e2 json
      | [ v ] ->
          Runtime_error.invalid_argument ~fn:"limit" ~expected:"number"
            ~found:(Json.type_of v)
      | _ ->
          Runtime_error.invalid_argument ~fn:"limit" ~expected:"number"
            ~found:"multiple values")
  | Skip -> (
      match collect ~ctx e1 json with
      | [ `Int n ] -> skip ~ctx n e2 json
      | [ `Int64 n ] -> skip ~ctx (Int64.to_int n) e2 json
      | [ `Float f ] -> skip ~ctx (Float.to_int f) e2 json
      | [ v ] ->
          Runtime_error.invalid_argument ~fn:"skip" ~expected:"number"
            ~found:(Json.type_of v)
      | _ ->
          Runtime_error.invalid_argument ~fn:"skip" ~expected:"number"
            ~found:"multiple values")
  | Recurse_with ->
      let results = recurse_with_cond ~ctx e1 e2 json in
      yield_many results
  | Any_gen -> any_with_generator ~ctx e1 e2 json
  | All_gen -> all_with_generator ~ctx e1 e2 json
  | Assert_msg -> assert_ ~ctx e1 (Some e2) json
  | Raise -> raise_error ~ctx e1 e2 json
  | Setpath -> setpath ~ctx e1 e2 json
  | Nth -> nth ~ctx e1 e2 json
  | Atan2 -> atan2_op ~ctx e1 e2 json
  | Copysign -> copysign_op ~ctx e1 e2 json
  | Ldexp -> ldexp_op ~ctx e1 e2 json
  | Fdim -> fdim_op ~ctx e1 e2 json
  | Remainder -> remainder_op ~ctx e1 e2 json
  | Scalbn -> scalbn_op ~ctx e1 e2 json
  | Pow2 -> pow2_op ~ctx e1 e2 json

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
      | `List items, `Int64 idx ->
          let idx = Int64.to_int idx in
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
          Runtime_error.invalid_argument ~fn:"index"
            ~expected:"array with number index or object with string key"
            ~found:(Json.type_of json ^ " with " ^ Json.type_of key_or_idx))

and update ~ctx path_expr transform json =
  (* path |= f means: for each path selected by path_expr, apply f to the value and update *)
  (* try to get existing paths *)
  let paths = collect ~ctx (Fn1 (With_expr (Path, path_expr))) json in
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
        | `Int n -> Some n
        | `Int64 n -> Some (Int64.to_int n)
        | `Float f -> Some (Float.to_int f)
        | _ -> None)
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
              List.iter (fun i -> yield (`Int64 (Int64.of_int i))) vals)
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
  | Fn (name, params, body) ->
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
  | _ -> fail_invalid_type ~ctx "map" json

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
  | _ -> fail_invalid_type ~ctx "map_values" json

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
  | _ -> fail_invalid_type ~ctx "sort_by" json

and min_by ~ctx expr json =
  match json with
  | `List [] -> Runtime_error.empty_array "min_by"
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
  | _ -> fail_invalid_type ~ctx "min_by" json

and max_by ~ctx expr json =
  match json with
  | `List [] -> Runtime_error.empty_array "max_by"
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
  | _ -> fail_invalid_type ~ctx "max_by" json

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
  | _ -> fail_invalid_type ~ctx "unique_by" json

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
              Runtime_error.invalid_argument ~fn:"object"
                ~expected:"string key for shorthand syntax"
                ~found:"non-string expression")
      | Some expr -> collect ~ctx expr json
    in
    List.concat_map
      (fun k ->
        match k with
        | `String k_str -> List.map (fun v -> (k_str, v)) values_res
        | _ ->
            Runtime_error.invalid_argument ~fn:"object" ~expected:"string key"
              ~found:(Json.type_of k))
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
  | `List _ -> Runtime_error.empty_array "flat_map"
  | _ -> fail_invalid_type ~ctx "flat_map" json

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
  | _ -> fail_invalid_type ~ctx "find" json

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
  | _ -> fail_invalid_type ~ctx "some" json

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
  | _ -> fail_invalid_type ~ctx "any" json

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
  | _ -> fail_invalid_type ~ctx "all" json

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
             (function
               | `String s -> `String s
               | `Int i -> `Int i
               | `Int64 i -> `Int64 i
               | _ -> `Null)
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
              Runtime_error.invalid_argument ~fn:"reduce"
                ~expected:"single value from update expression"
                ~found:"multiple values")
        ();
      yield !acc
  | _ ->
      Runtime_error.invalid_argument ~fn:"reduce"
        ~expected:"single value from init expression" ~found:"multiple values"

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
              Runtime_error.invalid_argument ~fn:"foreach"
                ~expected:"single value from update expression"
                ~found:"multiple values");
          let extract_res = collect ~ctx:new_ctx extract_expr !acc in
          List.iter yield extract_res)
        ()
  | _ ->
      Runtime_error.invalid_argument ~fn:"foreach"
        ~expected:"single value from init expression" ~found:"multiple values"

and in_ ~ctx json expr =
  match collect ~ctx expr json with
  | [ container ] -> (
      match (json, container) with
      | `Int n, `List l -> yield (`Bool (n >= 0 && n < List.length l))
      | `String key, `Assoc list -> yield (`Bool (List.mem_assoc key list))
      | _ -> fail_invalid_type ~ctx "in" json)
  | _ ->
      Runtime_error.invalid_argument ~fn:"in" ~expected:"single container"
        ~found:"multiple values"

and variable ~ctx var_name =
  if var_name = "ENV" then
    let env_pairs = get_envs () in
    yield (`Assoc env_pairs)
  else
    match List.assoc_opt var_name ctx.env with
    | Some value -> yield value
    | None ->
        Runtime_error.invalid_argument ~fn:"variable"
          ~expected:"defined variable" ~found:("undefined $" ^ var_name)

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
      | v -> fail_invalid_type ~ctx "if condition should be a bool" v)
    ()

and call_function ~ctx fname args json =
  match List.assoc_opt fname ctx.fns with
  | None -> Runtime_error.undefined_function ~name:fname
  | Some { params; body } ->
      if List.length params <> List.length args then
        Runtime_error.invalid_argument ~fn:fname
          ~expected:(Int.to_string (List.length params) ^ " arguments")
          ~found:(Int.to_string (List.length args) ^ " arguments")
      else
        (* separate value params ($x) from filter params (x) *)
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
        (* substitute filter params in body *)
        let new_body = substitute_params filter_params filter_args body in
        (* evaluate value params and bind them as variables (strip the $ prefix for env lookup) *)
        let value_bindings =
          List.map2
            (fun param arg ->
              let var_name = String.sub param 1 (String.length param - 1) in
              let values = collect ~ctx arg json in
              match values with
              | [ v ] -> (var_name, v)
              | [] -> (var_name, `Null)
              | _ ->
                  Runtime_error.invalid_argument ~fn:fname
                    ~expected:("single value for parameter " ^ param)
                    ~found:"multiple values")
            value_params value_args
        in
        let new_ctx = { ctx with env = value_bindings @ ctx.env } in
        interp ~ctx:new_ctx new_body json

and starts_with ~ctx expr json =
  collect ~ctx expr json
  |> List.iter (fun pattern ->
      match (json, pattern) with
      | `String s, `String prefix ->
          yield (`Bool (String.starts_with ~prefix s))
      | `String _, other ->
          Runtime_error.invalid_argument ~fn:"starts_with"
            ~expected:"string prefix" ~found:(Json.type_of other)
      | _ ->
          Runtime_error.invalid_argument ~fn:"starts_with" ~expected:"string"
            ~found:(Json.type_of json))

and ends_with ~ctx expr json =
  collect ~ctx expr json
  |> List.iter (fun pattern ->
      match (json, pattern) with
      | `String s, `String suffix -> yield (`Bool (String.ends_with ~suffix s))
      | `String _, other ->
          Runtime_error.invalid_argument ~fn:"ends_with"
            ~expected:"string suffix" ~found:(Json.type_of other)
      | _ ->
          Runtime_error.invalid_argument ~fn:"ends_with" ~expected:"string"
            ~found:(Json.type_of json))

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
  | _ -> fail_invalid_type ~ctx "to_entries failed" json

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
        (* every element in needle must be contained by some element in haystack *)
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
  | _ ->
      Runtime_error.invalid_argument ~fn:"contains" ~expected:"single value"
        ~found:"multiple values"

and index_of ~ctx expr json =
  let yield_opt = function
    | Some p -> yield (`Int64 (Int64.of_int p))
    | None -> yield `Null
  in
  collect ~ctx expr json
  |> List.iter (fun needle ->
      match (json, needle) with
      | `String haystack, `String needle ->
          yield_opt (Search.string_first haystack needle)
      | `List haystack, `List sublist ->
          yield_opt (Search.sublist_first haystack sublist)
      | `List haystack, needle ->
          yield_opt (Search.element_first haystack needle)
      | _ -> fail_invalid_type ~ctx "index" json)

and last_index_of ~ctx expr json =
  let yield_opt = function
    | Some p -> yield (`Int64 (Int64.of_int p))
    | None -> yield `Null
  in
  collect ~ctx expr json
  |> List.iter (fun needle ->
      match (json, needle) with
      | `String haystack, `String needle ->
          yield_opt (Search.string_last haystack needle)
      | `List haystack, `List sublist ->
          yield_opt (Search.sublist_last haystack sublist)
      | `List haystack, needle ->
          yield_opt (Search.element_last haystack needle)
      | _ -> fail_invalid_type ~ctx "last_index" json)

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
      | _ -> fail_invalid_type ~ctx "indices" json)

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
      | _ -> fail_invalid_type ~ctx "inside" json)

and trim_start_impl ~ctx expr json =
  collect ~ctx expr json
  |> List.iter (fun prefix ->
      match (json, prefix) with
      | `String s, `String prefix ->
          if String.starts_with ~prefix s then
            let prefix_len = String.length prefix in
            yield
              (`String (String.sub s prefix_len (String.length s - prefix_len)))
          else yield json
      | `String _, other ->
          Runtime_error.invalid_argument ~fn:"trim_start"
            ~expected:"string prefix" ~found:(Json.type_of other)
      | _ ->
          Runtime_error.invalid_argument ~fn:"trim_start" ~expected:"string"
            ~found:(Json.type_of json))

and trim_end_impl ~ctx expr json =
  collect ~ctx expr json
  |> List.iter (fun suffix ->
      match (json, suffix) with
      | `String s, `String suffix ->
          if String.ends_with ~suffix s then
            let suffix_len = String.length suffix in
            yield (`String (String.sub s 0 (String.length s - suffix_len)))
          else yield json
      | `String _, other ->
          Runtime_error.invalid_argument ~fn:"trim_end"
            ~expected:"string suffix" ~found:(Json.type_of other)
      | _ ->
          Runtime_error.invalid_argument ~fn:"trim_end" ~expected:"string"
            ~found:(Json.type_of json))

and trim ~ctx json =
  match json with
  | `String s -> yield (`String (String.trim s))
  | _ -> fail_invalid_type ~ctx "trim" json

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
  | _ -> fail_invalid_type ~ctx "combinations" json

and combinations_n ~ctx expr json =
  (* combinations(n): generates n-way combinations from input array *)
  match (json, collect ~ctx expr json) with
  | `List arr, [ n_val ] ->
      let n =
        match n_val with
        | `Float f -> Float.to_int f
        | `Int i -> i
        | `Int64 i -> Int64.to_int i
        | _ -> 0
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
  | _ ->
      Runtime_error.invalid_argument ~fn:"combinations"
        ~expected:"array input and number n" ~found:"invalid arguments"

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

and add_array ~ctx json =
  match json with
  | `List [] -> yield `Null
  | `List (first :: rest) ->
      let sum =
        List.fold_left (fun acc el -> Operators.add ~ctx acc el) first rest
      in
      yield sum
  | _ -> fail_invalid_type ~ctx "add" json

and add_expr ~ctx expr json =
  match collect ~ctx expr json with
  | [] -> yield `Null
  | first :: rest ->
      let sum = List.fold_left (Operators.add ~ctx) first rest in
      yield sum

and to_uppercase ~ctx json =
  match json with
  | `String s -> yield (`String (String.uppercase_ascii s))
  | _ -> fail_invalid_type ~ctx "to_uppercase" json

and to_lowercase ~ctx json =
  match json with
  | `String s -> yield (`String (String.lowercase_ascii s))
  | _ -> fail_invalid_type ~ctx "to_lowercase" json

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
          yield (`Int64 (Int64.of_int (search 0 len))))
  | _ -> fail_invalid_type ~ctx "binary_search" json

and first_of_array ~ctx json =
  match json with
  | `List [] -> Runtime_error.empty_array "first"
  | `List (hd :: _) -> yield hd
  | _ -> fail_invalid_type ~ctx "first" json

and first_of_expr ~ctx expr json =
  match collect ~ctx expr json with
  | [] ->
      Runtime_error.empty_result ~op:"first"
        ~suggestion:"Use first? for optional access" ()
  | hd :: _ -> yield hd

and last_of_array ~ctx json =
  match json with
  | `List [] -> Runtime_error.empty_array "last"
  | `List l -> yield (List.hd (List.rev l))
  | _ -> fail_invalid_type ~ctx "last" json

and last_of_expr ~ctx expr json =
  match collect ~ctx expr json with
  | [] ->
      Runtime_error.empty_result ~op:"last"
        ~suggestion:"Use last? for optional access" ()
  | l -> yield (List.hd (List.rev l))

and nth ~ctx n_expr expr json =
  let n_results = collect ~ctx n_expr json in
  let n_opt =
    match n_results with
    | [ `Int n ] -> Some n
    | [ `Int64 n ] -> Some (Int64.to_int n)
    | [ `Float f ] -> Some (Int.of_float f)
    | _ -> None
  in
  match n_opt with
  | Some n ->
      let results = collect ~ctx expr json in
      let len = List.length results in
      if n >= 0 && n < len then yield (List.nth results n)
      else Runtime_error.index_out_of_bounds ~index:n ~length:len ~value:json
  | None -> fail_invalid_type ~ctx "nth: first argument must be a number" json

and nth_array ~ctx n_expr json =
  let n_results = collect ~ctx n_expr json in
  let n_opt =
    match n_results with
    | [ `Int n ] -> Some n
    | [ `Int64 n ] -> Some (Int64.to_int n)
    | [ `Float f ] -> Some (Int.of_float f)
    | _ -> None
  in
  match (n_opt, json) with
  | Some n, `List items ->
      let len = List.length items in
      let actual_n = if n < 0 then len + n else n in
      if actual_n >= 0 && actual_n < len then yield (List.nth items actual_n)
      else Runtime_error.index_out_of_bounds ~index:n ~length:len ~value:json
  | Some _, _ -> fail_invalid_type ~ctx "nth" json
  | None, _ -> fail_invalid_type ~ctx "nth: argument must be a number" json

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
                match key with
                | `String s -> s
                | `Int n -> Int.to_string n
                | `Int64 n -> Int64.to_string n
                | `Float f ->
                    if Float.is_integer f then Int.to_string (Float.to_int f)
                    else Float.to_string f
                | `Bool b -> Bool.to_string b
                | `Null -> "null"
                | _ ->
                    Json.to_string_pretty ~colorize:false ~summarize:false
                      ~raw:true key
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
            | Some items -> (key_str, `List (List.rev items))
            | None -> (key_str, `List []))
          sorted_keys
      in
      yield (`Assoc result)
  | _ -> fail_invalid_type ~ctx "group_by" json

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

and json_to_float_opt = function
  | `Float f -> Some f
  | `Int n -> Some (Float.of_int n)
  | `Int64 n -> Some (Int64.to_float n)
  | _ -> None

and json_to_int_opt = function
  | `Int n -> Some n
  | `Int64 n -> Some (Int64.to_int n)
  | `Float f -> Some (Float.to_int f)
  | _ -> None

and atan2_op ~ctx y_expr x_expr json =
  let y_vals = collect ~ctx y_expr json in
  let x_vals = collect ~ctx x_expr json in
  match (y_vals, x_vals) with
  | [ y ], [ x ] -> (
      match (json_to_float_opt y, json_to_float_opt x) with
      | Some yf, Some xf -> yield (`Float (Float.atan2 yf xf))
      | _ ->
          Runtime_error.invalid_argument ~fn:"atan2" ~expected:"two numbers"
            ~found:(Json.type_of y ^ " and " ^ Json.type_of x))
  | _ ->
      Runtime_error.invalid_argument ~fn:"atan2" ~expected:"two single values"
        ~found:"multiple values"

and copysign_op ~ctx x_expr y_expr json =
  let x_vals = collect ~ctx x_expr json in
  let y_vals = collect ~ctx y_expr json in
  match (x_vals, y_vals) with
  | [ x ], [ y ] -> (
      match (json_to_float_opt x, json_to_float_opt y) with
      | Some xf, Some yf -> yield (`Float (Float.copy_sign xf yf))
      | _ ->
          Runtime_error.invalid_argument ~fn:"copysign" ~expected:"two numbers"
            ~found:(Json.type_of x ^ " and " ^ Json.type_of y))
  | _ ->
      Runtime_error.invalid_argument ~fn:"copysign"
        ~expected:"two single values" ~found:"multiple values"

and ldexp_op ~ctx m_expr e_expr json =
  let m_vals = collect ~ctx m_expr json in
  let e_vals = collect ~ctx e_expr json in
  match (m_vals, e_vals) with
  | [ m ], [ e ] -> (
      match (json_to_float_opt m, json_to_int_opt e) with
      | Some mf, Some ei -> yield (`Float (Float.ldexp mf ei))
      | _ ->
          Runtime_error.invalid_argument ~fn:"ldexp" ~expected:"two numbers"
            ~found:(Json.type_of m ^ " and " ^ Json.type_of e))
  | _ ->
      Runtime_error.invalid_argument ~fn:"ldexp" ~expected:"two single values"
        ~found:"multiple values"

and fdim_op ~ctx x_expr y_expr json =
  let x_vals = collect ~ctx x_expr json in
  let y_vals = collect ~ctx y_expr json in
  match (x_vals, y_vals) with
  | [ x ], [ y ] -> (
      match (json_to_float_opt x, json_to_float_opt y) with
      | Some xf, Some yf -> yield (`Float (Float.max 0.0 (xf -. yf)))
      | _ ->
          Runtime_error.invalid_argument ~fn:"fdim" ~expected:"two numbers"
            ~found:(Json.type_of x ^ " and " ^ Json.type_of y))
  | _ ->
      Runtime_error.invalid_argument ~fn:"fdim" ~expected:"two single values"
        ~found:"multiple values"

and remainder_op ~ctx x_expr y_expr json =
  let x_vals = collect ~ctx x_expr json in
  let y_vals = collect ~ctx y_expr json in
  match (x_vals, y_vals) with
  | [ x ], [ y ] -> (
      match (json_to_float_opt x, json_to_float_opt y) with
      | Some xf, Some yf -> yield (`Float (mod_float xf yf))
      | _ ->
          Runtime_error.invalid_argument ~fn:"remainder" ~expected:"two numbers"
            ~found:(Json.type_of x ^ " and " ^ Json.type_of y))
  | _ ->
      Runtime_error.invalid_argument ~fn:"remainder"
        ~expected:"two single values" ~found:"multiple values"

and scalbn_op ~ctx x_expr n_expr json =
  let x_vals = collect ~ctx x_expr json in
  let n_vals = collect ~ctx n_expr json in
  match (x_vals, n_vals) with
  | [ x ], [ n ] -> (
      match (json_to_float_opt x, json_to_int_opt n) with
      | Some xf, Some ni -> yield (`Float (Float.ldexp xf ni))
      | _ ->
          Runtime_error.invalid_argument ~fn:"scalbn" ~expected:"two numbers"
            ~found:(Json.type_of x ^ " and " ^ Json.type_of n))
  | _ ->
      Runtime_error.invalid_argument ~fn:"scalbn" ~expected:"two single values"
        ~found:"multiple values"

and pow2_op ~ctx x_expr y_expr json =
  let x_vals = collect ~ctx x_expr json in
  let y_vals = collect ~ctx y_expr json in
  match (x_vals, y_vals) with
  | [ x ], [ y ] -> (
      match (json_to_float_opt x, json_to_float_opt y) with
      | Some xf, Some yf -> yield (`Float (xf ** yf))
      | _ ->
          Runtime_error.invalid_argument ~fn:"pow" ~expected:"two numbers"
            ~found:(Json.type_of x ^ " and " ^ Json.type_of y))
  | _ ->
      Runtime_error.invalid_argument ~fn:"pow" ~expected:"two single values"
        ~found:"multiple values"

and fma_op ~ctx x_expr y_expr z_expr json =
  let x_vals = collect ~ctx x_expr json in
  let y_vals = collect ~ctx y_expr json in
  let z_vals = collect ~ctx z_expr json in
  match (x_vals, y_vals, z_vals) with
  | [ x ], [ y ], [ z ] -> (
      match (json_to_float_opt x, json_to_float_opt y, json_to_float_opt z) with
      | Some xf, Some yf, Some zf -> yield (`Float (Float.fma xf yf zf))
      | _ ->
          Runtime_error.invalid_argument ~fn:"fma" ~expected:"three numbers"
            ~found:
              (Json.type_of x ^ ", " ^ Json.type_of y ^ ", " ^ Json.type_of z))
  | _ ->
      Runtime_error.invalid_argument ~fn:"fma" ~expected:"three single values"
        ~found:"multiple values"

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

and try_catch ~ctx expr handler finally_expr json =
  let run_finally () =
    match finally_expr with
    | None -> ()
    | Some cleanup -> ignore (collect ~ctx cleanup json)
  in
  let error_occurred = ref false in
  let handle_error error_json input_for_handler =
    error_occurred := true;
    (match handler with
    | None -> yield `Null (* try without catch returns null on error *)
    | Some handler_expr ->
        let ctx_with_error =
          { ctx with env = ("error", error_json) :: ctx.env }
        in
        interp ~ctx:ctx_with_error handler_expr input_for_handler);
    run_finally ()
  in
  let try_handler : unit Effect.Deep.effect_handler =
    {
      effc =
        (fun (type a) (eff : a Effect.t) ->
          match eff with
          | User_error value ->
              Some
                (fun (_ : (a, _) Effect.Deep.continuation) ->
                  let error_json =
                    `Assoc
                      [
                        ("kind", `String "user_error");
                        ("message", `String (Json.to_string value));
                        ("value", value);
                      ]
                  in
                  handle_error error_json value)
          | Runtime_error.Fail err ->
              Some
                (fun (_ : (a, _) Effect.Deep.continuation) ->
                  handle_error
                    (Runtime_error.to_json err)
                    (Runtime_error.to_json err))
          | _ -> None);
    }
  in
  Effect.Deep.try_with (fun () -> interp ~ctx expr json) () try_handler;
  if not !error_occurred then run_finally ()

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
      | _ ->
          Runtime_error.invalid_argument ~fn:"error" ~expected:"single value"
            ~found:"multiple values")

and raise_error ~ctx kind_expr msg_expr json =
  let kind =
    match collect ~ctx kind_expr json with
    | [ `String k ] -> k
    | [ v ] ->
        Runtime_error.invalid_argument ~fn:"raise" ~expected:"string kind"
          ~found:(Json.type_of v)
    | _ ->
        Runtime_error.invalid_argument ~fn:"raise" ~expected:"string kind"
          ~found:"multiple values"
  in
  let message =
    match collect ~ctx msg_expr json with
    | [ `String m ] -> m
    | [ v ] ->
        Runtime_error.invalid_argument ~fn:"raise" ~expected:"string message"
          ~found:(Json.type_of v)
    | _ ->
        Runtime_error.invalid_argument ~fn:"raise" ~expected:"string message"
          ~found:"multiple values"
  in
  Runtime_error.custom ~kind ~value:json message

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
    | [] -> `Null (* path points to root, delete returns null *)
    | [ `String key ] -> (
        match value with
        | `Assoc fields -> `Assoc (List.filter (fun (k, _) -> k <> key) fields)
        | _ -> value)
    | [ ((`Int _ | `Int64 _ | `Big_int _ | `Float _) as num) ] -> (
        let idx =
          match num with
          | `Int i -> i
          | `Int64 i -> Int64.to_int i
          | `Big_int z -> Z.to_int z
          | `Float f -> Float.to_int f
          | _ -> 0
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
    | ((`Int _ | `Int64 _ | `Big_int _ | `Float _) as num) :: rest -> (
        let idx =
          match num with
          | `Int i -> i
          | `Int64 i -> Int64.to_int i
          | `Big_int z -> Z.to_int z
          | `Float f -> Float.to_int f
          | _ -> 0
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
  | [ v ] ->
      Runtime_error.invalid_argument ~fn:"delpaths" ~expected:"array of paths"
        ~found:(Json.type_of v)
  | _ ->
      Runtime_error.invalid_argument ~fn:"delpaths" ~expected:"array of paths"
        ~found:"multiple values"

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
  | [ v ] ->
      Runtime_error.invalid_argument ~fn:"getpath" ~expected:"array path"
        ~found:(Json.type_of v)
  | _ ->
      Runtime_error.invalid_argument ~fn:"getpath" ~expected:"array path"
        ~found:"multiple values"

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
        | ((`Int _ | `Int64 _ | `Big_int _ | `Float _) as num) :: rest -> (
            let idx =
              match num with
              | `Int i -> i
              | `Int64 i -> Int64.to_int i
              | `Big_int z -> Z.to_int z
              | `Float f -> Float.to_int f
              | _ -> 0
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
                (* create array with nulls up to idx, then set value at idx *)
                let arr =
                  List.init (idx + 1) (fun i ->
                      if i = idx then set_at `Null rest else `Null)
                in
                `List arr
            | _ -> value)
        | _ :: rest -> set_at value rest
      in
      yield (set_at json path_components)
  | [ p ], [ _ ] ->
      Runtime_error.invalid_argument ~fn:"setpath" ~expected:"array path"
        ~found:(Json.type_of p)
  | _ ->
      Runtime_error.invalid_argument ~fn:"setpath"
        ~expected:"(path_array, value)" ~found:"wrong number of arguments"

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
        (* for dynamic access like .[$var], evaluate to get the key/index *)
        let keys = collect ~ctx inner json in
        List.filter_map
          (function
            | `String s -> Some [ `String s ]
            | `Int i -> Some [ `Int i ]
            | `Int64 i -> Some [ `Int64 i ]
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
    | `Int64 idx :: rest -> (
        match value with
        | `List items ->
            let idx = Int64.to_int idx in
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
                  | `String s -> `String s
                  | `Int i -> `Int i
                  | `Int64 i -> `Int64 i
                  | _ -> `Null)
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
    | [ `Int64 n ] -> Int64.to_int n
    | [ `Float f ] -> Float.to_int f
    | _ -> failwith "slice index must evaluate to a number"
  in
  let start = Option.map eval_to_int start_expr in
  let finish = Option.map eval_to_int end_expr in
  slice ~ctx start finish json

and assign ~ctx path value_expr json =
  (* assignment updates a path in the JSON structure *)
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

and pluck ~ctx expr json =
  match json with
  | `List items ->
      let results =
        List.map
          (fun item ->
            let values =
              run_and_collect_results (fun () ->
                  run
                    (fun () -> interp ~ctx expr item)
                    ~and_then:(fun v -> yield v)
                    ~on_fail:(fun _ -> yield `Null)
                    ())
            in
            match values with [ v ] -> v | [] -> `Null | vs -> `List vs)
          items
      in
      yield (`List results)
  | _ -> fail_invalid_type ~ctx "pluck" json

and partition ~ctx expr json =
  match json with
  | `List items ->
      let matching = ref [] in
      let non_matching = ref [] in
      List.iter
        (fun item ->
          let results = collect ~ctx expr item in
          let is_truthy = function `Bool false | `Null -> false | _ -> true in
          if List.exists is_truthy results then matching := item :: !matching
          else non_matching := item :: !non_matching)
        items;
      yield
        (`List [ `List (List.rev !matching); `List (List.rev !non_matching) ])
  | _ -> fail_invalid_type ~ctx "partition" json

and is_empty ~ctx expr json =
  (* with argument: check if expression produces no output (jq semantics) *)
  (* when expr is Identity, this behaves like the 0-arg version *)
  match expr with
  | Identity -> (
      (* no argument: check if the value itself is empty *)
      match json with
      | `Null -> yield (`Bool true)
      | `List [] -> yield (`Bool true)
      | `List _ -> yield (`Bool false)
      | `Assoc [] -> yield (`Bool true)
      | `Assoc _ -> yield (`Bool false)
      | `String "" -> yield (`Bool true)
      | `String _ -> yield (`Bool false)
      | _ -> fail_invalid_type ~ctx "is_empty" json)
  | _ -> (
      (* with argument: check if expression produces no output (jq semantics) *)
      match collect ~ctx expr json with
      | [] -> yield (`Bool true)
      | _ -> yield (`Bool false))

and is_blank ~ctx json =
  match json with
  | `Null -> yield (`Bool true)
  | `List [] -> yield (`Bool true)
  | `List _ -> yield (`Bool false)
  | `Assoc [] -> yield (`Bool true)
  | `Assoc _ -> yield (`Bool false)
  | `String "" -> yield (`Bool true)
  | `String s ->
      let is_whitespace c = c = ' ' || c = '\t' || c = '\n' || c = '\r' in
      let all_whitespace = String.to_seq s |> Seq.for_all is_whitespace in
      yield (`Bool all_whitespace)
  | _ -> fail_invalid_type ~ctx "is_blank" json

and assert_ ~ctx cond_expr msg_expr json =
  let results = collect ~ctx cond_expr json in
  let is_truthy = function `Bool false | `Null -> false | _ -> true in
  if List.exists is_truthy results then yield json
  else
    let message =
      match msg_expr with
      | Some expr -> (
          match collect ~ctx expr json with
          | [ `String s ] -> s
          | [ v ] -> Json.to_string v
          | _ -> "assertion failed")
      | None -> "assertion failed"
    in
    Runtime_error.assertion_error ~value:json message

and debug_msg ~ctx msg_expr json =
  let debug_output =
    match msg_expr with
    | Some expr -> (
        match collect ~ctx expr json with
        | [ `String s ] ->
            Printf.eprintf "[debug] %s: %s\n%!" s (Json.to_string json);
            ()
        | [ v ] ->
            Printf.eprintf "[debug] %s: %s\n%!" (Json.to_string v)
              (Json.to_string json);
            ()
        | _ ->
            Printf.eprintf "[debug] %s\n%!" (Json.to_string json);
            ())
    | None ->
        Printf.eprintf "[debug] %s\n%!" (Json.to_string json);
        ()
  in
  debug_output;
  yield json

and collect_safe ~ctx expr json =
  let results = ref [] in
  let failed = ref false in
  run
    (fun () -> interp ~ctx expr json)
    ~and_then:(fun v -> results := v :: !results)
    ~on_fail:(fun _ -> failed := true)
    ();
  if !failed then [] else List.rev !results

and find_all ~ctx cond_expr json =
  let all_values = descend_breadth_first json in
  let matches =
    List.concat_map
      (fun value ->
        let results = collect_safe ~ctx cond_expr value in
        match results with
        | [ `Bool true ] -> [ value ]
        | [ `Bool false ] | [ `Null ] | [] -> []
        | results -> List.filter (fun r -> r <> `Null) results)
      all_values
  in
  yield (`List matches)

and find_first ~ctx cond_expr json =
  let all_values = descend_depth json in
  let rec loop = function
    | [] -> yield `Null
    | value :: rest -> (
        let results = collect_safe ~ctx cond_expr value in
        match results with [ `Bool true ] -> yield value | _ -> loop rest)
  in
  loop all_values

and paths_to ~ctx cond_expr json =
  let rec collect_paths current_path current_value =
    let results = collect_safe ~ctx cond_expr current_value in
    let matches =
      match results with
      | [ `Bool true ] -> [ `List (List.rev current_path) ]
      | _ -> []
    in
    let child_matches =
      match current_value with
      | `List items ->
          List.concat
            (List.mapi
               (fun i item -> collect_paths (`Int i :: current_path) item)
               items)
      | `Assoc fields ->
          List.concat_map
            (fun (k, v) -> collect_paths (`String k :: current_path) v)
            fields
      | _ -> []
    in
    matches @ child_matches
  in
  let all_paths = collect_paths [] json in
  yield (`List all_paths)

let execute ~colorize ~verbose ?(env = []) expr json =
  let ctx = { colorize; verbose; env; fns = [] } in
  let format_error (err : Runtime_error.t) =
    let qerr =
      Error.runtime_error
        ~kind:(Runtime_error.kind_string err)
        ~message:(Runtime_error.message err)
        ?value:(Runtime_error.value err)
        ?suggestion:(Runtime_error.suggestion err)
        ()
    in
    Error.format ~colorize qerr
  in
  match collect ~ctx expr json with
  | results -> Ok results
  | effect Runtime_error.Fail err, _ -> Error (format_error err)
  | effect Break, _ ->
      let err =
        Error.context_error ~message:"break used outside of loop context"
      in
      Error (Error.format ~colorize err)
  | effect Halt exit_code, _ -> exit exit_code
  | exception e -> Error (Printexc.to_string e)
