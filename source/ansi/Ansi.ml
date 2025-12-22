module To_string (Config : sig
  val colorize : bool
end) =
struct
  let wrap code str =
    if Config.colorize then Printf.sprintf "%s%s\027[0m" code str else str

  let bold str = wrap "\027[1m" str
  let red str = wrap "\027[31m" str
  let green str = wrap "\027[32m" str
  let yellow str = wrap "\027[33m" str
  let gray str = wrap "\027[90m" str
end

module To_buffer (Config : sig
  val colorize : bool
end) =
struct
  let green buf = if Config.colorize then Buffer.add_string buf "\027[32m"

  let blue_bold buf =
    if Config.colorize then Buffer.add_string buf "\027[1m\027[34m"

  let gray buf = if Config.colorize then Buffer.add_string buf "\027[90m"

  let reset buf =
    if Config.colorize then Buffer.add_string buf "\027[39m\027[0m"
end
