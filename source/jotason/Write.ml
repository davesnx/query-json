include Common

let hex n = Char.chr (if n < 10 then n + 48 else n + 87)

let write_special src start stop ob str =
  Buffer.add_substring ob src !start (stop - !start);
  Buffer.add_string ob str;
  start := stop + 1

let write_control_char src start stop ob c =
  Buffer.add_substring ob src !start (stop - !start);
  Buffer.add_string ob "\\u00";
  Buffer.add_char ob (hex (Char.code c lsr 4));
  Buffer.add_char ob (hex (Char.code c land 0xf));
  start := stop + 1

let finish_string src start ob =
  try Buffer.add_substring ob src !start (String.length src - !start)
  with exc ->
    Printf.eprintf "src=%S start=%i len=%i\n%!" src !start
      (String.length src - !start);
    raise exc

let write_string_body ob s =
  let start = ref 0 in
  for i = 0 to String.length s - 1 do
    match s.[i] with
    | '"' -> write_special s start i ob "\\\""
    | '\\' -> write_special s start i ob "\\\\"
    | '\b' -> write_special s start i ob "\\b"
    | '\012' -> write_special s start i ob "\\f"
    | '\n' -> write_special s start i ob "\\n"
    | '\r' -> write_special s start i ob "\\r"
    | '\t' -> write_special s start i ob "\\t"
    | ('\x00' .. '\x1F' | '\x7F') as c -> write_control_char s start i ob c
    | _ -> ()
  done;
  finish_string s start ob

let write_string ob s =
  Buffer.add_char ob '"';
  write_string_body ob s;
  Buffer.add_char ob '"'

let write_null ob () = Buffer.add_string ob "null"
let write_bool ob x = Buffer.add_string ob (if x then "true" else "false")
let dec n = Char.chr (n + 48)

let rec write_digits s x =
  if x = 0 then ()
  else
    let d = x mod 10 in
    write_digits s (x / 10);
    Buffer.add_char s (dec (abs d))

let write_int ob x =
  if x > 0 then write_digits ob x
  else if x < 0 then (
    Buffer.add_char ob '-';
    write_digits ob x)
  else Buffer.add_char ob '0'

let float_needs_period s =
  try
    for i = 0 to String.length s - 1 do
      match s.[i] with '0' .. '9' | '-' -> () | _ -> raise Exit
    done;
    true
  with Exit -> false

let write_float ob x =
  match classify_float x with
  | FP_nan -> Buffer.add_string ob "NaN"
  | FP_infinite ->
      Buffer.add_string ob (if x > 0. then "Infinity" else "-Infinity")
  | _ ->
      let s1 = Printf.sprintf "%.16g" x in
      let s = if float_of_string s1 = x then s1 else Printf.sprintf "%.17g" x in
      Buffer.add_string ob s;
      if float_needs_period s then Buffer.add_string ob ".0"

let write_std_float ob x =
  match classify_float x with
  | FP_nan -> json_error "NaN value not allowed in standard JSON"
  | FP_infinite ->
      json_error
        (if x > 0. then "Infinity value not allowed in standard JSON"
         else "-Infinity value not allowed in standard JSON")
  | _ ->
      let s1 = Printf.sprintf "%.16g" x in
      let s = if float_of_string s1 = x then s1 else Printf.sprintf "%.17g" x in
      Buffer.add_string ob s;
      if float_needs_period s then Buffer.add_string ob ".0"

let rec iter2_aux f_elt f_sep x = function
  | [] -> ()
  | y :: l ->
      f_sep x;
      f_elt x y;
      iter2_aux f_elt f_sep x l

let iter2 f_elt f_sep x = function
  | [] -> ()
  | y :: l ->
      f_elt x y;
      iter2_aux f_elt f_sep x l

let f_sep ob = Buffer.add_char ob ','

let rec write_json ob (x : t) =
  match x with
  | `Null -> write_null ob ()
  | `Bool b -> write_bool ob b
  | `Int i -> write_int ob i
  | `Intlit s -> Buffer.add_string ob s
  | `Float f -> write_float ob f
  | `Floatlit s -> Buffer.add_string ob s
  | `String s -> write_string ob s
  | `Stringlit s -> Buffer.add_string ob s
  | `Assoc l -> write_assoc ob l
  | `List l -> write_list ob l

and write_assoc ob l =
  let f_elt ob (s, x) =
    write_string ob s;
    Buffer.add_char ob ':';
    write_json ob x
  in
  Buffer.add_char ob '{';
  iter2 f_elt f_sep ob l;
  Buffer.add_char ob '}'

