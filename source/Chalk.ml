module Make (Config : sig
  val disable : bool
end) =
struct
  let bold str =
    if Config.disable then str else Printf.sprintf "\027[1m%s\027[0m" str

  let underline str =
    if Config.disable then str else Printf.sprintf "\027[4m%s\027[0m" str

  let invert str =
    if Config.disable then str else Printf.sprintf "\027[7m%s\027[0m" str

  let red str =
    if Config.disable then str else Printf.sprintf "\027[31m%s\027[39m" str

  let green str =
    if Config.disable then str else Printf.sprintf "\027[32m%s\027[39m" str

  let yellow str =
    if Config.disable then str else Printf.sprintf "\027[33m%s\027[39m" str

  let blue str =
    if Config.disable then str else Printf.sprintf "\027[34m%s\027[39m" str

  let magenta str =
    if Config.disable then str else Printf.sprintf "\027[35m%s\027[39m" str

  let cyan str =
    if Config.disable then str else Printf.sprintf "\027[36m%s\027[39m" str

  let gray str =
    if Config.disable then str else Printf.sprintf "\027[90m%s\027[39m" str

  let white str =
    if Config.disable then str else Printf.sprintf "\027[97m%s\027[39m" str

  let light_gray str =
    if Config.disable then str else Printf.sprintf "\027[37m%s\027[39m" str

  let light_red str =
    if Config.disable then str else Printf.sprintf "\027[91m%s\027[39m" str

  let light_green str =
    if Config.disable then str else Printf.sprintf "\027[92m%s\027[39m" str

  let light_yellow str =
    if Config.disable then str else Printf.sprintf "\027[93m%s\027[39m" str

  let light_blue str =
    if Config.disable then str else Printf.sprintf "\027[94m%s\027[39m" str

  let light_magenta str =
    if Config.disable then str else Printf.sprintf "\027[95m%s\027[39m" str

  let light_cyan str =
    if Config.disable then str else Printf.sprintf "\027[96m%s\027[39m" str

  let bg_red str =
    if Config.disable then str else Printf.sprintf "\027[41m%s\027[49m" str

  let bg_green str =
    if Config.disable then str else Printf.sprintf "\027[42m%s\027[49m" str

  let bg_yellow str =
    if Config.disable then str else Printf.sprintf "\027[43m%s\027[49m" str

  let bg_blue str =
    if Config.disable then str else Printf.sprintf "\027[44m%s\027[49m" str

  let bg_magenta str =
    if Config.disable then str else Printf.sprintf "\027[45m%s\027[49m" str

  let bg_cyan str =
    if Config.disable then str else Printf.sprintf "\027[46m%s\027[49m" str

  let bg_gray str =
    if Config.disable then str else Printf.sprintf "\027[100m%s\027[49m" str

  let bg_white str =
    if Config.disable then str else Printf.sprintf "\027[107m%s\027[49m" str

  let bg_light_gray str =
    if Config.disable then str else Printf.sprintf "\027[47m%s\027[49m" str

  let bg_light_red str =
    if Config.disable then str else Printf.sprintf "\027[101m%s\027[49m" str

  let bg_light_green str =
    if Config.disable then str else Printf.sprintf "\027[102m%s\027[49m" str

  let bg_light_yellow str =
    if Config.disable then str else Printf.sprintf "\027[103m%s\027[49m" str

  let bg_light_blue str =
    if Config.disable then str else Printf.sprintf "\027[104m%s\027[49m" str

  let bg_light_magenta str =
    if Config.disable then str else Printf.sprintf "\027[105m%s\027[49m" str

  let bg_light_cyan str =
    if Config.disable then str else Printf.sprintf "\027[106m%s\027[39m" str
end
