type location = { input : string; start_pos : int; end_pos : int }

type context =
  | Json_value of Json.t
  | Expected of string
  | Found of string
  | Available_keys of string list
  | Example of string
  | Usage of string
  | Description of string
  | Applicable_to of string

type t = {
  kind : string;
  message : string;
  location : location option;
  contexts : context list;
  suggestion : string option;
}

let make ~kind ~message ?location ?(contexts = []) ?suggestion () =
  { kind; message; location; contexts; suggestion }

let with_location ~input ~start_pos ~end_pos err =
  { err with location = Some { input; start_pos; end_pos } }

let with_context ctx err = { err with contexts = ctx :: err.contexts }

let format_location ~colorize loc =
  let t = Console_style.make ~colorize in
  let { input; start_pos; end_pos } = loc in
  let pointer_len = max 1 (end_pos - start_pos) in
  let pointer = String.make pointer_len '^' in
  let indent_space = String.make start_pos ' ' in
  Printf.sprintf "  %s %s\n      %s%s" (t.blue "-->") input indent_space
    (t.red pointer)

let format_context ~colorize ctx =
  let t = Console_style.make ~colorize in
  match ctx with
  | Json_value json ->
      let json_str =
        Json.to_string_pretty ~colorize ~summarize:true ~raw:false json
      in
      Printf.sprintf "  %s %s" (t.gray "in:") json_str
  | Expected s -> Printf.sprintf "  %s %s" (t.gray "expected:") s
  | Found s -> Printf.sprintf "  %s %s" (t.gray "found:") s
  | Available_keys keys ->
      Printf.sprintf "  %s %s" (t.gray "available keys:")
        (String.concat ", " keys)
  | Example s -> Printf.sprintf "  %s %s" (t.gray "example:") s
  | Usage s -> Printf.sprintf "  %s %s" (t.gray "usage:") s
  | Description s -> Printf.sprintf "  %s" s
  | Applicable_to s -> Printf.sprintf "  %s %s" (t.gray "applicable to:") s

let format ~colorize err =
  let t = Console_style.make ~colorize in
  let parts = ref [] in

  let header =
    Printf.sprintf "%s%s%s %s"
      (t.red (t.bold "error"))
      (t.red (Printf.sprintf "[%s]" err.kind))
      (t.red ":") err.message
  in
  parts := [ header ];

  (match err.location with
  | Some loc -> parts := !parts @ [ format_location ~colorize loc ]
  | None -> ());

  let has_context = List.length err.contexts > 0 || err.suggestion <> None in
  if has_context then parts := !parts @ [ "" ];

  List.iter
    (fun ctx -> parts := !parts @ [ format_context ~colorize ctx ])
    err.contexts;

  (match err.suggestion with
  | Some s -> parts := !parts @ [ Printf.sprintf "  %s %s" (t.cyan "hint:") s ]
  | None -> ());

  String.concat "\n" !parts

let to_string err = err.message

let key_not_found ~key ~json ~available_keys =
  make ~kind:"key_not_found"
    ~message:(Printf.sprintf "key `%s` not found" key)
    ~contexts:[ Json_value json; Available_keys available_keys ]
    ~suggestion:(Printf.sprintf "use `.%s?` for optional access" key)
    ()

let type_mismatch ~operation ~expected ~actual_json =
  let actual_type = Json.type_of actual_json in
  make ~kind:"type_mismatch"
    ~message:(Printf.sprintf "cannot apply `%s` to %s" operation actual_type)
    ~contexts:[ Expected expected; Found actual_type; Json_value actual_json ]
    ()

let invalid_argument ~fn_name ~expected ~found ?example () =
  let contexts = [ Expected expected; Found found ] in
  let contexts =
    match example with Some ex -> contexts @ [ Example ex ] | None -> contexts
  in
  make ~kind:"invalid_argument"
    ~message:(Printf.sprintf "`%s()` received invalid argument" fn_name)
    ~contexts ()

let deprecated ~old_name ~new_name =
  make ~kind:"deprecated"
    ~message:(Printf.sprintf "`%s` is deprecated" old_name)
    ~suggestion:(Printf.sprintf "use `%s` instead" new_name)
    ()

let not_implemented ?suggestion ?description feature =
  let contexts =
    match description with Some d -> [ Description d ] | None -> []
  in
  make ~kind:"not_implemented"
    ~message:(Printf.sprintf "`%s` is not implemented" feature)
    ~contexts ?suggestion ()

let invalid_regex ~pattern =
  make ~kind:"invalid_regex"
    ~message:(Printf.sprintf "invalid regex pattern: `%s`" pattern)
    ()

let requires_literal ~fn_name ~what ~example =
  make ~kind:"invalid_argument"
    ~message:(Printf.sprintf "`%s` requires a string literal %s" fn_name what)
    ~contexts:[ Expected "string literal"; Example example ]
    ()

let requires_number_literal ~fn_name ~what ?example () =
  let contexts = [ Expected "number literal" ] in
  let contexts =
    match example with Some ex -> contexts @ [ Example ex ] | None -> contexts
  in
  make ~kind:"invalid_argument"
    ~message:(Printf.sprintf "`%s` %s" fn_name what)
    ~contexts ()

let unsupported ~fn_name ~message ?suggestion () =
  make ~kind:"invalid_argument"
    ~message:(Printf.sprintf "`%s` %s" fn_name message)
    ?suggestion ()

let missing_argument ~fn_name ?message ~usage ~description ?applicable_to
    ?example () =
  let msg =
    match message with
    | Some m -> m
    | None -> Printf.sprintf "`%s` requires an argument" fn_name
  in
  let contexts = [ Usage usage; Description description ] in
  let contexts =
    match applicable_to with
    | Some types -> contexts @ [ Applicable_to types ]
    | None -> contexts
  in
  let contexts =
    match example with Some ex -> contexts @ [ Example ex ] | None -> contexts
  in
  make ~kind:"missing_argument" ~message:msg ~contexts ()

let parse_error ~message ~input ~start_pos ~end_pos =
  make ~kind:"parse_error" ~message ~location:{ input; start_pos; end_pos } ()

let lexer_error ~message ~input ~start_pos ~end_pos =
  make ~kind:"lexer_error" ~message ~location:{ input; start_pos; end_pos } ()

let semantic_error ~message ~input ~start_pos ~end_pos =
  make ~kind:"semantic_error" ~message
    ~location:{ input; start_pos; end_pos }
    ()

let runtime_error ~kind ~message ?value ?suggestion ?expected ?found () =
  let err = make ~kind ~message ?suggestion () in
  let err =
    match value with Some v -> with_context (Json_value v) err | None -> err
  in
  let err =
    match expected with Some e -> with_context (Expected e) err | None -> err
  in
  match found with Some f -> with_context (Found f) err | None -> err

let context_error ~message = make ~kind:"context_error" ~message ()

exception Parse_exception of string * Lexing.position * Lexing.position
exception Rich_parse_exception of t * Lexing.position * Lexing.position

let raise_parse_exception err start_pos end_pos =
  raise (Rich_parse_exception (err, start_pos, end_pos))

module Runtime : sig
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
