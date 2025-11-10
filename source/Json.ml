include Yojson.Safe
include Yojson.Safe.Util

let quotes str = "\"" ^ str ^ "\""

let parse_string str =
  try Ok (Yojson.Safe.from_string str)
  with e ->
    Error (Printexc.to_string e ^ " There was an error reading the string")

let parse_file file =
  try Ok (Yojson.Safe.from_file file)
  with e ->
    Error (Printexc.to_string e ^ " There was an error reading the file")

let parse_channel channel =
  try Ok (Yojson.Safe.from_channel channel)
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

module Format = struct
  let rec format ~disable (json : t) =
    match json with
    | `Null -> Easy_format.Atom (Chalk.green ~disable "null", Easy_format.atom)
    | `Bool b ->
        Easy_format.Atom
          (Chalk.green ~disable (Bool.to_string b), Easy_format.atom)
    | `Int i ->
        Easy_format.Atom (Chalk.green ~disable (Int.to_string i), Easy_format.atom)
    | `Float f ->
        Easy_format.Atom
          (Chalk.green ~disable (float_to_string f), Easy_format.atom)
    | `String s ->
        Easy_format.Atom
          (Chalk.green ~disable (quotes (encode s)), Easy_format.atom)
    | `Intlit s -> Easy_format.Atom (Chalk.green ~disable s, Easy_format.atom)
    | `List [] -> Easy_format.Atom ("[]", Easy_format.atom)
    | `List l ->
        Easy_format.List
          (("[", ",", "]", Easy_format.list), List.map (format ~disable) l)
    | `Assoc [] -> Easy_format.Atom ("{}", Easy_format.atom)
    | `Assoc l ->
        Easy_format.List
          (("{", ",", "}", Easy_format.list), List.map (item ~disable) l)

  and item ~disable (name, json) =
    let s =
      Printf.sprintf "%s:"
        (name |> encode |> quotes |> Chalk.blue ~disable
       |> Chalk.bold ~disable)
    in
    Easy_format.Label
      ( (Easy_format.Atom (s, Easy_format.atom), Easy_format.label),
        format ~disable json )
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
  let disable = not colorize in
  match summarize with
  | false -> Easy_format.Pretty.to_string (Format.format ~disable json)
  | true -> Easy_format.Pretty.to_string (Summarize.format json)
