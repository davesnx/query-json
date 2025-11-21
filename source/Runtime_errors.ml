let append_article (noun : string) =
  let starts_with_any (str : string) (chars : string list) =
    let rec loop (chars : string list) =
      match chars with
      | [] -> false
      | x :: xs -> if String.starts_with ~prefix:str x then true else loop xs
    in
    loop chars
  in
  match starts_with_any noun [ "a"; "e"; "i"; "o"; "u" ] with
  | true -> "an " ^ noun
  | false -> "a " ^ noun

let make_error_wrong_operation ~colorize op member_kind (value : Json.t) =
  let module Chalk = Chalk.Make (struct
    let disable = not colorize
  end) in
  "Trying to "
  ^ Formatting.single_quotes (Chalk.bold op)
  ^ " on "
  ^ Chalk.bold (append_article member_kind)
  ^ ":" ^ Formatting.enter 1
  ^ Chalk.gray (Json.to_string value ~colorize ~summarize:true)

let make_empty_list_error ~colorize op =
  let module Chalk = Chalk.Make (struct
    let disable = not colorize
  end) in
  "Trying to "
  ^ Formatting.single_quotes (Chalk.bold op)
  ^ " on an empty array."

let make_arg_error ~colorize op expected actual_value =
  let module Chalk = Chalk.Make (struct
    let disable = not colorize
  end) in
  "Invalid argument for "
  ^ Formatting.single_quotes (Chalk.bold op)
  ^ ": expected " ^ Chalk.bold expected ^ "." ^ Formatting.enter 1
  ^ Chalk.gray (Json.to_string actual_value ~colorize ~summarize:true)

let make_structure_error ~colorize op msg actual_value =
  let module Chalk = Chalk.Make (struct
    let disable = not colorize
  end) in
  "Invalid structure for "
  ^ Formatting.single_quotes (Chalk.bold op)
  ^ ": " ^ msg ^ "." ^ Formatting.enter 1
  ^ Chalk.gray (Json.to_string actual_value ~colorize ~summarize:true)

let make_message_error ~colorize msg =
  let module Chalk = Chalk.Make (struct
    let disable = not colorize
  end) in
  Chalk.red "Error: " ^ msg

let get_field_name json =
  match json with
  | `List _ -> "list"
  | `Assoc _ -> "object"
  | `Bool _ -> "bool"
  | `Float _ -> "float"
  | `Int _ -> "int"
  | `Null -> "null"
  | `String _ -> "string"
  | `Intlit _ -> "int"

let make_error ~colorize (name : string) (json : Json.t) =
  let item_name = get_field_name json in
  make_error_wrong_operation ~colorize name item_name json

let make_error_missing_member ~colorize op key (value : Json.t) =
  let module Chalk = Chalk.Make (struct
    let disable = not colorize
  end) in
  "Trying to "
  ^ Formatting.double_quotes (Chalk.bold op)
  ^ " on an object, that don't have the field "
  ^ Formatting.double_quotes key
  ^ ":" ^ Formatting.enter 1
  ^ Chalk.gray (Json.to_string value ~colorize ~summarize:true)
