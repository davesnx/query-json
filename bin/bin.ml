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

let print_error_message ~colorize str =
  let open Formatting in
  let open Ansi.To_string (struct
    let colorize = colorize
  end) in
  print_endline
    (enter 1 ^ red (bold "Error") ^ red ":" ^ indent 1 ^ str ^ enter 1)

let usage ?(colorize = true) () =
  let open Formatting in
  let open Ansi.To_string (struct
    let colorize = colorize
  end) in
  [
    enter 1;
    yellow "Missing query as argument";
    enter 1 ^ "Usage:" ^ enter 2 ^ bold "query-json" ^ gray " [OPTIONS] "
    ^ "[QUERY] [JSON]" ^ enter 2 ^ bold "OPTIONS";
    indent 1 ^ "-c, --no-color: Disable color in the output";
    indent 1 ^ "-r, --raw-output: Output raw strings, not JSON texts";
    indent 1 ^ "-v, --verbose: Activate verbossity";
    indent 1 ^ "-d, --debug: Print AST";
    indent 1 ^ "--version: Show version information." ^ enter 2
    ^ bold "EXAMPLES";
    indent 1 ^ "query-json '.dependencies' package.json";
    indent 1 ^ "query-json '.' <<< '[1, 2, 3]'" ^ enter 2 ^ bold "MORE";
    indent 1 ^ " https://github.com/davesnx/query-json";
    enter 1;
  ]
  |> String.concat (enter 1)
  |> print_endline

let ( let* ) = Result.bind

let execution query payload verbose debug no_color raw_output =
  let colorize = not no_color in
  match query with
  | None -> usage ()
  | Some query -> (
      let output =
        let* expr = Core.parse ~debug ~colorize ~verbose query in
        let* json =
          match payload with
          | Some f when Sys.file_exists f -> Json.parse_file f
          | Some s -> Json.parse_string s
          | None -> Json.parse_channel (Unix.in_channel_of_descr Unix.stdin)
        in
        Interpreter.execute ~colorize ~verbose expr json
      in
      match output with
      | Ok results ->
          List.iter
            (Json.print ~colorize ~summarize:false ~raw:raw_output)
            results
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
  let term =
    let open Cmdliner.Term in
    const execution $ query $ json $ verbose $ debug $ color $ raw_output
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
        ]
  in
  Stdlib.exit (Cmdliner.Cmd.eval (Cmdliner.Cmd.v info term))