and write_list ob l =
  Buffer.add_char ob '[';
  iter2 write_json f_sep ob l;
  Buffer.add_char ob ']'

let rec write_std_json ob (x : t) =
  match x with
  | `Null -> write_null ob ()
  | `Bool b -> write_bool ob b
  | `Int i -> write_int ob i
  | `Intlit s -> Buffer.add_string ob s
  | `Float f -> write_std_float ob f
  | `Floatlit s -> Buffer.add_string ob s
  | `String s -> write_string ob s
  | `Stringlit s -> Buffer.add_string ob s
  | `Assoc l -> write_std_assoc ob l
  | `List l -> write_std_list ob l

and write_std_assoc ob l =
  let f_elt ob (s, x) =
    write_string ob s;
    Buffer.add_char ob ':';
    write_std_json ob x
  in
  Buffer.add_char ob '{';
  iter2 f_elt f_sep ob l;
  Buffer.add_char ob '}'

and write_std_list ob l =
  Buffer.add_char ob '[';
  iter2 write_std_json f_sep ob l;
  Buffer.add_char ob ']'

let to_buffer ?(suf = "") ?(std = false) ob x =
  if std then write_std_json ob x else write_json ob x;
  Buffer.add_string ob suf

let to_string ?buf ?(len = 256) ?(suf = "") ?std x =
  let ob =
    match buf with
    | None -> Buffer.create len
    | Some ob ->
        Buffer.clear ob;
        ob
  in
  to_buffer ~suf ?std ob x;
  let s = Buffer.contents ob in
  Buffer.clear ob;
  s

let to_channel ?buf ?(len = 4096) ?(suf = "") ?std oc x =
  let ob =
    match buf with
    | None -> Buffer.create len
    | Some ob ->
        Buffer.clear ob;
        ob
  in
  to_buffer ~suf ?std ob x;
  Buffer.output_buffer oc ob;
  Buffer.clear ob

let to_output ?buf ?(len = 4096) ?(suf = "") ?std out x =
  let ob =
    match buf with
    | None -> Buffer.create len
    | Some ob ->
        Buffer.clear ob;
        ob
  in
  to_buffer ~suf ?std ob x;
  let _ : int = out#output (Buffer.contents ob) 0 (Buffer.length ob) in
  Buffer.clear ob

let to_file ?len ?std ?(suf = "\n") file x =
  let oc = open_out_bin file in
  try
    to_channel ?len ~suf ?std oc x;
    close_out oc
  with e ->
    close_out_noerr oc;
    raise e

let seq_to_buffer ?(suf = "\n") ?std ob st =
  Seq.iter (to_buffer ~suf ?std ob) st

let seq_to_string ?buf ?(len = 256) ?(suf = "\n") ?std st =
  let ob =
    match buf with
    | None -> Buffer.create len
    | Some ob ->
        Buffer.clear ob;
        ob
  in
  seq_to_buffer ~suf ?std ob st;
  let s = Buffer.contents ob in
  Buffer.clear ob;
  s

let seq_to_channel ?buf ?(len = 2096) ?(suf = "\n") ?std oc seq =
  let ob =
    match buf with
    | None -> Buffer.create len
    | Some ob ->
        Buffer.clear ob;
        ob
  in
  Seq.iter
    (fun json ->
      to_buffer ~suf ?std ob json;
      Buffer.output_buffer oc ob;
      Buffer.clear ob)
    seq

let seq_to_file ?len ?(suf = "\n") ?std file st =
  let oc = open_out file in
  try
    seq_to_channel ?len ~suf ?std oc st;
    close_out oc
  with e ->
    close_out_noerr oc;
    raise e

let rec sort = function
  | `Assoc l ->
      let l = List.rev (List.rev_map (fun (k, v) -> (k, sort v)) l) in
      `Assoc (List.stable_sort (fun (a, _) (b, _) -> String.compare a b) l)
  | `List l -> `List (List.rev (List.rev_map sort l))
  | x -> x

