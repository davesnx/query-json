type t =
  [ `Null
  | `Bool of bool
  | `Int of int (* Small integers: 63-bit, fast arithmetic *)
  | `Int64 of int64 (* Large integers: 64-bit, for values outside int range *)
  | `Float of float (* Floating point *)
  | `Big_int of Z.t (* Huge integers: arbitrary precision *)
  | `String of string
  | `Assoc of (string * t) list
  | `List of t list ]

exception Json_error of string

let json_error s = raise (Json_error s)

exception End_of_array
exception End_of_object
exception End_of_input

type lexer_state = {
  buf : Buffer.t; (* Buffer used to accumulate substrings *)
  mutable lnum : int; (* Current line number (starting from 1) *)
  mutable bol : int;
      (* Absolute position of the first character of the current line (starting from 0) *)
  mutable fname : string option; (* Name describing the input file *)
}

let init_lexer ?buf ?fname ?(lnum = 1) () =
  let buf = match buf with None -> Buffer.create 256 | Some buf -> buf in
  { buf; lnum; bol = 0; fname }

(** Get numeric value as float for comparison, None for non-numeric types *)
let to_float (json : t) : float option =
  match json with
  | `Int n -> Some (Float.of_int n)
  | `Int64 n -> Some (Int64.to_float n)
  | `Float n -> Some n
  | `Big_int z -> Some (Z.to_float z)
  | _ -> None

(** Compare two JSON values for ordering (jq semantics) *)
let rec compare_values (a : t) (b : t) : int =
  match (a, b) with
  (* null < false < true < numbers < strings < arrays < objects *)
  | `Null, `Null -> 0
  | `Null, _ -> -1
  | _, `Null -> 1
  | `Bool false, `Bool false -> 0
  | `Bool false, `Bool true -> -1
  | `Bool true, `Bool false -> 1
  | `Bool true, `Bool true -> 0
  | `Bool _, _ -> -1
  | _, `Bool _ -> 1
  (* Numbers - compare numerically *)
  | ( (`Int _ | `Int64 _ | `Float _ | `Big_int _),
      (`Int _ | `Int64 _ | `Float _ | `Big_int _) ) -> (
      match (to_float a, to_float b) with
      | Some na, Some nb -> Float.compare na nb
      | _ -> 0
    )
  | (`Int _ | `Int64 _ | `Float _ | `Big_int _), _ -> -1
  | _, (`Int _ | `Int64 _ | `Float _ | `Big_int _) -> 1
  (* Strings - lexicographic *)
  | `String sa, `String sb -> String.compare sa sb
  | `String _, _ -> -1
  | _, `String _ -> 1
  (* Arrays - lexicographic element-wise *)
  | `List la, `List lb -> compare_lists la lb
  | `List _, _ -> -1
  | _, `List _ -> 1
  (* Objects - compare by sorted keys then values *)
  | `Assoc aa, `Assoc ab -> compare_objects aa ab

and compare_lists la lb =
  match (la, lb) with
  | [], [] -> 0
  | [], _ -> -1
  | _, [] -> 1
  | x :: xs, y :: ys ->
      let c = compare_values x y in
      if c <> 0 then c else compare_lists xs ys

and compare_objects aa ab =
  let sort_fields = List.sort (fun (k1, _) (k2, _) -> String.compare k1 k2) in
  let sa = sort_fields aa in
  let sb = sort_fields ab in
  let rec cmp a b =
    match (a, b) with
    | [], [] -> 0
    | [], _ -> -1
    | _, [] -> 1
    | (k1, v1) :: rest1, (k2, v2) :: rest2 ->
        let kc = String.compare k1 k2 in
        if kc <> 0 then kc
        else
          let vc = compare_values v1 v2 in
          if vc <> 0 then vc else cmp rest1 rest2
  in
  cmp sa sb

(** Check if two JSON values are equal *)
let equal (a : t) (b : t) : bool = compare_values a b = 0
