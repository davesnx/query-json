let find_group = Language.find_category
let available_categories = Language.category_names

let format_function_doc ~colorize (f : Language.function_info) =
  let t = Console_style.make ~colorize in
  let aliases_str =
    if List.length f.aliases > 0 then
      t.gray (" (aliases: " ^ String.concat ", " f.aliases ^ ")")
    else ""
  in
  let base =
    Console_style.indent 1 ^ t.bold f.name ^ aliases_str
    ^ t.gray (" - " ^ f.description)
  in
  match f.example with
  | Some ex ->
      base ^ Console_style.enter 1 ^ Console_style.indent 2 ^ t.green ex
  | None -> base

let format_group ~colorize (g : Language.category) =
  let t = Console_style.make ~colorize in
  let header =
    t.bold (t.yellow (String.uppercase_ascii g.name ^ " FUNCTIONS"))
    ^ Console_style.enter 1 ^ t.gray g.description ^ Console_style.enter 2
  in
  let funcs =
    g.functions
    |> List.map (format_function_doc ~colorize)
    |> String.concat (Console_style.enter 1)
  in
  header ^ funcs ^ Console_style.enter 1

let format_categories_list ~colorize =
  let t = Console_style.make ~colorize in
  t.bold "Available help categories:"
  ^ Console_style.enter 2
  ^ (Language.all_categories
    |> List.map (fun (g : Language.category) ->
        Console_style.indent 1 ^ t.bold g.name ^ t.gray (" - " ^ g.description))
    |> String.concat (Console_style.enter 1))
  ^ Console_style.enter 2
  ^ t.gray "Usage: query-json --functions <category>"
  ^ Console_style.enter 1
  ^ t.gray "Example: query-json --functions string"
  ^ Console_style.enter 1
