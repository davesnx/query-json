include Yojson.Safe
include Yojson.Safe.Util

let quotes str = "\"" ^ str ^ "\""

let read_json lexbuf =
  let lexer_state = init_lexer () in
  read_t lexer_state lexbuf

let parse_string str =
  try
    let lexbuf = Lexing.from_string str in
    Ok (read_json lexbuf)
  with e ->
    Error (Printexc.to_string e ^ " There was an error reading the string")

let parse_file file =
  try
    let ic = open_in file in
    let lexbuf = Lexing.from_channel ic in
    let result = read_json lexbuf in
    close_in ic;
    Ok result
  with e ->
    Error (Printexc.to_string e ^ " There was an error reading the file")

let parse_channel channel =
  try
    let lexbuf = Lexing.from_channel channel in
    Ok (read_json lexbuf)
  with e ->
    Error
      (Printexc.to_string e ^ " There was an error reading from standard input")

let encode str =
  let buf = Buffer.create (String.length str * 5 / 4) in
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
  done;
  Buffer.contents buf

let float_to_string float =
  if Stdlib.Float.equal (Stdlib.Float.round float) float then
    float |> Float.to_int |> Int.to_string
  else Printf.sprintf "%g" float

module Format (Chalk : sig
  val green : string -> string
  val blue : string -> string
  val bold : string -> string
end) =
struct
  let rec format (json : t) =
    match json with
    | `Null -> Easy_format.Atom (Chalk.green "null", Easy_format.atom)
    | `Bool b ->
        Easy_format.Atom (Chalk.green (Bool.to_string b), Easy_format.atom)
    | `Int i ->
        Easy_format.Atom (Chalk.green (Int.to_string i), Easy_format.atom)
    | `Float f ->
        Easy_format.Atom (Chalk.green (float_to_string f), Easy_format.atom)
    | `String s ->
        Easy_format.Atom (Chalk.green (quotes (encode s)), Easy_format.atom)
    | `Intlit s -> Easy_format.Atom (Chalk.green s, Easy_format.atom)
    | `List [] -> Easy_format.Atom ("[]", Easy_format.atom)
    | `List l ->
        Easy_format.List (("[", ",", "]", Easy_format.list), List.map format l)
    | `Assoc [] -> Easy_format.Atom ("{}", Easy_format.atom)
    | `Assoc l ->
        Easy_format.List (("{", ",", "}", Easy_format.list), List.map item l)

  and item (name, json) =
    let s =
      Printf.sprintf "%s:" (name |> encode |> quotes |> Chalk.blue |> Chalk.bold)
    in
    Easy_format.Label
      ((Easy_format.Atom (s, Easy_format.atom), Easy_format.label), format json)
end

module Summarize = struct
  let rec format (json : t) =
    match json with
    | `Null -> Easy_format.Atom ("null", Easy_format.atom)
    | `Bool b -> Easy_format.Atom (Bool.to_string b, Easy_format.atom)
    | `Int i -> Easy_format.Atom (Int.to_string i, Easy_format.atom)
    | `Intlit s -> Easy_format.Atom (s, Easy_format.atom)
    | `Float f -> Easy_format.Atom (float_to_string f, Easy_format.atom)
    | `String s -> Easy_format.Atom (encode s |> quotes, Easy_format.atom)
    | `List [] -> Easy_format.Atom ("[]", Easy_format.atom)
    | `List l ->
        Easy_format.List (("[", ",", "]", Easy_format.list), List.map format l)
    | `Assoc [] -> Easy_format.Atom ("{}", Easy_format.atom)
    | `Assoc l ->
        Easy_format.List (("{", ",", "}", Easy_format.list), List.map item l)

  and item (name, _json) =
    let s = Printf.sprintf "%s:" (encode name |> quotes) in
    Easy_format.Label
      ( (Easy_format.Atom (s, Easy_format.atom), Easy_format.label),
        Easy_format.Atom ("...", Easy_format.atom) )
end

let to_string (json : t) ~colorize ~summarize =
  match summarize with
  | false ->
      let module Chalk = Chalk.Make (struct
        let disable = not colorize
      end) in
      let module F = Format (Chalk) in
      Easy_format.Pretty.to_string (F.format json)
  | true -> Easy_format.Pretty.to_string (Summarize.format json)
