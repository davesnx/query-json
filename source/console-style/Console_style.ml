open Ansi

let indent n = String.make (n * 1) ' '
let enter n = String.make n '\n'
let single_quotes str = "'" ^ str ^ "'"

type t = {
  bold : string -> string;
  red : string -> string;
  green : string -> string;
  yellow : string -> string;
  blue : string -> string;
  gray : string -> string;
  cyan : string -> string;
  styled : ?fg:Color.t -> ?bold:bool -> string -> string;
}

let make ~colorize =
  let styled ?fg ?bold text =
    if colorize then
      Ansi.Style.styled ~reset:true (Ansi.Style.make ?fg ?bold ()) text
    else text
  in
  {
    bold = (fun s -> styled ~bold:true s);
    red = (fun s -> styled ~fg:Color.red s);
    green = (fun s -> styled ~fg:Color.green s);
    yellow = (fun s -> styled ~fg:Color.yellow s);
    blue = (fun s -> styled ~fg:Color.blue s);
    gray = (fun s -> styled ~fg:Color.bright_black s);
    cyan = (fun s -> styled ~fg:Color.cyan s);
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
