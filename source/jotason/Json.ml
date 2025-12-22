include T
include Read
include Write

let to_string_pretty json ~colorize ~summarize ~raw =
  match (raw, json) with
  | true, `String s -> s
  | _ -> Write.Pretty.to_string_colored ~colorize ~summarize json

let print_pretty (json : T.t) ~colorize ~summarize ~raw =
  match (raw, json) with
  | true, `String s -> print_endline s
  | _ -> Write.Pretty.print_colored ~colorize ~summarize json

let type_of (json : T.t) =
  match json with
  | `List _ -> "array"
  | `Assoc _ -> "object"
  | `Bool _ -> "boolean"
  | `Float _ | `Int _ | `Intlit _ | `Floatlit _ -> "number"
  | `Null -> "null"
  | `String _ | `Stringlit _ -> "string"

let rec equal (a : T.t) (b : T.t) : bool =
  match (a, b) with
  | `Int x, `Int y -> x = y
  | `Float x, `Float y -> x = y
  | `Int x, `Float y -> Float.of_int x = y
  | `Float x, `Int y -> x = Float.of_int y
  | `String x, `String y -> x = y
  | `Stringlit x, `Stringlit y -> x = y
  | `Intlit x, `Intlit y -> x = y
  | `Floatlit x, `Floatlit y -> x = y
  | `Bool x, `Bool y -> x = y
  | `Null, `Null -> true
  | `List xs, `List ys ->
      List.length xs = List.length ys && List.for_all2 equal xs ys
  | `Assoc xs, `Assoc ys ->
      let compare_keys (key, _) (key', _) = String.compare key key' in
      let xs = List.stable_sort compare_keys xs in
      let ys = List.stable_sort compare_keys ys in
      (match List.for_all2 (fun (key, value) (key', value') ->
        key = key' && equal value value') xs ys with
      | result -> result
      | exception Invalid_argument _ -> false)
  | _ -> false

let rec compare_list_with cmp xs ys =
  match (xs, ys) with
  | [], [] -> 0
  | [], _ -> -1
  | _, [] -> 1
  | x :: xs', y :: ys' ->
      let c = cmp x y in
      if c <> 0 then c else compare_list_with cmp xs' ys'

let rec compare (a : T.t) (b : T.t) : int =
  match (a, b) with
  | `Null, `Null -> 0
  | `Null, _ -> -1
  | _, `Null -> 1
  | `Bool x, `Bool y -> Bool.compare x y
  | `Bool _, _ -> -1
  | _, `Bool _ -> 1
  | `Int x, `Int y -> Int.compare x y
  | `Float x, `Float y -> Float.compare x y
  | `Int x, `Float y -> Float.compare (float_of_int x) y
  | `Float x, `Int y -> Float.compare x (float_of_int y)
  | (`Int _ | `Float _), _ -> -1
  | _, (`Int _ | `Float _) -> 1
  | `String x, `String y -> String.compare x y
  | `String _, _ -> -1
  | _, `String _ -> 1
  | `List xs, `List ys -> compare_list_with compare xs ys
  | `List _, _ -> -1
  | _, `List _ -> 1
  | `Assoc xs, `Assoc ys -> compare_assoc xs ys
  | `Intlit x, `Intlit y -> String.compare x y
  | `Intlit _, _ -> -1
  | _, `Intlit _ -> 1
  | _, _ -> -1

and compare_assoc xs ys =
  let keys_x = List.map fst xs |> List.sort String.compare in
  let keys_y = List.map fst ys |> List.sort String.compare in
  let key_cmp = compare_list_with String.compare keys_x keys_y in
  if key_cmp <> 0 then key_cmp
  else
    let rec compare_values = function
      | [] -> 0
      | k :: ks ->
          let c = compare (List.assoc k xs) (List.assoc k ys) in
          if c <> 0 then c else compare_values ks
    in
    compare_values keys_x

let rec contains (needle : T.t) (haystack : T.t) : bool =
  match (needle, haystack) with
  | `String n, `String h -> (
      try
        let _ = Str.search_forward (Str.regexp_string n) h 0 in
        true
      with Not_found -> false)
  | `List needles, `List hay ->
      List.for_all (fun n -> List.exists (fun h -> contains n h) hay) needles
  | `Assoc needle_obj, `Assoc hay_obj ->
      List.for_all
        (fun (k, v) ->
          match List.assoc_opt k hay_obj with
          | Some hv -> contains v hv
          | None -> false)
        needle_obj
  | _ -> equal needle haystack

let typerr msg js = raise (Json_error (msg ^ type_of js))

let to_assoc = function
  | `Assoc obj -> obj
  | js -> typerr "Expected object, got " js

let assoc name obj = try List.assoc name obj with Not_found -> `Null

let member name = function
  | `Assoc obj -> assoc name obj
  | js -> typerr ("Can't get member '" ^ name ^ "' of non-object type ") js

let keys o =
  to_assoc o |> List.map (fun (key, _) -> key)

let values o =
  to_assoc o |> List.map (fun (_, value) -> value)

exception Undefined of string * t

let index i = function
  | `List l as js ->
      let len = List.length l in
      let wrapped_index = if i < 0 then len + i else i in
      if wrapped_index < 0 || wrapped_index >= len then
        raise (Undefined ("Index " ^ string_of_int i ^ " out of bounds", js))
      else List.nth l wrapped_index
  | js ->
      typerr ("Can't get index " ^ string_of_int i ^ " of non-array type ") js
