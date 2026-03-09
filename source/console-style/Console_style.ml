let indent n = String.make (n * 1) ' '
let enter n = String.make n '\n'
let single_quotes str = "'" ^ str ^ "'"

(* Lightweight ANSI SGR helpers — avoids pulling in matrix.ansi (which contains
   64-bit integer literals that overflow when compiled to JS). *)

type color = Red | Green | Yellow | Blue | Cyan | Bright_black

let sgr_of_color = function
  | Red -> "31"
  | Green -> "32"
  | Yellow -> "33"
  | Blue -> "34"
  | Cyan -> "36"
  | Bright_black -> "90"

let wrap_sgr codes text = "\027[" ^ codes ^ "m" ^ text ^ "\027[0m"

let styled_string ?fg ?bold text =
  let codes =
    match (bold, fg) with
    | Some true, Some c -> "1;" ^ sgr_of_color c
    | Some true, None -> "1"
    | _, Some c -> sgr_of_color c
    | _ -> ""
  in
  if codes = "" then text else wrap_sgr codes text

type t = {
  bold : string -> string;
  red : string -> string;
  green : string -> string;
  yellow : string -> string;
  blue : string -> string;
  gray : string -> string;
  cyan : string -> string;
  styled : ?fg:color -> ?bold:bool -> string -> string;
}

let make ~colorize =
  let styled ?fg ?bold text =
    if colorize then styled_string ?fg ?bold text else text
  in
  {
    bold = (fun s -> styled ~bold:true s);
    red = (fun s -> styled ~fg:Red s);
    green = (fun s -> styled ~fg:Green s);
    yellow = (fun s -> styled ~fg:Yellow s);
    blue = (fun s -> styled ~fg:Blue s);
    gray = (fun s -> styled ~fg:Bright_black s);
    cyan = (fun s -> styled ~fg:Cyan s);
    styled;
  }

module Buffer = struct
  let green ~colorize buf =
    if colorize then Stdlib.Buffer.add_string buf "\027[32m"

  let blue_bold ~colorize buf =
    if colorize then Stdlib.Buffer.add_string buf "\027[1m\027[34m"

  let gray ~colorize buf =
    if colorize then Stdlib.Buffer.add_string buf "\027[90m"

  let reset ~colorize buf =
    if colorize then Stdlib.Buffer.add_string buf "\027[39m\027[0m"
end
