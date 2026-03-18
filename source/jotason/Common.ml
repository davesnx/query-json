type decimal = { coeff : Z.t; scale : int; repr : string option }

module Decimal = struct
  type t = decimal

  let ten = Z.of_int 10
  let two = Z.of_int 2
  let five = Z.of_int 5

  let rec pow10 n =
    if n <= 0 then
      Z.one
    else if n = 1 then
      ten
    else
      let half = pow10 (n / 2) in
      let sq = Z.mul half half in
      if n mod 2 = 0 then
        sq
      else
        Z.mul sq ten

  let pow2 n =
    if n <= 0 then
      Z.one
    else
      Z.pow two n
  let pow5 n =
    if n <= 0 then
      Z.one
    else
      Z.pow five n

  let z_of_string_opt s = try Some (Z.of_string s) with _ -> None

  let normalize ?repr coeff scale =
    let rec trim c s =
      if s > 0 && Z.equal (Z.erem c ten) Z.zero then
        trim (Z.divexact c ten) (s - 1)
      else
        (c, s)
    in
    if Z.equal coeff Z.zero then
      { coeff = Z.zero; scale = 0; repr }
    else
      let coeff, scale = trim coeff scale in
      { coeff; scale; repr }

  let make ?repr coeff scale = normalize ?repr coeff scale
  let of_integer ?repr coeff = { coeff; scale = 0; repr }

  let parse_exponent s i len =
    if i >= len || (s.[i] <> 'e' && s.[i] <> 'E') then
      Some (0, i)
    else
      let j = ref (i + 1) in
      let exp_sign =
        if !j < len && s.[!j] = '+' then (
          incr j;
          1
        ) else if !j < len && s.[!j] = '-' then (
          incr j;
          -1
        ) else
          1
      in
      let exp_start = !j in
      while !j < len && s.[!j] >= '0' && s.[!j] <= '9' do
        incr j
      done;
      if !j = exp_start then
        None
      else
        Some
          ( exp_sign * int_of_string (String.sub s exp_start (!j - exp_start)),
            !j
          )

  let of_lexeme_opt s =
    let len = String.length s in
    if len = 0 then
      None
    else
      let i = ref 0 in
      let sign =
        if s.[!i] = '-' then (
          incr i;
          -1
        ) else if s.[!i] = '+' then (
          incr i;
          1
        ) else
          1
      in
      let int_start = !i in
      while !i < len && s.[!i] >= '0' && s.[!i] <= '9' do
        incr i
      done;
      let int_len = !i - int_start in
      if int_len = 0 then
        None
      else
        let frac_part =
          if !i < len && s.[!i] = '.' then (
            incr i;
            let frac_start = !i in
            while !i < len && s.[!i] >= '0' && s.[!i] <= '9' do
              incr i
            done;
            let frac_len = !i - frac_start in
            if frac_len = 0 then
              None
            else
              Some (String.sub s frac_start frac_len)
          ) else
            Some ""
        in
        match frac_part with
        | None ->
            None
        | Some frac_part -> (
            match parse_exponent s !i len with
            | None ->
                None
            | Some (exp, stop) -> (
                if stop <> len then
                  None
                else
                  let int_part = String.sub s int_start int_len in
                  let digits = int_part ^ frac_part in
                  match z_of_string_opt digits with
                  | None ->
                      None
                  | Some z ->
                      let coeff =
                        if sign < 0 then
                          Z.neg z
                        else
                          z
                      in
                      let scale = String.length frac_part - exp in
                      if Z.equal coeff Z.zero then
                        Some { coeff = Z.zero; scale = 0; repr = Some s }
                      else if scale >= 0 then
                        Some (normalize ~repr:s coeff scale)
                      else
                        Some (normalize ~repr:s (Z.mul coeff (pow10 (-scale))) 0)
              )
          )

  let of_lexeme_exn s =
    match of_lexeme_opt s with
    | Some d ->
        d
    | None ->
        invalid_arg ("invalid decimal literal: " ^ s)

  let to_string ?(preserve_repr = true) d =
    let canonical () =
      let abs_coeff = Z.abs d.coeff in
      let digits = Z.to_string abs_coeff in
      if d.scale = 0 then
        Z.to_string d.coeff
      else
        let len = String.length digits in
        let sign =
          if Z.sign d.coeff < 0 then
            "-"
          else
            ""
        in
        if len <= d.scale then
          sign ^ "0." ^ String.make (d.scale - len) '0' ^ digits
        else
          let int_part = String.sub digits 0 (len - d.scale) in
          let frac_part = String.sub digits (len - d.scale) d.scale in
          sign ^ int_part ^ "." ^ frac_part
    in
    if preserve_repr then
      match d.repr with Some s -> s | None -> canonical ()
    else
      canonical ()

  let to_float d = Float.of_string (to_string ~preserve_repr:false d)

  let compare a b =
    if a.scale = b.scale then
      Z.compare a.coeff b.coeff
    else if a.scale < b.scale then
      Z.compare (Z.mul a.coeff (pow10 (b.scale - a.scale))) b.coeff
    else
      Z.compare a.coeff (Z.mul b.coeff (pow10 (a.scale - b.scale)))

  let add a b =
    if a.scale = b.scale then
      normalize (Z.add a.coeff b.coeff) a.scale
    else if a.scale < b.scale then
      normalize
        (Z.add (Z.mul a.coeff (pow10 (b.scale - a.scale))) b.coeff)
        b.scale
    else
      normalize
        (Z.add a.coeff (Z.mul b.coeff (pow10 (a.scale - b.scale))))
        a.scale

  let sub a b =
    if a.scale = b.scale then
      normalize (Z.sub a.coeff b.coeff) a.scale
    else if a.scale < b.scale then
      normalize
        (Z.sub (Z.mul a.coeff (pow10 (b.scale - a.scale))) b.coeff)
        b.scale
    else
      normalize
        (Z.sub a.coeff (Z.mul b.coeff (pow10 (a.scale - b.scale))))
        a.scale

  let mul a b = normalize (Z.mul a.coeff b.coeff) (a.scale + b.scale)

  let div_exact_or_none a b =
    if Z.equal b.coeff Z.zero then
      None
    else
      let num = Z.mul a.coeff (pow10 b.scale) in
      let den = Z.mul b.coeff (pow10 a.scale) in
      let num, den =
        if Z.sign den < 0 then
          (Z.neg num, Z.neg den)
        else
          (num, den)
      in
      let gcd = Z.gcd num den in
      let num = Z.divexact num gcd in
      let den = Z.divexact den gcd in
      let rec count_factor n p count =
        if Z.equal (Z.erem n p) Z.zero then
          count_factor (Z.divexact n p) p (count + 1)
        else
          (count, n)
      in
      let c2, den = count_factor den two 0 in
      let c5, den = count_factor den five 0 in
      if not (Z.equal den Z.one) then
        None
      else
        let k = max c2 c5 in
        let coeff = Z.mul num (Z.mul (pow2 (k - c2)) (pow5 (k - c5))) in
        Some (normalize coeff k)
