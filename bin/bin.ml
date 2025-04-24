module Info = struct
  let version = "0.5.20"

  let description =
    "query-json is a faster and simpler re-implementation of jq in Reason \
     Native"

  let issues_url = "https://github.com/davesnx/query-json/issues"
end

module Runtime = struct
  type inputKind = File | Inline

  let run ~kind ~payload ~noColor runtime =
    let input =
      match (kind, payload) with
      | File, Some file -> Json.parseFile file
      | Inline, Some str -> Json.parseString str
      | _, None ->
          let ic =
            let open Unix in
            stdin |> in_channel_of_descr
          in
          Json.parseChannel ic
    in
    match input with
    | Ok json -> (
        match runtime json with
        | Ok json ->
            json
            |> List.map (Json.toString ~colorize:(not noColor) ~summarize:false)
            |> List.iter print_endline
        | Error err -> print_endline (Console.Errors.printError err))
    | Error err -> print_endline (Console.Errors.printError err)
end

let execution (query : string option) (payload : string option)
    (kind : Runtime.inputKind) (_verbose : bool) (debug : bool) (noColor : bool)
    =
  match query with
  | Some q ->
      QueryJsonCore.parse ~debug q
      |> Result.map Compiler.compile
      |> Result.iter (Runtime.run ~payload ~kind ~noColor)
  | None -> print_endline (Console.usage ())

let () =
  let open Cmdliner.Arg in
  let query = value & pos 0 (some string) None & info [] ~doc:"Query to run" in
  let json = value & pos 1 (some string) None & info [] ~doc:"JSON file" in
  let kind =
    let kindEnum = enum [ ("file", Runtime.File); ("inline", Inline) ] in
    value
    & opt kindEnum ~vopt:Runtime.File File
    & info [ "k"; "kind" ] ~doc:"Input kind, either a JSON file or inline JSON"
  in
  let verbose =
    value & flag
    & info [ "v"; "verbose" ] ~doc:"Activate verbossity. Not used for now"
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
      ~doc:"Run operations on JSON"
      ~man:
        [
          `S Cmdliner.Manpage.s_description;
          `P Info.description;
          `P "query-json '.dependencies' package.json";
          `S Cmdliner.Manpage.s_bugs;
          `P ("Report them to " ^ Info.issues_url);
        ]
  in
  Stdlib.exit (Cmdliner.Cmd.eval (Cmdliner.Cmd.v info term))
