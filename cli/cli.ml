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

let print_error_message ~colorize:_ str =
  print_endline (Console_style.enter 1 ^ str ^ Console_style.enter 1)

let usage ?(colorize = true) () =
  let t = Console_style.make ~colorize in
  [
    Console_style.enter 1;
    t.yellow "Missing query as argument";
    Console_style.enter 1 ^ "Usage:" ^ Console_style.enter 2
    ^ t.bold "query-json" ^ t.gray " [OPTIONS] " ^ "[QUERY] [JSON]"
    ^ Console_style.enter 2 ^ t.bold "OPTIONS";
    Console_style.indent 1 ^ "-c, --no-color: Disable color in the output";
    Console_style.indent 1
    ^ "-r, --raw-output: Output raw strings, not JSON texts";
    Console_style.indent 1 ^ "-v, --verbose: Activate verbossity";
    Console_style.indent 1 ^ "-d, --debug: Print AST";
    Console_style.indent 1 ^ "--repl: Start interactive REPL mode";
    Console_style.indent 1 ^ "--version: Show version information."
    ^ Console_style.enter 2 ^ t.bold "EXAMPLES";
    Console_style.indent 1 ^ "query-json '.dependencies' package.json";
    Console_style.indent 1 ^ "query-json '.' '[1, 2, 3]'";
    Console_style.indent 1 ^ "query-json --repl package.json";
    Console_style.indent 1 ^ "query-json --repl '[1, 2, 3]'"
    ^ Console_style.enter 2 ^ t.bold "MORE";
    Console_style.indent 1 ^ " https://github.com/davesnx/query-json";
    Console_style.enter 1;
  ]
  |> String.concat (Console_style.enter 1)
  |> print_endline

let ( let* ) = Result.bind

let repl_mode payload =
  match payload with
  | None ->
      print_error_message ~colorize:true
        "Error: REPL mode requires a JSON file path or inline JSON";
      Stdlib.exit 1
  | Some payload_str -> (
      let json_result, path =
        if Sys.file_exists payload_str then
          (Json.parse_file payload_str, payload_str)
        else (Json.parse_string payload_str, "inline")
      in
      match json_result with
      | Ok json -> Repl.make ~json ~path
      | Error err ->
          print_error_message ~colorize:true err;
          Stdlib.exit 1)

let execution query payload verbose debug no_color raw_output repl =
  let colorize = not no_color in
  if repl then
    (* In repl mode, use query as JSON payload if payload is None *)
    let json_payload = match payload with Some p -> Some p | None -> query in
    match json_payload with
    | None ->
        print_error_message ~colorize
          "Error: REPL mode requires a JSON file path or inline JSON";
        Stdlib.exit 1
    | Some _ -> repl_mode json_payload
  else
    match query with
    | None -> usage ()
    | Some query -> (
        let output =
          let* json =
            match payload with
            | Some f when Sys.file_exists f -> Json.parse_file f
            | Some s -> Json.parse_string s
            | None -> Json.parse_channel (Unix.in_channel_of_descr Unix.stdin)
          in
          Core.run ~debug ~colorize ~verbose ~raw:raw_output ~summarize:false
            query json
        in
        match output with
        | Ok results -> print_endline results
        | Error err -> print_error_message ~colorize err)

let () =
  let open Cmdliner.Arg in
  let query = value & pos 0 (some string) None & info [] ~doc:"Query to run" in
  let json = value & pos 1 (some string) None & info [] ~doc:"JSON" in
  let verbose =
    value & flag & info [ "v"; "verbose" ] ~doc:"Activate verbossity"
  in
  let debug = value & flag & info [ "d"; "debug" ] ~doc:"Activate debug mode" in
  let color =
    value & flag
    & info [ "c"; "no-color" ] ~doc:"Enable or disable color in the output"
  in
  let raw_output =
    value & flag
    & info [ "r"; "raw-output" ] ~doc:"Output raw strings, not JSON texts"
  in
  let repl =
    value & flag & info [ "repl" ] ~doc:"Start interactive REPL mode"
  in
  let term =
    let open Cmdliner.Term in
    const execution $ query $ json $ verbose $ debug $ color $ raw_output $ repl
  in
  let info =
    Cmdliner.Cmd.info "query-json" ~version:Info.version
      ~doc:"Run operations on JSON" ~docs:"Run operations on JSON"
      ~man:
        [
          `S Cmdliner.Manpage.s_description;
          `P Info.description;
          `S Cmdliner.Manpage.s_examples;
          `P "query-json '.dependencies' package.json";
          `P "query-json '.' <<< '[1, 2, 3]'";
          `P "query-json --repl package.json";
          `P "query-json --repl '[1, 2, 3]'";
        ]
  in
  Stdlib.exit (Cmdliner.Cmd.eval (Cmdliner.Cmd.v info term))