end

type t =
  [ `Null
  | `Bool of bool
  | `Int of int (* Small integers: 63-bit, fast arithmetic *)
  | `Int64 of int64 (* Large integers: 64-bit, for values outside int range *)
  | `Float of float (* Floating point *)
  | `Big_int of Z.t (* Huge integers: arbitrary precision *)
  | `Decimal of decimal (* Exact decimal / scientific notation numbers *)
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
  | `Int n ->
      Some (Float.of_int n)
  | `Int64 n ->
      Some (Int64.to_float n)
  | `Float n ->
      Some n
  | `Big_int z ->
      Some (Z.to_float z)
  | `Decimal d ->
      Some (Decimal.to_float d)
  | _ ->
      None

let to_decimal_exact (json : t) : decimal option =
  match json with
  | `Int n ->
      Some (Decimal.of_integer (Z.of_int n))
  | `Int64 n ->
      Some (Decimal.of_integer (Z.of_int64 n))
  | `Big_int z ->
      Some (Decimal.of_integer z)
  | `Decimal d ->
      Some d
  | _ ->
      None

(** Compare two JSON values for ordering (jq semantics) *)
let rec compare_values (a : t) (b : t) : int =
  match (a, b) with
  (* null < false < true < numbers < strings < arrays < objects *)
  | `Null, `Null ->
      0
  | `Null, _ ->
      -1
  | _, `Null ->
      1
  | `Bool false, `Bool false ->
      0
  | `Bool false, `Bool true ->
      -1
  | `Bool true, `Bool false ->
      1
  | `Bool true, `Bool true ->
      0
  | `Bool _, _ ->
      -1
  | _, `Bool _ ->
      1
  (* Numbers - compare numerically *)
  | ( (`Int _ | `Int64 _ | `Float _ | `Big_int _ | `Decimal _),
      (`Int _ | `Int64 _ | `Float _ | `Big_int _ | `Decimal _) ) -> (
      match (a, b) with
      | `Float af, _ -> (
          match to_float b with Some bf -> Float.compare af bf | None -> 0
        )
      | _, `Float bf -> (
          match to_float a with Some af -> Float.compare af bf | None -> 0
        )
      | _ -> (
          match (to_decimal_exact a, to_decimal_exact b) with
          | Some da, Some db ->
              Decimal.compare da db
          | _ ->
              0
        )
    )
  | (`Int _ | `Int64 _ | `Float _ | `Big_int _ | `Decimal _), _ ->
      -1
  | _, (`Int _ | `Int64 _ | `Float _ | `Big_int _ | `Decimal _) ->
      1
  (* Strings - lexicographic *)
  | `String sa, `String sb ->
      String.compare sa sb
  | `String _, _ ->
      -1
  | _, `String _ ->
      1
  (* Arrays - lexicographic element-wise *)
  | `List la, `List lb ->
      compare_lists la lb
  | `List _, _ ->
      -1
  | _, `List _ ->
      1
  (* Objects - compare by sorted keys then values *)
  | `Assoc aa, `Assoc ab ->
      compare_objects aa ab

and compare_lists la lb =
  match (la, lb) with
  | [], [] ->
      0
  | [], _ ->
      -1
  | _, [] ->
      1
  | x :: xs, y :: ys ->
      let c = compare_values x y in
      if c <> 0 then
        c
      else
        compare_lists xs ys

and compare_objects aa ab =
  let sort_fields = List.sort (fun (k1, _) (k2, _) -> String.compare k1 k2) in
  let sa = sort_fields aa in
  let sb = sort_fields ab in
  let rec cmp a b =
    match (a, b) with
    | [], [] ->
        0
    | [], _ ->
        -1
    | _, [] ->
        1
    | (k1, v1) :: rest1, (k2, v2) :: rest2 ->
        let kc = String.compare k1 k2 in
        if kc <> 0 then
          kc
        else
          let vc = compare_values v1 v2 in
          if vc <> 0 then
            vc
          else
            cmp rest1 rest2
  in
  cmp sa sb

(** Check if two JSON values are equal *)
let equal (a : t) (b : t) : bool = compare_values a b = 0
