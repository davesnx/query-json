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

module Make_format (Chalk : sig
  val green : string -> string
  val blue : string -> string
  val bold : string -> string
end) (Config : sig
  val summarize : bool
end) =
struct
  let quotes str = "\"" ^ str ^ "\""

  let rec to_easy_format = function
    | `Null -> Easy_format.Atom (Chalk.green "null", Easy_format.atom)
    | `Bool b ->
        Easy_format.Atom (Chalk.green (Bool.to_string b), Easy_format.atom)
    | `Int i ->
        Easy_format.Atom (Chalk.green (Int.to_string i), Easy_format.atom)
    | `Float f ->
        let float_to_string float =
          if Stdlib.Float.equal (Stdlib.Float.round float) float then
            float |> Float.to_int |> Int.to_string
          else Printf.sprintf "%g" float
        in
        Easy_format.Atom (Chalk.green (float_to_string f), Easy_format.atom)
    | `String s ->
        Easy_format.Atom (Chalk.green (quotes (encode s)), Easy_format.atom)
    | `Intlit s -> Easy_format.Atom (Chalk.green s, Easy_format.atom)
    | `List [] -> Easy_format.Atom ("[]", Easy_format.atom)
    | `List (l : t list) ->
        Easy_format.List
          (("[", ",", "]", Easy_format.list), List.map to_easy_format l)
    | `Assoc [] -> Easy_format.Atom ("{}", Easy_format.atom)
    | `Assoc (l : (string * t) list) ->
        Easy_format.List (("{", ",", "}", Easy_format.list), List.map item l)

  and item (name, json) =
    let s =
      Printf.sprintf "%s:" (name |> encode |> quotes |> Chalk.blue |> Chalk.bold)
    in
    let value =
      if Config.summarize then Easy_format.Atom ("...", Easy_format.atom)
      else to_easy_format json
    in
    Easy_format.Label
      ((Easy_format.Atom (s, Easy_format.atom), Easy_format.label), value)
end

let to_string (json : t) ~colorize ~summarize ~raw =
  match (raw, json) with
  | true, `String s -> s
  | _ ->
      let module Chalk = Chalk.Make (struct
        let disable = not colorize
      end) in
      let module Format =
        Make_format
          (Chalk)
          (struct
            let summarize = summarize
          end)
      in
      Easy_format.Pretty.to_string (Format.to_easy_format json)
