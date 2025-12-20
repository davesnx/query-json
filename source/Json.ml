include Yojson.Safe
include Yojson.Safe.Util

let parse_string str =
  try Ok (Yojson.Safe.from_string str) with
  | Yojson.Json_error msg -> Error ("JSON parse error: " ^ msg)
  | e -> Error (Printexc.to_string e ^ " There was an error reading the string")

let parse_file file =
  try Ok (Yojson.Safe.from_file file) with
  | Yojson.Json_error msg -> Error ("JSON parse error: " ^ msg)
  | e -> Error (Printexc.to_string e ^ " There was an error reading the file")

let parse_channel channel =
  try Ok (Yojson.Safe.from_channel channel) with
  | Yojson.Json_error msg -> Error ("JSON parse error: " ^ msg)
  | e ->
      Error
        (Printexc.to_string e
       ^ " There was an error reading from standard input")

let hex n = Char.chr (if n < 10 then n + 48 else n + 87)

let write_special src start stop buf str =
  Buffer.add_substring buf src !start (stop - !start);
  Buffer.add_string buf str;
  start := stop + 1

let write_control_char src start stop buf c =
  Buffer.add_substring buf src !start (stop - !start);
  Buffer.add_string buf "\\u00";
  Buffer.add_char buf (hex (Char.code c lsr 4));
  Buffer.add_char buf (hex (Char.code c land 0xf));
  start := stop + 1

let encode_to_buffer buf str =
  let start = ref 0 in
  for i = 0 to String.length str - 1 do
    match str.[i] with
    | '"' -> write_special str start i buf {|\"|}
    | '\\' -> write_special str start i buf {|\\|}
    | '\b' -> write_special str start i buf {|\b|}
    | '\012' -> write_special str start i buf {|\f|}
    | '\n' -> write_special str start i buf {|\n|}
    | '\r' -> write_special str start i buf {|\r|}
    | '\t' -> write_special str start i buf {|\t|}
    | '\x00' .. '\x1F' | '\x7F' -> write_control_char str start i buf str.[i]
    | _ -> ()
  done;
  Buffer.add_substring buf str !start (String.length str - !start)

let encode str =
  let buf = Buffer.create (String.length str * 5 / 4) in
  encode_to_buffer buf str;
  Buffer.contents buf

module Printer = struct
  let indent_str = "  "
  let max_compact_width = 60

  let should_compact (json : t) =
    (* Combined check with early bail-out *)
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
      | `String s -> add (String.length s + 2)
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
    encode_to_buffer buf s;
    Buffer.add_char buf '"'

  (* Write a primitive JSON value (null, bool, number, string) with optional color callbacks *)
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
    | `String s ->
        value buf;
        write_quoted_string buf s;
        reset buf
    | _ -> ()

  let write_primitive_plain buf json =
    match (json : t) with
    | `Null -> Buffer.add_string buf "null"
    | `Bool b -> Buffer.add_string buf (if b then "true" else "false")
    | `Int i -> Buffer.add_string buf (Int.to_string i)
    | `Intlit s -> Buffer.add_string buf s
    | `Float f -> write_float buf f
    | `String s -> write_quoted_string buf s
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

  let to_buffer buf ~colorize ~summarize json =
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

  let to_string ~colorize ~summarize json =
    let buf = Buffer.create 4096 in
    to_buffer buf ~colorize ~summarize json;
    Buffer.contents buf

  let print ~colorize ~summarize json =
    let buf = Buffer.create 65536 in
    to_buffer buf ~colorize ~summarize json;
    Buffer.output_buffer stdout buf;
    print_newline ()
end

let to_string json ~colorize ~summarize ~raw =
  match (raw, json) with
  | true, `String s -> s
  | _ -> Printer.to_string ~colorize ~summarize json

let print (json : t) ~colorize ~summarize ~raw =
  match (raw, json) with
  | true, `String s -> print_endline s
  | _ -> Printer.print ~colorize ~summarize json

let type_of (json : t) =
  match json with
  | `List _ -> "array"
  | `Assoc _ -> "object"
  | `Bool _ -> "boolean"
  | `Float _ | `Int _ | `Intlit _ -> "number"
  | `Null -> "null"
  | `String _ -> "string"

let rec equal (a : t) (b : t) : bool =
  match (a, b) with
  | `Int x, `Int y -> x = y
  | `Float x, `Float y -> x = y
  | `Int x, `Float y -> Float.of_int x = y
  | `Float x, `Int y -> x = Float.of_int y
  | `String x, `String y -> x = y
  | `Bool x, `Bool y -> x = y
  | `Null, `Null -> true
  | `List xs, `List ys ->
      List.length xs = List.length ys && List.for_all2 equal xs ys
  | `Assoc xs, `Assoc ys ->
      List.length xs = List.length ys
      && List.for_all
           (fun (k, v) ->
             match List.assoc_opt k ys with
             | Some v' -> equal v v'
             | None -> false)
           xs
  | _ -> false

(* Generic list comparison: compares two lists element-wise using the provided comparator *)
let rec compare_list_with cmp xs ys =
  match (xs, ys) with
  | [], [] -> 0
  | [], _ -> -1
  | _, [] -> 1
  | x :: xs', y :: ys' ->
      let c = cmp x y in
      if c <> 0 then c else compare_list_with cmp xs' ys'

let rec compare (a : t) (b : t) : int =
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

let rec contains (needle : t) (haystack : t) : bool =
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
