type location = {
  input : string; (* the full query string *)
  start_pos : int; (* character offset *)
  end_pos : int; (* character offset *)
}

type context =
  | Json_value of Json.t
  | Expected of string
  | Found of string
  | Available_keys of string list
  | Example of string
  | Note of string

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
let with_suggestion s err = { err with suggestion = Some s }

let format_location ~colorize loc =
  let open Ansi.To_string (struct
    let colorize = colorize
  end) in
  let { input; start_pos; end_pos } = loc in
  let pointer_len = max 1 (end_pos - start_pos) in
  let pointer = String.make pointer_len '^' in
  let indent_space = String.make start_pos ' ' in
  Printf.sprintf "  %s %s\n      %s%s" (gray "-->") input indent_space
    (red pointer)

let format_context ~colorize ctx =
  let open Ansi.To_string (struct
    let colorize = colorize
  end) in
  match ctx with
  | Json_value json ->
      let json_str =
        Json.to_string_pretty ~colorize ~summarize:true ~raw:false json
      in
      Printf.sprintf "  %s %s" (gray "in:") json_str
  | Expected s -> Printf.sprintf "  %s %s" (gray "expected:") s
  | Found s -> Printf.sprintf "  %s %s" (gray "found:") s
  | Available_keys keys ->
      Printf.sprintf "  %s %s" (gray "available keys:")
        (String.concat ", " keys)
  | Example s -> Printf.sprintf "  %s %s" (gray "example:") s
  | Note s -> Printf.sprintf "  %s %s" (gray "note:") s

let format ~colorize err =
  let open Ansi.To_string (struct
    let colorize = colorize
  end) in
  let parts = ref [] in

  let header =
    Printf.sprintf "%s%s%s %s"
      (red (bold "error"))
      (red (Printf.sprintf "[%s]" err.kind))
      (red ":") err.message
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
  | Some s -> parts := !parts @ [ Printf.sprintf "  %s %s" (gray "hint:") s ]
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

let not_implemented feature =
  make ~kind:"not_implemented"
    ~message:(Printf.sprintf "`%s` is not implemented" feature)
    ()

let missing_argument ~fn_name ~usage ~description ?example () =
  let contexts =
    [ Note (Printf.sprintf "usage: `%s`" usage); Note description ]
  in
  let contexts =
    match example with Some ex -> contexts @ [ Example ex ] | None -> contexts
  in
  make ~kind:"missing_argument"
    ~message:(Printf.sprintf "`%s` requires an argument" fn_name)
    ~contexts ()

let empty_collection ~operation =
  make ~kind:"empty_collection"
    ~message:(Printf.sprintf "cannot apply `%s` to empty collection" operation)
    ()

let null_access ~key =
  make ~kind:"null_access"
    ~message:(Printf.sprintf "cannot access key `%s` on null" key)
    ~suggestion:"check if value exists before accessing" ()

let index_out_of_bounds ~index ~length =
  make ~kind:"index_out_of_bounds"
    ~message:
      (Printf.sprintf "index `%d` out of bounds (length: %d)" index length)
    ~suggestion:"use `.[index]?` for optional access" ()

let parse_error ~message ~input ~start_pos ~end_pos =
  make ~kind:"parse_error" ~message ~location:{ input; start_pos; end_pos } ()

let lexer_error ~message ~input ~start_pos ~end_pos =
  make ~kind:"lexer_error" ~message ~location:{ input; start_pos; end_pos } ()

let semantic_error ~message ~input ~start_pos ~end_pos =
  make ~kind:"semantic_error" ~message
    ~location:{ input; start_pos; end_pos }
    ()

let runtime_error ~kind ~message ?value ?suggestion () =
  let err = make ~kind ~message ?suggestion () in
  match value with Some v -> with_context (Json_value v) err | None -> err

let context_error ~message = make ~kind:"context_error" ~message ()

let json_error ~colorize ~message ?input ?start_pos ?end_pos () =
  match (input, start_pos, end_pos) with
  | Some input, Some start_pos, Some end_pos ->
      let err =
        make ~kind:"json" ~message ~location:{ input; start_pos; end_pos } ()
      in
      format ~colorize err
  | _ ->
      let err = make ~kind:"json" ~message () in
      format ~colorize err
