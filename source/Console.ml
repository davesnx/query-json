module Formatting = struct
  let indent n = String.make (n * 2) ' '
  let enter n = String.make n '\n'
  let double_quotes str = "\"" ^ str ^ "\""
  let single_quotes str = "'" ^ str ^ "'"
end

module Errors = struct
  let print_error str =
    Formatting.enter 1
    ^ Chalk.red (Chalk.bold "Error")
    ^ Chalk.red ":" ^ Formatting.indent 1 ^ str ^ Formatting.enter 1

  let position_to_string start end_ =
    Printf.sprintf "[line: %d, char: %d-%d]" start.Lexing.pos_lnum
      (start.Lexing.pos_cnum - start.Lexing.pos_bol)
      (end_.Lexing.pos_cnum - end_.Lexing.pos_bol)

  let extract_exn (str : string) =
    let first = String.index_opt str '(' in
    let last = String.rindex_opt str ')' in
    match (first, last) with
    | Some first_index, Some last_index ->
        let first = first_index + 2 in
        let length = last_index - first_index - 1 - 2 in
        String.sub str first length
    | _, _ -> str

  let make ~input ~(start : Lexing.position) ~(end_ : Lexing.position) =
    let pointer_range = String.make (end_.pos_cnum - start.pos_cnum) '^' in
    Chalk.red (Chalk.bold "Parse error: ")
    ^ "Problem parsing at position "
    ^ position_to_string start end_
    ^ Formatting.enter 2 ^ "Input:" ^ Formatting.indent 1
    ^ Chalk.green (Chalk.bold input)
    ^ Formatting.enter 1 ^ Formatting.indent 4
    ^ String.make start.pos_cnum ' '
    ^ Chalk.gray pointer_range

  let renamed f name =
    Formatting.single_quotes f ^ " is not valid in q, use "
    ^ Formatting.single_quotes name
    ^ " instead"

  let notImplemented f = Formatting.single_quotes f ^ " is not implemented"

  let missing f =
    Formatting.single_quotes f
    ^ " looks like a function and maybe is not implemented or missing in the \
       parser. Either way, could you open an issue \
       'https://github.com/davesnx/query-json/issues/new'"
end

let usage () =
  let open Formatting in
  [
    enter 1;
    Chalk.yellow "Missing query as argument";
    enter 1 ^ "Usage:" ^ enter 2 ^ Chalk.bold "query-json"
    ^ Chalk.gray " [OPTIONS] " ^ "[QUERY] [JSON]" ^ enter 2
    ^ Chalk.bold "OPTIONS";
    indent 1 ^ "-c, --no-color: Disable color in the output";
    indent 1 ^ "-k [VAL], --kind[=VAL]: input kind. " ^ double_quotes "file"
    ^ " | " ^ double_quotes "inline";
    indent 1 ^ "-v, --verbose: Activate verbossity";
    indent 1 ^ "-d, --debug: Print AST";
    indent 1 ^ "--version: Show version information." ^ enter 2
    ^ Chalk.bold "EXAMPLES";
    indent 1 ^ "query-json '.dependencies' package.json";
    indent 1 ^ "query-json '.' <<< '[1, 2, 3]'" ^ enter 2 ^ Chalk.bold "MORE";
    indent 1 ^ " https://github.com/davesnx/query-json";
    enter 1;
  ]
  |> String.concat (enter 1)
