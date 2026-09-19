(* The REPL links the Mosaic TUI stack. Its module initializers (cmarkit's
   Unicode tables above all) cost about 3 ms and 8 MB per process, so the REPL
   ships as its own binary and plain `query-json` queries keep a fast start. *)

let version =
  Option.fold ~none:"n/a" ~some:Build_info.V1.Version.to_string
    (Build_info.V1.version ())

let print_error_message str =
  print_endline (Console_style.enter 1 ^ str ^ Console_style.enter 1)

let usage () =
  let t = Console_style.make ~colorize:true in
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

let start ~json ~path ~query =
  match json with
  | Ok json ->
      Repl_ui.make ~json ~path ~query
  | Error err ->
      print_error_message err;
      Stdlib.exit 1

let from_stdin query =
  if Unix.isatty Unix.stdin then (
    usage ();
    Stdlib.exit 1
  );
  let json = Json.parse_channel (Unix.in_channel_of_descr Unix.stdin) in
  if not (reconnect_stdin_to_tty ()) then (
    print_error_message
      "REPL requires an interactive terminal. No TTY available.";
    Stdlib.exit 1
  );
  start ~json ~path:"<stdin>" ~query

let execution position_0 position_1 =
  match (position_0, position_1) with
  | query, Some file_or_json ->
      let query = Option.value ~default:"." query in
      if Sys.file_exists file_or_json then
        start ~json:(Json.parse_file file_or_json) ~path:file_or_json ~query
      else
        start ~json:(Json.parse_string file_or_json) ~path:"<inline>" ~query
  | Some file, None when Sys.file_exists file ->
      start ~json:(Json.parse_file file) ~path:file ~query:"."
  | query, None ->
      from_stdin (Option.value ~default:"." query)

let () =
  set_binary_mode_out stdout true;
  let open Cmdliner.Arg in
  let query = value & pos 0 (some string) None & info [] ~doc:"Initial query" in
  let json =
    value & pos 1 (some string) None & info [] ~doc:"JSON file or inline JSON"
  in
  let term = Cmdliner.Term.(const execution $ query $ json) in
  let info =
    Cmdliner.Cmd.info "query-json-repl" ~version
      ~doc:"Interactive REPL for query-json"
      ~man:
        [
          `S Cmdliner.Manpage.s_description;
          `P
            "Explore a JSON document interactively with autocomplete. \
             $(b,query-json --repl) launches this binary.";
          `S Cmdliner.Manpage.s_examples;
          `P "query-json-repl package.json";
          `P "query-json-repl '.dependencies' package.json";
          `P "cat data.json | query-json-repl";
        ]
  in
  Stdlib.exit (Cmdliner.Cmd.eval (Cmdliner.Cmd.v info term))
