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

let encode_to_buffer buf str =
  for i = 0 to String.length str - 1 do
    match str.[i] with
    | '\\' -> Buffer.add_string buf {|\\|}
    | '"' -> Buffer.add_string buf {|\"|}
    | '\n' -> Buffer.add_string buf {|\n|}
    | '\t' -> Buffer.add_string buf {|\t|}
    | '\r' -> Buffer.add_string buf {|\r|}
    | '\b' -> Buffer.add_string buf {|\b|}
    | ('\000' .. '\031' | '\127') as c ->
        Printf.bprintf buf "\\u%04X" (Char.code c)
    | c -> Buffer.add_char buf c
  done

let encode str =
  let buf = Buffer.create (String.length str * 5 / 4) in
  encode_to_buffer buf str;
  Buffer.contents buf

module Printer = struct
  let indent_str = "  "
  let max_compact_width = 60

  let rec is_simple_json (json : t) =
    match json with
    | `Null | `Bool _ | `Int _ | `Intlit _ | `Float _ | `String _ -> true
    | `List items -> List.for_all is_simple_json items
    | `Assoc items -> List.for_all (fun (_, v) -> is_simple_json v) items

  let rec estimate_width (json : t) =
    match json with
    | `Null -> 4
    | `Bool b -> if b then 4 else 5
    | `Int i -> String.length (Int.to_string i)
    | `Intlit s -> String.length s
    | `Float f ->
        if Float.equal (Float.round f) f then
          String.length (Int.to_string (Float.to_int f))
        else String.length (Printf.sprintf "%g" f)
    | `String s -> String.length s + 2
    | `List [] -> 2
    | `List items ->
        List.fold_left (fun acc x -> acc + estimate_width x + 2) 2 items
    | `Assoc [] -> 2
    | `Assoc items ->
        List.fold_left
          (fun acc (k, v) -> acc + String.length k + 4 + estimate_width v + 2)
          2 items

  let should_compact (json : t) =
    is_simple_json json && estimate_width json <= max_compact_width

  let write_indent buf indent =
    for _ = 1 to indent do
      Buffer.add_string buf indent_str
    done

  let write_float buf f =
    if Float.equal (Float.round f) f then
      Buffer.add_string buf (Int.to_string (Float.to_int f))
    else Printf.bprintf buf "%g" f

  let rec write_compact buf ~value ~key ~reset json =
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
        Buffer.add_char buf '"';
        encode_to_buffer buf s;
        Buffer.add_char buf '"';
        reset buf
    | `List [] -> Buffer.add_string buf "[]"
    | `List items ->
        Buffer.add_string buf "[ ";
        write_compact_list buf ~value ~key ~reset items;
        Buffer.add_string buf " ]"
    | `Assoc [] -> Buffer.add_string buf "{}"
    | `Assoc items ->
        Buffer.add_string buf "{ ";
        write_compact_assoc buf ~value ~key ~reset items;
        Buffer.add_string buf " }"

  and write_compact_list buf ~value ~key ~reset = function
    | [] -> ()
    | [ x ] -> write_compact buf ~value ~key ~reset x
    | x :: rest ->
        write_compact buf ~value ~key ~reset x;
        Buffer.add_string buf ", ";
        write_compact_list buf ~value ~key ~reset rest

  and write_compact_assoc buf ~value ~key ~reset = function
    | [] -> ()
    | [ (k, v) ] ->
        key buf;
        Buffer.add_char buf '"';
        encode_to_buffer buf k;
        Buffer.add_char buf '"';
        reset buf;
        Buffer.add_string buf ": ";
        write_compact buf ~value ~key ~reset v
    | (k, v) :: rest ->
        key buf;
        Buffer.add_char buf '"';
        encode_to_buffer buf k;
        Buffer.add_char buf '"';
        reset buf;
        Buffer.add_string buf ": ";
        write_compact buf ~value ~key ~reset v;
        Buffer.add_string buf ", ";
        write_compact_assoc buf ~value ~key ~reset rest

  let rec write_summarized buf ~value ~key ~meta ~reset json =
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
        let truncated =
          if String.length s > 20 then String.sub s 0 17 ^ "..." else s
        in
        value buf;
        Buffer.add_char buf '"';
        encode_to_buffer buf truncated;
        Buffer.add_char buf '"';
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
        write_summarized_assoc buf ~key ~meta ~reset items;
        Buffer.add_string buf " }"

  and write_summarized_assoc buf ~key ~meta ~reset = function
    | [] -> ()
    | [ (k, _) ] ->
        key buf;
        Buffer.add_char buf '"';
        encode_to_buffer buf k;
        Buffer.add_char buf '"';
        reset buf;
        Buffer.add_string buf ": ";
        meta buf;
        Buffer.add_string buf "...";
        reset buf
    | (k, _) :: rest ->
        key buf;
        Buffer.add_char buf '"';
        encode_to_buffer buf k;
        Buffer.add_char buf '"';
        reset buf;
        Buffer.add_string buf ": ";
        meta buf;
        Buffer.add_string buf "...";
        reset buf;
        Buffer.add_string buf ", ";
        write_summarized_assoc buf ~key ~meta ~reset rest

  let rec write_json buf ~value ~key ~reset ~indent json =
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
        Buffer.add_char buf '"';
        encode_to_buffer buf s;
        Buffer.add_char buf '"';
        reset buf
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

  and write_list_items buf ~value ~key ~reset ~indent = function
    | [] -> ()
    | [ x ] ->
        write_indent buf indent;
        write_json buf ~value ~key ~reset ~indent x;
        Buffer.add_char buf '\n'
    | x :: rest ->
        write_indent buf indent;
        write_json buf ~value ~key ~reset ~indent x;
        Buffer.add_string buf ",\n";
        write_list_items buf ~value ~key ~reset ~indent rest

  and write_assoc_items buf ~value ~key ~reset ~indent = function
    | [] -> ()
    | [ (k, v) ] ->
        write_indent buf indent;
        key buf;
        Buffer.add_char buf '"';
        encode_to_buffer buf k;
        Buffer.add_char buf '"';
        reset buf;
        Buffer.add_string buf ": ";
        write_json buf ~value ~key ~reset ~indent v;
        Buffer.add_char buf '\n'
    | (k, v) :: rest ->
        write_indent buf indent;
        key buf;
        Buffer.add_char buf '"';
        encode_to_buffer buf k;
        Buffer.add_char buf '"';
        reset buf;
        Buffer.add_string buf ": ";
        write_json buf ~value ~key ~reset ~indent v;
        Buffer.add_string buf ",\n";
        write_assoc_items buf ~value ~key ~reset ~indent rest

  let to_buffer buf ~colorize ~summarize json =
    let module Color = Ansi.To_buffer (struct
      let colorize = colorize
    end) in
    if summarize then
      write_summarized buf json ~value:Color.green ~key:Color.blue_bold
        ~meta:Color.gray ~reset:Color.reset
    else
      write_json buf json ~indent:0 ~value:Color.green ~key:Color.blue_bold
        ~reset:Color.reset

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

let equal (a : t) (b : t) =
  match (a, b) with
  | `Int x, `Int y -> x = y
  | `Float x, `Float y -> x = y
  | `Int x, `Float y -> float_of_int x = y
  | `Float x, `Int y -> x = float_of_int y
  | _ -> a = b
