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
  let line_text, col =
    let lines = String.split_on_char '\n' input in
    let rec find lines offset =
      match lines with
      | [] -> ("", max 0 (start_pos - offset))
      | [ line ] -> (line, max 0 (start_pos - offset))
      | line :: rest ->
          let next = offset + String.length line + 1 in
          if start_pos < next then (line, max 0 (start_pos - offset))
          else find rest next
    in
    find lines 0
  in
  let pointer_len = max 1 (end_pos - start_pos) in
  let pointer = String.make pointer_len '^' in
  let indent_space = String.make col ' ' in
  Printf.sprintf "  %s %s\n      %s%s" (t.blue "-->") line_text indent_space
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

exception Parse_error of t * Lexing.position * Lexing.position

let raise err start_pos end_pos = raise (Parse_error (err, start_pos, end_pos))
