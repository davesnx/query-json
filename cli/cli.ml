module Info = struct
  let version =
    match Build_info.V1.version () with
    | None -> "n/a"
    | Some v -> Build_info.V1.Version.to_string v

  let description =
    "A fast, friendly and portable JSON query language for the command line. \
     query-json lets you slice, filter, and transform JSON data with a \
     concise, expressive syntax with a focus on ease of use."
end

let print_error_message ~colorize:_ str =
  print_endline (Console_style.enter 1 ^ str ^ Console_style.enter 1)

let usage ?(colorize = true) () =
  let t = Console_style.make ~colorize in
  [
    Console_style.enter 0;
    t.yellow "Missing query as argument";
    Console_style.enter 1 ^ "Usage:" ^ Console_style.enter 2
    ^ t.bold "query-json" ^ t.gray " [OPTIONS] " ^ "[QUERY] [JSON]"
    ^ Console_style.enter 2 ^ Console_style.indent 1 ^ t.bold " OPTIONS";
    Console_style.indent 3 ^ "-c, --no-color: Disable color in the output";
    Console_style.indent 3
    ^ "-r, --raw-output: Output raw strings, not JSON texts";
    Console_style.indent 3
    ^ "-n, --null-input: Run filter with null as input (no input read)";
    Console_style.indent 3 ^ "-v, --verbose: Activate verbossity";
    Console_style.indent 3 ^ "-d, --debug: Print AST";
    Console_style.indent 3 ^ "--repl: Start interactive REPL mode";
    Console_style.indent 3 ^ "--version: Show version information."
    ^ Console_style.enter 2 ^ Console_style.indent 1 ^ t.bold "EXAMPLES";
    Console_style.indent 3 ^ "query-json '.dependencies' package.json";
    Console_style.indent 3 ^ "query-json '.' '[1, 2, 3]'";
    Console_style.indent 3 ^ "query-json --repl package.json";
    Console_style.indent 3 ^ "query-json --repl '[1, 2, 3]'"
    ^ Console_style.enter 2 ^ Console_style.indent 1 ^ t.bold "MORE";
    Console_style.indent 3 ^ "https://github.com/davesnx/query-json";
    Console_style.enter 1;
  ]
  |> String.concat (Console_style.enter 1)
  |> print_endline

let repl_usage ?(colorize = true) () =
  let t = Console_style.make ~colorize in
  [
    Console_style.enter 0;
    t.yellow "Missing JSON file or inline JSON for REPL mode";
    Console_style.enter 1 ^ "Usage:" ^ Console_style.enter 2
    ^ t.bold "query-json" ^ " --repl "
    ^ t.gray "[JSON_FILE | INLINE_JSON]"
    ^ Console_style.enter 2 ^ Console_style.indent 1 ^ t.bold "EXAMPLES";
    Console_style.indent 3 ^ "query-json --repl package.json";
    Console_style.indent 3 ^ "query-json --repl '[1, 2, 3]'";
    Console_style.indent 3 ^ "query-json --repl '{\"name\": \"test\"}'";
    Console_style.indent 3 ^ "cat data.json | query-json --repl";
    Console_style.enter 1;
  ]
  |> String.concat (Console_style.enter 1)
  |> print_endline

let ( let* ) = Result.bind

(* When JSON is piped via stdin (e.g., `cat data.json | query-json --repl`), stdin is consumed by the JSON parser. The REPL then needs stdin for interactive keyboard input, but it's exhausted/closed from the pipe.

   This function reconnects stdin to /dev/tty (the controlling terminal),
   allowing the REPL to receive keyboard input after reading piped JSON.
   This is the standard Unix pattern used by programs like fzf, less, and vim. *)
let reconnect_stdin_to_tty () =
  try
    let tty_fd = Unix.openfile "/dev/tty" [ Unix.O_RDONLY ] 0 in
    Unix.dup2 tty_fd Unix.stdin;
    Unix.close tty_fd;
    true
  with Unix.Unix_error _ -> false

let execution position_0 position_1 verbose debug no_color raw_output null_input
    repl =
  let colorize = not no_color in
  if repl then
    match (position_1, position_0) with
    | Some file_or_json, query -> (
        let initial_query = Option.value ~default:"." query in
        let json =
          if Sys.file_exists file_or_json then Json.parse_file file_or_json
          else Json.parse_string file_or_json
        in
        let path =
          if Sys.file_exists file_or_json then file_or_json else "<inline>"
        in
        match json with
        | Ok json -> Repl.make ~json ~path ~query:initial_query
        | Error err ->
            print_error_message ~colorize err;
            Stdlib.exit 1)
    | None, Some file_or_json when Sys.file_exists file_or_json -> (
        match Json.parse_file file_or_json with
        | Ok json -> Repl.make ~json ~path:file_or_json ~query:"."
        | Error err ->
            print_error_message ~colorize err;
            Stdlib.exit 1)
    | None, Some query -> (
        if Unix.isatty Unix.stdin then (
          repl_usage ~colorize ();
          Stdlib.exit 1)
        else
          let json_result =
            Json.parse_channel (Unix.in_channel_of_descr Unix.stdin)
          in
          if not (reconnect_stdin_to_tty ()) then (
            print_error_message ~colorize
              "REPL requires an interactive terminal. No TTY available.";
            Stdlib.exit 1);
          match json_result with
          | Ok json -> Repl.make ~json ~path:"<stdin>" ~query
          | Error err ->
              print_error_message ~colorize err;
              Stdlib.exit 1)
    | None, None -> (
        if Unix.isatty Unix.stdin then (
          repl_usage ~colorize ();
          Stdlib.exit 1)
        else
          let json = Json.parse_channel (Unix.in_channel_of_descr Unix.stdin) in
          if not (reconnect_stdin_to_tty ()) then (
            print_error_message ~colorize
              "REPL requires an interactive terminal. No TTY available.";
            Stdlib.exit 1);
          match json with
          | Ok json -> Repl.make ~json ~path:"<stdin>" ~query:"."
          | Error err ->
              print_error_message ~colorize err;
              Stdlib.exit 1)
  else
    match position_0 with
    | None -> usage ()
    | Some query -> (
        let output =
          let* json =
            if null_input then Ok `Null
            else
              match position_1 with
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
  let null_input =
    value & flag
    & info [ "n"; "null-input" ]
        ~doc:"Don't read any input. Run filter with null as input"
  in
  let repl =
    value & flag & info [ "repl" ] ~doc:"Start interactive REPL mode"
  in
  let term =
    let open Cmdliner.Term in
    const execution $ query $ json $ verbose $ debug $ color $ raw_output
    $ null_input $ repl
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
          `P "query-json -n '{a: 1, b: 2}'";
          `P "query-json --repl package.json";
          `P "query-json --repl '[1, 2, 3]'";
          `P "cat data.json | query-json --repl";
        ]
  in
  Stdlib.exit (Cmdliner.Cmd.eval (Cmdliner.Cmd.v info term))
