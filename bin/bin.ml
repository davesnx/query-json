module Info = struct
  let version =
    match Build_info.V1.version () with
    | None -> "n/a"
    | Some v -> Build_info.V1.Version.to_string v

  let description =
    "query-json allows you to write small programs to operate on top of json \
     files with a concise syntax. It's a faster, simpler and more portable \
     re-implementation of jq in OCaml"
end

let print_error_message str = print_endline ("\n" ^ str ^ "\n")

let usage ?(colorize = true) () =
  let open Formatting in
  let t = Term_style.make ~colorize in
  [
    enter 1;
    t.yellow "Missing query as argument";
    enter 1 ^ "Usage:" ^ enter 2 ^ t.bold "query-json" ^ t.gray " [OPTIONS] "
    ^ "[QUERY] [JSON]" ^ enter 2 ^ t.bold "OPTIONS";
    indent 1 ^ "-c, --no-color: Disable color in the output";
    indent 1 ^ "-r, --raw-output: Output raw strings, not JSON texts";
    indent 1 ^ "-d, --debug: Print AST";
    indent 1 ^ "--functions <category>: Show help for a function category";
    indent 1 ^ "--version: Show version information." ^ enter 2
    ^ t.bold "SUBCOMMANDS";
    indent 1 ^ "repl <json>: Start interactive REPL mode" ^ enter 2
    ^ t.bold "HELP CATEGORIES";
    indent 1
    ^ "string, array, object, path, math, type, control, definition, debug"
    ^ enter 2 ^ t.bold "EXAMPLES";
    indent 1 ^ "query-json '.dependencies' package.json";
    indent 1 ^ "query-json '.' <<< '[1, 2, 3]'";
    indent 1 ^ "query-json --functions string";
    indent 1 ^ "query-json repl data.json" ^ enter 2 ^ t.bold "MORE";
    indent 1 ^ " https://github.com/davesnx/query-json";
    enter 1;
  ]
  |> String.concat (enter 1)
  |> print_endline

let show_help_category ~colorize category =
  match Help.find_group category with
  | Some group ->
      print_endline (Help.format_group ~colorize group);
      true
  | None ->
      print_endline (Help.format_categories_list ~colorize);
      false

let format_json_error ~colorize (err : Json.json_parse_error) =
  Query_error.json_error ~colorize ~message:err.message ?input:err.input
    ?start_pos:err.start_pos ?end_pos:err.end_pos ()

let run_repl json =
  match json with
  | Some f when Sys.file_exists f -> (
      match Json.parse_file f with
      | Ok json -> Repl.make ~json ~path:f
      | Error err -> print_error_message (format_json_error ~colorize:true err))
  | Some s -> (
      match Json.parse_string s with
      | Ok json -> Repl.make ~json ~path:"<inline>"
      | Error err -> print_error_message (format_json_error ~colorize:true err))
  | None ->
      print_error_message
        "REPL mode requires a JSON file or inline JSON as argument"

module Query_cmd = struct
  let run query payload debug no_color raw_output help_category =
    let colorize = not no_color in
    match help_category with
    | Some category ->
        let _ = show_help_category ~colorize category in
        ()
    | None -> (
        match query with
        | None -> usage ~colorize ()
        | Some query -> (
            let json_result =
              match payload with
              | Some f when Sys.file_exists f -> Json.parse_file f
              | Some s -> Json.parse_string s
              | None -> Json.parse_channel (Unix.in_channel_of_descr Unix.stdin)
            in
            match json_result with
            | Error err -> print_error_message (format_json_error ~colorize err)
            | Ok json -> (
                match
                  Core.run ~debug ~colorize ~raw:raw_output ~summarize:false
                    query json
                with
                | Ok results -> print_endline results
                | Error err -> print_error_message err)))

  let term =
    let open Cmdliner.Arg in
    let open Cmdliner.Term in
    let query =
      value & pos 0 (some string) None & info [] ~doc:"Query to run"
    in
    let json = value & pos 1 (some string) None & info [] ~doc:"JSON" in
    let debug =
      value & flag & info [ "d"; "debug" ] ~doc:"Activate debug mode"
    in
    let no_color =
      value & flag & info [ "c"; "no-color" ] ~doc:"Disable color in the output"
    in
    let raw_output =
      value & flag
      & info [ "r"; "raw-output" ] ~doc:"Output raw strings, not JSON texts"
    in
    let help_category =
      value
      & opt (some string) None
      & info [ "functions"; "f" ] ~docv:"CATEGORY"
          ~doc:
            "Show help for a function category. Available categories: string, \
             array, object, path, math, type, control, definition, debug"
    in
    const run $ query $ json $ debug $ no_color $ raw_output $ help_category
end

let () =
  let is_repl_command = Array.length Sys.argv > 1 && Sys.argv.(1) = "repl" in
  if is_repl_command then
    let info =
      Cmdliner.Cmd.info "query-json repl" ~version:Info.version
        ~doc:"Start interactive REPL mode with auto-completion"
    in
    let argv =
      Array.concat
        [ [| Sys.argv.(0) |]; Array.sub Sys.argv 2 (Array.length Sys.argv - 2) ]
    in
    let repl_term =
      let open Cmdliner.Arg in
      let open Cmdliner.Term in
      let json =
        value
        & pos 0 (some string) None
        & info [] ~docv:"JSON" ~doc:"JSON file or inline JSON to explore"
      in
      const run_repl $ json
    in
    let cmd = Cmdliner.Cmd.v info repl_term in
    Stdlib.exit (Cmdliner.Cmd.eval ~argv cmd)
  else
    let info =
      Cmdliner.Cmd.info "query-json" ~version:Info.version
        ~doc:"Run operations on JSON"
        ~man:
          [
            `S Cmdliner.Manpage.s_description;
            `P Info.description;
            `S Cmdliner.Manpage.s_examples;
            `P "query-json '.dependencies' package.json";
            `P "query-json '.' '[1, 2, 3]'";
            `P "query-json --functions string";
            `P "query-json repl data.json";
          ]
    in
    let cmd = Cmdliner.Cmd.v info Query_cmd.term in
    Stdlib.exit (Cmdliner.Cmd.eval cmd)
