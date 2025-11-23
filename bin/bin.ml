module Info = struct
  let version =
    match Build_info.V1.version () with
    | None -> "n/a"
    | Some v -> Build_info.V1.Version.to_string v

  let description =
    "query-json allows to write small programs to operate on top of JSON files \
     with a concise syntax. It's a faster and simpler re-implementation of jq \
     in OCaml"
end

let print_error_message ~colorize str =
  let module Chalk = Chalk.Make (struct
    let disable = not colorize
  end) in
  print_endline
    (Formatting.enter 1
    ^ Chalk.red (Chalk.bold "Error")
    ^ Chalk.red ":" ^ Formatting.indent 1 ^ str ^ Formatting.enter 1)

let usage ?(colorize = true) () =
  let open Formatting in
  let module Chalk = Chalk.Make (struct
    let disable = not colorize
  end) in
  [
    enter 1;
    Chalk.yellow "Missing query as argument";
    enter 1 ^ "Usage:" ^ enter 2 ^ Chalk.bold "query-json"
    ^ Chalk.gray " [OPTIONS] " ^ "[QUERY] [JSON]" ^ enter 2
    ^ Chalk.bold "OPTIONS";
    indent 1 ^ "-c, --no-color: Disable color in the output";
    indent 1 ^ "-r, --raw-output: Output raw strings, not JSON texts";
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
  |> print_endline

module Runtime = struct
  let run ~payload ~no_color ~verbose ~raw_output runtime =
    let colorize = not no_color in
    let input =
      match payload with
      | Some file_or_json ->
          if Sys.file_exists file_or_json then Json.parse_file file_or_json
          else Json.parse_string file_or_json
      | None ->
          let ic = Unix.in_channel_of_descr Unix.stdin in
          Json.parse_channel ic
    in
    match input with
    | Ok json -> (
        match runtime ~colorize ~verbose json with
        | Ok json ->
            json
            |> List.map
                 (Json.to_string ~colorize ~summarize:false ~raw:raw_output)
            |> List.iter print_endline
        | Error err -> print_error_message ~colorize err)
    | Error err -> print_error_message ~colorize err
end

let execution (query : string option) (payload : string option) (verbose : bool)
    (debug : bool) (no_color : bool) (raw_output : bool) =
  let colorize = not no_color in
  match query with
  | Some query -> (
      let runtime =
        Core.parse ~debug ~colorize ~verbose query
        |> Result.map (fun expr ->
            fun ~colorize ~verbose json ->
             Interpreter.execute ~colorize ~verbose expr json)
      in
      match runtime with
      | Ok runtime ->
          Runtime.run ~payload ~no_color ~verbose ~raw_output runtime
      | Error err -> print_error_message ~colorize err)
  | None -> usage ()

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
