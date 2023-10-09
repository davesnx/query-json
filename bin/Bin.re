open QueryJsonCore;
open QueryJsonCore.Console;

module Runtime = {
  type inputKind =
    | File
    | Inline;

  let run = (~kind, ~payload, ~noColor, runtime) => {
    let input =
      switch (kind, payload) {
      | (File, Some(file)) => Json.parseFile(file)
      | (Inline, Some(str)) => Json.parseString(str)
      | (_, None) =>
        let ic = Unix.(stdin |> in_channel_of_descr);
        Json.parseChannel(ic);
      };

    switch (input) {
    | Ok(json) =>
      switch (runtime(json)) {
      | Ok(json) =>
        json
        |> List.map(Json.toString(~colorize=!noColor, ~summarize=false))
        |> List.iter(print_endline)
      | Error(err) => print_endline(Console.Errors.printError(err))
      }
    | Error(err) => print_endline(Console.Errors.printError(err))
    };
  };
};

let execution =
    (
      query: option(string),
      payload: option(string),
      kind: Runtime.inputKind,
      verbose: bool,
      debug: bool,
      noColor: bool,
    ) => {
  switch (query) {
  | Some(q) =>
    Main.parse(~debug, ~verbose, q)
    |> Result.map(Compiler.compile)
    |> Result.iter(Runtime.run(~payload, ~kind, ~noColor))
  | None => print_endline(usage())
  };
};

open Cmdliner;

let query = {
  let doc = "Query to run";
  Arg.(value & pos(0, some(string), None) & info([], ~doc));
};

let json = {
  let doc = "JSON file";
  Arg.(value & pos(1, some(string), None) & info([], ~doc));
};

let kind = {
  let doc = "input kind";
  let kindEnum = Arg.enum([("file", Runtime.File), ("inline", Inline)]);
  Arg.(
    value
    & opt(kindEnum, ~vopt=Runtime.File, File)
    & info(["k", "kind"], ~doc)
  );
};

let verbose = {
  let doc = "Activate verbossity";
  Arg.(value & flag & info(["v", "verbose"], ~doc));
};

let debug = {
  let doc = "Activate debug mode";
  Arg.(value & flag & info(["d", "debug"], ~doc));
};

let noColor = {
  let doc = "Enable or disable color in the output";
  Arg.(value & flag & info(["c", "no-color"], ~doc));
};

let term =
  Term.(const(execution) $ query $ json $ kind $ verbose $ debug $ noColor);

let info =
  Cmd.info(
    "query-json",
    ~version=Info.version,
    ~doc="Run operations on JSON",
    ~man=[
      `S(Manpage.s_description),
      `P(Info.description),
      `P("query-json '.dependencies' package.json"),
      `S(Manpage.s_bugs),
      `P("Report them to " ++ Info.bugUrl),
    ],
  );

let cmd = Cmd.v(info, term);

let _ = Stdlib.exit(Cmd.eval(cmd));
