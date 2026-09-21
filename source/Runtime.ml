open Ast

module Runtime_error = struct
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
    | Key_not_found ->
        "key_not_found"
    | Null_access ->
        "null_access"
    | Type_mismatch ->
        "type_mismatch"
    | Index_out_of_bounds ->
        "index_out_of_bounds"
    | Empty_array ->
        "empty_array"
    | Undefined_function ->
        "undefined_function"
    | Empty_result ->
        "empty_result"
    | Assertion_error ->
        "assertion_error"
    | Invalid_argument ->
        "invalid_argument"
    | Custom s ->
        s

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
      | Some s ->
          fields @ [ ("suggestion", `String s) ]
      | None ->
          fields
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
                && String.get k key_len = '-'
              )
              keys
          in
          match hyphenated_match with
          | Some hk ->
              Printf.sprintf
                "Did you mean \"%s\"? Use .[\"...\"] or .\"...\" for keys with \
                 hyphens"
                hk
          | None ->
              "Use ." ^ key ^ "? for optional access"
        )
      | _ ->
          "Use ." ^ key ^ "? for optional access"
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
     ^ Int.to_string length ^ " elements)"
      )

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
      | Some s ->
          Some s
      | None ->
          Some ("Use " ^ op ^ "? for optional access")
    in
    fail ~kind:Empty_result ?suggestion (op ^ ": empty expression result")

  let assertion_error ~value message =
    fail ~kind:Assertion_error ~value
      ~suggestion:"Check the condition in your assert() call" message

  let custom ~kind ~value message = fail ~kind:(Custom kind) ~value message

  let format ~colorize err =
    let qerr =
      Error.runtime_error ~kind:(kind_string err) ~message:(message err)
        ?value:(value err) ?suggestion:(suggestion err) ()
    in
    Error.format ~colorize qerr
end

let fail_invalid_type ~colorize op (json : Json.t) =
  let type_desc =
    match json with
    | `List _ | `Assoc _ ->
        "an " ^ Json.type_of json
    | `String _ ->
        "a " ^ Json.type_of json
    | `Bool _ ->
        "a boolean"
    | `Float _ | `Int _ | `Int64 _ | `Big_int _ | `Decimal _ ->
        "a number"
    | `Null ->
        "null"
  in
  let t = Console_style.make ~colorize in
  Runtime_error.type_mismatch ~value:json
    ("Cannot apply "
    ^ Console_style.single_quotes (t.bold op)
    ^ " to " ^ type_desc
    )

module Operators = struct
  let not (json : Json.t) =
    match json with `Bool false | `Null -> `Bool true | _ -> `Bool false

  let to_float = function
    | `Float f ->
        Some f
    | `Int n ->
        Some (Float.of_int n)
    | `Int64 n ->
        Some (Int64.to_float n)
    | `Big_int z ->
        Some (Z.to_float z)
    | `Decimal (d : Json.decimal) ->
        Some (Json.Decimal.to_float d)
    | _ ->
        None

  let exact_decimal_of_json = function
    | `Int n ->
        Some (Json.Decimal.of_integer (Z.of_int n))
    | `Int64 n ->
        Some (Json.Decimal.of_integer (Z.of_int64 n))
    | `Big_int z ->
        Some (Json.Decimal.of_integer z)
    | `Decimal (d : Json.decimal) ->
        Some d
    | _ ->
        None

  let z_int_min = Z.of_int Int.min_int
  let z_int_max = Z.of_int Int.max_int
  let z_int64_min = Z.of_int64 Int64.min_int
  let z_int64_max = Z.of_int64 Int64.max_int

  let json_of_integer_z z =
    if Z.compare z z_int_min >= 0 && Z.compare z z_int_max <= 0 then
      `Int (Z.to_int z)
    else if Z.compare z z_int64_min >= 0 && Z.compare z z_int64_max <= 0 then
      `Int64 (Z.to_int64 z)
    else
      `Big_int z

  let json_of_decimal (d : Json.decimal) =
    if d.scale = 0 then
      json_of_integer_z d.coeff
    else
      `Decimal d

  let add_exact l r = Json.Decimal.add l r |> json_of_decimal
  let sub_exact l r = Json.Decimal.sub l r |> json_of_decimal
  let mul_exact l r = Json.Decimal.mul l r |> json_of_decimal

  let add ~colorize str (left : Json.t) (right : Json.t) : Json.t =
    match (left, right) with
    | ( ((`Int _ | `Int64 _ | `Big_int _ | `Decimal _) as l),
        ((`Int _ | `Int64 _ | `Big_int _ | `Decimal _) as r) ) ->
        add_exact
          (Option.get (exact_decimal_of_json l))
          (Option.get (exact_decimal_of_json r))
    | `Float l, `Float r ->
        `Float (l +. r)
    | `Int l, `Float r ->
        `Float (Int.to_float l +. r)
    | `Float l, `Int r ->
        `Float (l +. Int.to_float r)
    | `Int64 l, `Float r ->
        `Float (Int64.to_float l +. r)
    | `Float l, `Int64 r ->
        `Float (l +. Int64.to_float r)
    | `Decimal l, `Float r ->
        `Float (Json.Decimal.to_float l +. r)
    | `Float l, `Decimal r ->
        `Float (l +. Json.Decimal.to_float r)
    | `Big_int l, `Float r ->
        `Float (Z.to_float l +. r)
    | `Float l, `Big_int r ->
        `Float (l +. Z.to_float r)
    | `String l, `String r ->
        `String (l ^ r)
    | `Assoc l_entries, `Assoc r_entries ->
        let updated_l =
          List.map
            (fun (k, v) ->
              match List.assoc_opt k r_entries with
              | Some v' ->
                  (k, v')
              | None ->
                  (k, v)
            )
            l_entries
        in
        let new_keys =
          List.filter
            (fun (k, _) -> Stdlib.not (List.mem_assoc k l_entries))
            r_entries
        in
        `Assoc (updated_l @ new_keys)
    | `List l, `List r ->
        `List (l @ r)
    | `Null, r ->
        Runtime_error.type_mismatch ~value:r
          ~suggestion:"Use (.x ?? 0) for explicit null handling"
          ("Cannot add null to " ^ Json.type_of r)
    | l, `Null ->
        Runtime_error.type_mismatch ~value:l
          ~suggestion:"Use (.x ?? 0) for explicit null handling"
          ("Cannot add " ^ Json.type_of l ^ " to null")
    | _ ->
        fail_invalid_type ~colorize str left

  let apply_float_operation ~colorize str fn (left : Json.t) (right : Json.t) =
    match (to_float left, to_float right) with
    | Some l, Some r ->
        `Float (fn l r)
    | _ ->
        fail_invalid_type ~colorize str left

  let compare str int_fn (left : Json.t) (right : Json.t) =
    match (left, right) with
    | ( (`Int _ | `Int64 _ | `Big_int _ | `Float _ | `Decimal _),
        (`Int _ | `Int64 _ | `Big_int _ | `Float _ | `Decimal _) ) ->
        `Bool (int_fn (Json.compare left right) 0)
    | _ ->
        Runtime_error.invalid_argument ~fn:str ~expected:"numbers"
          ~found:(Json.type_of left ^ " and " ^ Json.type_of right)

  let is_truthy (json : Json.t) : bool =
    match json with `Bool false | `Null -> false | _ -> true

  let add ~colorize = add ~colorize "+"

  let subtract ~colorize (left : Json.t) (right : Json.t) : Json.t =
    match (left, right) with
    | ( ((`Int _ | `Int64 _ | `Big_int _ | `Decimal _) as l),
        ((`Int _ | `Int64 _ | `Big_int _ | `Decimal _) as r) ) ->
        sub_exact
          (Option.get (exact_decimal_of_json l))
          (Option.get (exact_decimal_of_json r))
    | `Float l, `Float r ->
        `Float (l -. r)
    | `Int l, `Float r ->
        `Float (Int.to_float l -. r)
    | `Float l, `Int r ->
        `Float (l -. Int.to_float r)
    | `Int64 l, `Float r ->
        `Float (Int64.to_float l -. r)
    | `Float l, `Int64 r ->
        `Float (l -. Int64.to_float r)
    | `Decimal l, `Float r ->
        `Float (Json.Decimal.to_float l -. r)
    | `Float l, `Decimal r ->
        `Float (l -. Json.Decimal.to_float r)
    | `Big_int l, `Float r ->
        `Float (Z.to_float l -. r)
    | `Float l, `Big_int r ->
        `Float (l -. Z.to_float r)
    | `List l, `List r ->
        let in_r x = List.exists (fun y -> Json.equal x y) r in
        `List (List.filter (fun x -> Stdlib.not (in_r x)) l)
    | _ ->
        fail_invalid_type ~colorize "-" left

  let rec deep_merge (left : Json.t) (right : Json.t) : Json.t =
    match (left, right) with
    | `Assoc l_entries, `Assoc r_entries ->
        let updated_l =
          List.map
            (fun (k, v) ->
              match List.assoc_opt k r_entries with
              | Some r_val ->
                  (k, deep_merge v r_val)
              | None ->
                  (k, v)
            )
            l_entries
        in
        let new_keys =
          List.filter
            (fun (k, _) -> Stdlib.not (List.mem_assoc k l_entries))
            r_entries
        in
        `Assoc (updated_l @ new_keys)
    | _, r ->
        r

  let multiply ~colorize (left : Json.t) (right : Json.t) : Json.t =
    match (left, right) with
    | ( ((`Int _ | `Int64 _ | `Big_int _ | `Decimal _) as l),
        ((`Int _ | `Int64 _ | `Big_int _ | `Decimal _) as r) ) ->
        mul_exact
          (Option.get (exact_decimal_of_json l))
          (Option.get (exact_decimal_of_json r))
    | `Float l, `Float r ->
        `Float (l *. r)
    | `Int l, `Float r ->
        `Float (Int.to_float l *. r)
    | `Float l, `Int r ->
        `Float (l *. Int.to_float r)
    | `Int64 l, `Float r ->
        `Float (Int64.to_float l *. r)
    | `Float l, `Int64 r ->
        `Float (l *. Int64.to_float r)
    | `Decimal l, `Float r ->
        `Float (Json.Decimal.to_float l *. r)
    | `Float l, `Decimal r ->
        `Float (l *. Json.Decimal.to_float r)
    | `Big_int l, `Float r ->
        `Float (Z.to_float l *. r)
    | `Float l, `Big_int r ->
        `Float (l *. Z.to_float r)
    | `String s, `Int n ->
        if n <= 0 then
          `String ""
        else
          `String (String.concat "" (List.init n (fun _ -> s)))
    | `String s, `Int64 n ->
        let count = Int64.to_int n in
        if count <= 0 then
          `String ""
        else
          `String (String.concat "" (List.init count (fun _ -> s)))
    | `String s, `Float f ->
        let count = Int.of_float f in
        if count <= 0 then
          `String ""
        else
          `String (String.concat "" (List.init count (fun _ -> s)))
    | `String s, `Decimal d ->
        let count = Int.of_float (Json.Decimal.to_float d) in
        if count <= 0 then
          `String ""
        else
          `String (String.concat "" (List.init count (fun _ -> s)))
    | `Assoc _, `Assoc _ ->
        deep_merge left right
    | `Null, r | r, `Null ->
        r
    | _ ->
        fail_invalid_type ~colorize "*" left

  let is_zero_divisor (json : Json.t) =
    match json with
    | `Int 0 | `Int64 0L ->
        true
    | `Float f ->
        f = 0.0
    | `Big_int z ->
        Z.equal z Z.zero
    | `Decimal (d : Json.decimal) ->
        Z.equal d.coeff Z.zero
    | _ ->
        false

  let divide ~colorize (left : Json.t) (right : Json.t) : Json.t =
    if is_zero_divisor right then
      Runtime_error.invalid_argument ~fn:"divide" ~expected:"non-zero divisor"
        ~found:"zero";
    match (left, right) with
    | ( ((`Int _ | `Int64 _ | `Big_int _ | `Decimal _) as l),
        ((`Int _ | `Int64 _ | `Big_int _ | `Decimal _) as r) ) -> (
        let ld = Option.get (exact_decimal_of_json l) in
        let rd = Option.get (exact_decimal_of_json r) in
        let exact = Json.Decimal.div_exact_or_none ld rd in
        match exact with
        | Some d ->
            json_of_decimal d
        | None ->
            `Float (Json.Decimal.to_float ld /. Json.Decimal.to_float rd)
      )
    | `Float l, `Float r ->
        `Float (l /. r)
    | `Int l, `Float r ->
        `Float (Int.to_float l /. r)
    | `Float l, `Int r ->
        `Float (l /. Int.to_float r)
    | `Int64 l, `Float r ->
        `Float (Int64.to_float l /. r)
    | `Float l, `Int64 r ->
        `Float (l /. Int64.to_float r)
    | `Decimal l, `Float r ->
        `Float (Json.Decimal.to_float l /. r)
    | `Float l, `Decimal r ->
        `Float (l /. Json.Decimal.to_float r)
    | `String s, `String delim ->
        `List
          (Re.split_delim (Re.compile (Re.str delim)) s
          |> List.map (fun part -> `String part)
          )
    | _ ->
        fail_invalid_type ~colorize "/" left

  let modulo ~colorize (left : Json.t) (right : Json.t) : Json.t =
    match (left, right) with
    | `Big_int l, `Big_int r ->
        `Big_int (Z.rem l r)
    | `Big_int l, `Int r ->
        `Big_int (Z.rem l (Z.of_int r))
    | `Int l, `Big_int r ->
        `Big_int (Z.rem (Z.of_int l) r)
    | `Big_int l, `Int64 r ->
        `Big_int (Z.rem l (Z.of_int64 r))
    | `Int64 l, `Big_int r ->
        `Big_int (Z.rem (Z.of_int64 l) r)
    | `Big_int l, `Float r ->
        `Float (mod_float (Z.to_float l) r)
    | `Float l, `Big_int r ->
        `Float (mod_float l (Z.to_float r))
    | `Int64 l, `Int64 r ->
        `Int64 (Int64.rem l r)
    | `Int64 l, `Int r ->
        `Int64 (Int64.rem l (Int64.of_int r))
    | `Int l, `Int64 r ->
        `Int64 (Int64.rem (Int64.of_int l) r)
    | `Int l, `Int r ->
        `Int (l mod r)
    | ( ((`Int _ | `Int64 _ | `Big_int _ | `Decimal _) as l),
        ((`Int _ | `Int64 _ | `Big_int _ | `Decimal _) as r) ) ->
        let ld = Option.get (exact_decimal_of_json l) in
        let rd = Option.get (exact_decimal_of_json r) in
        if ld.scale = 0 && rd.scale = 0 then
          json_of_integer_z (Z.rem ld.coeff rd.coeff)
        else
          apply_float_operation ~colorize "%" mod_float left right
    | _ ->
        apply_float_operation ~colorize "%" mod_float left right

  let apply ~colorize (op : Ast.op) left right =
    match op with
    | Add ->
        add ~colorize left right
    | Subtract ->
        subtract ~colorize left right
    | Multiply ->
        multiply ~colorize left right
    | Divide ->
        divide ~colorize left right
    | Modulo ->
        modulo ~colorize left right
    | Greater_than ->
        compare ">" ( > ) left right
    | Greater_than_or_equal ->
        compare ">=" ( >= ) left right
    | Less_than ->
        compare "<" ( < ) left right
    | Less_than_or_equal ->
        compare "<=" ( <= ) left right
    | Equal ->
        `Bool (Json.equal left right)
    | Not_equal ->
        `Bool (Stdlib.not (Json.equal left right))
    | And ->
        `Bool (is_truthy left && is_truthy right)
    | Or ->
        `Bool (is_truthy left || is_truthy right)
end

let json_number_of_ast_number = function
  | Ast.Integer s -> (
      match int_of_string_opt s with
      | Some i ->
          `Int i
      | None -> (
          match Int64.of_string_opt s with
          | Some i ->
              `Int64 i
          | None ->
              `Big_int (Z.of_string s)
        )
    )
  | Ast.Decimal s ->
      `Decimal (Json.Decimal.of_lexeme_exn s)

let literal = function
  | Bool b ->
      `Bool b
  | Number n ->
      json_number_of_ast_number n
  | String s ->
      `String s
  | Null ->
      `Null

let member (key : string) (json : Json.t) =
  match json with
  | `Assoc assoc -> (
      match List.assoc_opt key assoc with
      | Some value ->
          value
      | None ->
          Runtime_error.key_not_found ~key ~value:json
    )
  | `Null ->
      Runtime_error.null_access ~key ~value:json
  | _ ->
      Runtime_error.type_mismatch ~value:json
        ("Cannot index " ^ Json.type_of json ^ " with string \"" ^ key ^ "\"")

let iterator ~colorize (json : Json.t) =
  match json with
  | `List items ->
      List.to_seq items
  | `Assoc obj ->
      Seq.map snd (List.to_seq obj)
  | _ ->
      fail_invalid_type ~colorize "[]" json

let index ~colorize value (json : Json.t) =
  match json with
  | `List list ->
      let len = List.length list in
      let actual_index =
        if value < 0 then
          len + value
        else
          value
      in
      if actual_index >= 0 && actual_index < len then
        List.nth list actual_index
      else
        Runtime_error.index_out_of_bounds ~index:value ~length:len ~value:json
  | _ ->
      fail_invalid_type ~colorize ("[" ^ Int.to_string value ^ "]") json

let map_inputs ~colorize (json : Json.t) =
  match json with
  | `List items ->
      items
  | _ ->
      fail_invalid_type ~colorize "map" json