let rec pp fmt = function
  | `Null -> Format.pp_print_string fmt "`Null"
  | `Bool x ->
      Format.fprintf fmt "`Bool (@[<hov>";
      Format.fprintf fmt "%B" x;
      Format.fprintf fmt "@])"
  | `Int x ->
      Format.fprintf fmt "`Int (@[<hov>";
      Format.fprintf fmt "%d" x;
      Format.fprintf fmt "@])"
  | `Intlit x ->
      Format.fprintf fmt "`Intlit (@[<hov>";
      Format.fprintf fmt "%S" x;
      Format.fprintf fmt "@])"
  | `Float x ->
      Format.fprintf fmt "`Float (@[<hov>";
      Format.fprintf fmt "%F" x;
      Format.fprintf fmt "@])"
  | `Floatlit x ->
      Format.fprintf fmt "`Floatlit (@[<hov>";
      Format.fprintf fmt "%S" x;
      Format.fprintf fmt "@])"
  | `String x ->
      Format.fprintf fmt "`String (@[<hov>";
      Format.fprintf fmt "%S" x;
      Format.fprintf fmt "@])"
  | `Stringlit x ->
      Format.fprintf fmt "`Stringlit (@[<hov>";
      Format.fprintf fmt "%S" x;
      Format.fprintf fmt "@])"
  | `Assoc xs ->
      Format.fprintf fmt "`Assoc (@[<hov>";
      Format.fprintf fmt "@[<2>[";
      ignore
        (List.fold_left
           (fun sep (key, value) ->
             if sep then Format.fprintf fmt ";@ ";
             Format.fprintf fmt "(@[";
             Format.fprintf fmt "%S" key;
             Format.fprintf fmt ",@ ";
             pp fmt value;
             Format.fprintf fmt "@])";
             true)
           false xs);
      Format.fprintf fmt "@,]@]";
      Format.fprintf fmt "@])"
  | `List xs ->
      Format.fprintf fmt "`List (@[<hov>";
      Format.fprintf fmt "@[<2>[";
      ignore
        (List.fold_left
           (fun sep x ->
             if sep then Format.fprintf fmt ";@ ";
             pp fmt x;
             true)
           false xs);
      Format.fprintf fmt "@,]@]";
      Format.fprintf fmt "@])"

let show x = Format.asprintf "%a" pp x

let rec equal a b =
  match (a, b) with
  | `Null, `Null -> true
  | `Bool a, `Bool b -> a = b
  | `Int a, `Int b -> a = b
  | `Intlit a, `Intlit b -> a = b
  | `Float a, `Float b -> a = b
  | `Floatlit a, `Floatlit b -> a = b
  | `String a, `String b -> a = b
  | `Stringlit a, `Stringlit b -> a = b
  | `Assoc xs, `Assoc ys -> (
      let compare_keys = fun (key, _) (key', _) -> String.compare key key' in
      let xs = List.stable_sort compare_keys xs in
      let ys = List.stable_sort compare_keys ys in
      match
        List.for_all2
          (fun (key, value) (key', value') ->
            match key = key' with false -> false | true -> equal value value')
          xs ys
      with
      | result -> result
      | exception Invalid_argument _ -> false)
  | `List xs, `List ys -> (
      match List.for_all2 equal xs ys with
      | result -> result
      | exception Invalid_argument _ -> false)
  | _ -> false

module Pretty = struct
  let indent_str = "  "
  let max_compact_width = 120

  let should_compact (json : t) =
    let exception Not_compact in
    let width = ref 0 in
    let add n =
      width := !width + n;
      if !width > max_compact_width then raise_notrace Not_compact
    in
    let rec check json =
      match json with
      | `Null -> add 4
      | `Bool b -> add (if b then 4 else 5)
      | `Int i -> add (String.length (Int.to_string i))
      | `Intlit s -> add (String.length s)
      | `Float f ->
          add
            (if Float.equal (Float.round f) f then
               String.length (Int.to_string (Float.to_int f))
             else String.length (Printf.sprintf "%g" f))
      | `Floatlit s -> add (String.length s)
      | `String s -> add (String.length s + 2)
      | `Stringlit s -> add (String.length s)
      | `List [] -> add 2
      | `List items ->
          add 2;
          List.iter
            (fun x ->
              check x;
              add 2)
            items
      | `Assoc [] -> add 2
      | `Assoc items ->
          add 2;
          List.iter
            (fun (k, v) ->
              add (String.length k + 4);
              check v;
              add 2)
            items
    in
    match check json with () -> true | exception Not_compact -> false

  let write_indent buf indent =
    for _ = 1 to indent do
      Buffer.add_string buf indent_str
    done

  let write_float buf f =
    if Float.equal (Float.round f) f then
      Buffer.add_string buf (Int.to_string (Float.to_int f))
    else Printf.bprintf buf "%g" f

  let write_quoted_string buf s =
    Buffer.add_char buf '"';
    write_string_body buf s;
    Buffer.add_char buf '"'

  let write_primitive buf ~value ~reset json =
    match (json : t) with
    | `Null ->
        value buf;
        Buffer.add_string buf "null";
        reset buf
    | `Bool b ->
        value buf;
        Buffer.add_string buf (if b then "true" else "false");
        reset buf
    | `Int i ->
        value buf;
        Buffer.add_string buf (Int.to_string i);
        reset buf
    | `Intlit s ->
        value buf;
        Buffer.add_string buf s;
        reset buf
    | `Float f ->
        value buf;
        write_float buf f;
        reset buf
    | `Floatlit s ->
        value buf;
        Buffer.add_string buf s;
        reset buf
    | `String s ->
        value buf;
        write_quoted_string buf s;
        reset buf
    | `Stringlit s ->
        value buf;
        Buffer.add_string buf s;
        reset buf
    | _ -> ()

  let write_primitive_plain buf json =
    match (json : t) with
    | `Null -> Buffer.add_string buf "null"
    | `Bool b -> Buffer.add_string buf (if b then "true" else "false")
    | `Int i -> Buffer.add_string buf (Int.to_string i)
    | `Intlit s -> Buffer.add_string buf s
    | `Float f -> write_float buf f
    | `Floatlit s -> Buffer.add_string buf s
    | `String s -> write_quoted_string buf s
    | `Stringlit s -> Buffer.add_string buf s
    | _ -> ()

  let write_key buf ~key ~reset k =
    key buf;
    write_quoted_string buf k;
    reset buf;
    Buffer.add_string buf ": "

  let write_key_plain buf k =
    write_quoted_string buf k;
    Buffer.add_string buf ": "

  let is_primitive (json : t) =
    match json with `List _ | `Assoc _ -> false | _ -> true

  let rec write_sep_list :
      'a. Buffer.t -> string -> ('a -> unit) -> 'a list -> unit =
   fun buf sep write_item -> function
    | [] -> ()
    | [ x ] -> write_item x
    | x :: rest ->
        write_item x;
        Buffer.add_string buf sep;
        write_sep_list buf sep write_item rest

  let rec write_compact buf ~value ~key ~reset json =
    if is_primitive json then write_primitive buf ~value ~reset json
    else
      match (json : t) with
      | `List [] -> Buffer.add_string buf "[]"
      | `List items ->
          Buffer.add_string buf "[ ";
          write_sep_list buf ", " (write_compact buf ~value ~key ~reset) items;
          Buffer.add_string buf " ]"
      | `Assoc [] -> Buffer.add_string buf "{}"
      | `Assoc items ->
          Buffer.add_string buf "{ ";
          write_sep_list buf ", "
            (write_compact_entry buf ~value ~key ~reset)
            items;
          Buffer.add_string buf " }"
      | _ -> ()

  and write_compact_entry buf ~value ~key ~reset (k, v) =
    write_key buf ~key ~reset k;
    write_compact buf ~value ~key ~reset v

  let rec write_summarized buf ~value ~key ~meta ~reset json =
    match (json : t) with
    | `String s ->
        let truncated =
          if String.length s > 20 then String.sub s 0 17 ^ "..." else s
        in
        value buf;
        write_quoted_string buf truncated;
        reset buf
    | `List [] -> Buffer.add_string buf "[]"
    | `List items ->
        Buffer.add_string buf "[ ";
        meta buf;
        Printf.bprintf buf "<%d items>" (List.length items);
        reset buf;
        Buffer.add_string buf " ]"
    | `Assoc [] -> Buffer.add_string buf "{}"
    | `Assoc items ->
        Buffer.add_string buf "{ ";
        write_sep_list buf ", "
          (write_summarized_entry buf ~key ~meta ~reset)
          items;
        Buffer.add_string buf " }"
    | _ -> write_primitive buf ~value ~reset json

  and write_summarized_entry buf ~key ~meta ~reset (k, _) =
    write_key buf ~key ~reset k;
    meta buf;
    Buffer.add_string buf "...";
    reset buf

  let rec write_json buf ~value ~key ~reset ~indent json =
    if is_primitive json then write_primitive buf ~value ~reset json
    else
      match (json : t) with
      | `List [] -> Buffer.add_string buf "[]"
      | `List _ when indent = 0 && should_compact json ->
          write_compact buf ~value ~key ~reset json
      | `List items ->
          Buffer.add_string buf "[\n";
          write_list_items buf ~value ~key ~reset ~indent:(indent + 1) items;
          write_indent buf indent;
          Buffer.add_char buf ']'
      | `Assoc [] -> Buffer.add_string buf "{}"
      | `Assoc _ when indent = 0 && should_compact json ->
          write_compact buf ~value ~key ~reset json
      | `Assoc items ->
          Buffer.add_string buf "{\n";
          write_assoc_items buf ~value ~key ~reset ~indent:(indent + 1) items;
          write_indent buf indent;
          Buffer.add_char buf '}'
      | _ -> ()

  and write_list_items buf ~value ~key ~reset ~indent items =
    let write_item ~last x =
      write_indent buf indent;
      write_json buf ~value ~key ~reset ~indent x;
      Buffer.add_string buf (if last then "\n" else ",\n")
    in
    match items with
    | [] -> ()
    | [ x ] -> write_item ~last:true x
    | x :: rest ->
        write_item ~last:false x;
        write_list_items buf ~value ~key ~reset ~indent rest

  and write_assoc_items buf ~value ~key ~reset ~indent items =
    let write_item ~last (k, v) =
      write_indent buf indent;
      write_key buf ~key ~reset k;
      write_json buf ~value ~key ~reset ~indent v;
      Buffer.add_string buf (if last then "\n" else ",\n")
    in
    match items with
    | [] -> ()
    | [ kv ] -> write_item ~last:true kv
    | kv :: rest ->
        write_item ~last:false kv;
        write_assoc_items buf ~value ~key ~reset ~indent rest

  let rec write_compact_plain buf json =
    if is_primitive json then write_primitive_plain buf json
    else
      match (json : t) with
      | `List [] -> Buffer.add_string buf "[]"
      | `List items ->
          Buffer.add_string buf "[ ";
          write_sep_list buf ", " (write_compact_plain buf) items;
          Buffer.add_string buf " ]"
      | `Assoc [] -> Buffer.add_string buf "{}"
      | `Assoc items ->
          Buffer.add_string buf "{ ";
          write_sep_list buf ", " (write_compact_entry_plain buf) items;
          Buffer.add_string buf " }"
      | _ -> ()

  and write_compact_entry_plain buf (k, v) =
    write_key_plain buf k;
    write_compact_plain buf v

  let rec write_json_plain buf ~indent json =
    if is_primitive json then write_primitive_plain buf json
    else
      match (json : t) with
      | `List [] -> Buffer.add_string buf "[]"
      | `List _ when indent = 0 && should_compact json ->
          write_compact_plain buf json
      | `List items ->
          Buffer.add_string buf "[\n";
          write_list_items_plain buf ~indent:(indent + 1) items;
          write_indent buf indent;
          Buffer.add_char buf ']'
      | `Assoc [] -> Buffer.add_string buf "{}"
      | `Assoc _ when indent = 0 && should_compact json ->
          write_compact_plain buf json
      | `Assoc items ->
          Buffer.add_string buf "{\n";
          write_assoc_items_plain buf ~indent:(indent + 1) items;
          write_indent buf indent;
          Buffer.add_char buf '}'
      | _ -> ()

  and write_list_items_plain buf ~indent items =
    let write_item ~last x =
      write_indent buf indent;
      write_json_plain buf ~indent x;
      Buffer.add_string buf (if last then "\n" else ",\n")
    in
    match items with
    | [] -> ()
    | [ x ] -> write_item ~last:true x
    | x :: rest ->
        write_item ~last:false x;
        write_list_items_plain buf ~indent rest

  and write_assoc_items_plain buf ~indent items =
    let write_item ~last (k, v) =
      write_indent buf indent;
      write_key_plain buf k;
      write_json_plain buf ~indent v;
      Buffer.add_string buf (if last then "\n" else ",\n")
    in
    match items with
    | [] -> ()
    | [ kv ] -> write_item ~last:true kv
    | kv :: rest ->
        write_item ~last:false kv;
        write_assoc_items_plain buf ~indent rest

  let to_buffer_colored buf ~colorize ~summarize json =
    if (not colorize) && not summarize then write_json_plain buf ~indent:0 json
    else begin
      let module Color = Ansi.To_buffer (struct
        let colorize = colorize
      end) in
      if summarize then
        write_summarized buf json ~value:Color.green ~key:Color.blue_bold
          ~meta:Color.gray ~reset:Color.reset
      else
        write_json buf json ~indent:0 ~value:Color.green ~key:Color.blue_bold
          ~reset:Color.reset
    end

  let to_string_colored ~colorize ~summarize json =
    let buf = Buffer.create 4096 in
    to_buffer_colored buf ~colorize ~summarize json;
    Buffer.contents buf

  let print_colored ~colorize ~summarize json =
    let buf = Buffer.create 65536 in
    to_buffer_colored buf ~colorize ~summarize json;
    Buffer.output_buffer stdout buf;
    print_newline ()
end

let pp fmt json = Format.fprintf fmt "%s" (to_string json)
