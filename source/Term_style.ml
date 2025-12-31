open Ansi

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
    if colorize then Ansi.styled ~reset:true ?fg ?bold text else text
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

let bold ~colorize text =
  if colorize then Ansi.styled ~reset:true ~bold:true text else text

let red ~colorize text =
  if colorize then Ansi.styled ~reset:true ~fg:Color.red text else text

let green ~colorize text =
  if colorize then Ansi.styled ~reset:true ~fg:Color.green text else text

let yellow ~colorize text =
  if colorize then Ansi.styled ~reset:true ~fg:Color.yellow text else text

let blue ~colorize text =
  if colorize then Ansi.styled ~reset:true ~fg:Color.blue text else text

let gray ~colorize text =
  if colorize then Ansi.styled ~reset:true ~fg:Color.bright_black text else text

let cyan ~colorize text =
  if colorize then Ansi.styled ~reset:true ~fg:Color.cyan text else text

let styled ~colorize ?fg ?bold text =
  if colorize then Ansi.styled ~reset:true ?fg ?bold text else text

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
