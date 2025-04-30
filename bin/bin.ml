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

module Runtime = struct
  type input_kind = File | Inline

  let run ~kind ~payload ~no_color runtime =
    let input =
      match (kind, payload) with
      | File, Some file -> Json.parse_file file
      | Inline, Some str -> Json.parse_string str
      | _, None ->
          let ic = Unix.in_channel_of_descr Unix.stdin in
          Json.parse_channel ic
    in
    match input with
    | Ok json -> (
        match runtime json with
        | Ok json ->
            json
            |> List.map
                 (Json.to_string ~colorize:(not no_color) ~summarize:false)
            |> List.iter print_endline
        | Error err -> print_endline (Console.Errors.print_error err))
    | Error err -> print_endline (Console.Errors.print_error err)
end

let execution (query : string option) (payload : string option)
    (kind : Runtime.input_kind) (_verbose : bool) (debug : bool)
    (no_color : bool) =
  match query with
  | Some q ->
      let r = Core.parse ~debug q |> Result.map Compiler.compile in
      let () =
        Result.iter_error
          (fun err -> print_endline (Console.Errors.print_error err))
          r
      in
      Result.iter (Runtime.run ~payload ~kind ~no_color) r
  | None -> print_endline (Console.usage ())

let () =
  let open Cmdliner.Arg in
  let query = value & pos 0 (some string) None & info [] ~doc:"Query to run" in
  let json = value & pos 1 (some string) None & info [] ~doc:"JSON" in
  let kind =
    let kind_enum =
      enum [ ("file", Runtime.File); ("inline", Runtime.Inline) ]
    in
    value
    & opt kind_enum ~vopt:Runtime.File Runtime.File
    & info [ "k"; "kind" ] ~doc:"Input kind, either a JSON file or inline JSON"
  in
  let verbose =
    value & flag & info [ "v"; "verbose" ] ~doc:"Activate verbossity"
  in
  let debug = value & flag & info [ "d"; "debug" ] ~doc:"Activate debug mode" in
  let color =
    value & flag
    & info [ "c"; "no-color" ] ~doc:"Enable or disable color in the output"
  in
  let term =
    let open Cmdliner.Term in
    const execution $ query $ json $ kind $ verbose $ debug $ color
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
