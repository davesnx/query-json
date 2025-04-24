module Info = {
  let version = "0.5.20";
  let description = "query-json is a faster and simpler re-implementation of jq in Reason Native";
  let issues_url = "https://github.com/davesnx/query-json/issues";
};

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
      _verbose: bool,
      debug: bool,
      noColor: bool,
    ) => {
  switch (query) {
  | Some(q) =>
    QueryJsonCore.parse(~debug, q)
    |> Result.map(Compiler.compile)
    |> Result.iter(Runtime.run(~payload, ~kind, ~noColor))
  | None => print_endline(QueryJsonCore.usage())
  };
};

let query = {
  Cmdliner.(
    Arg.(value & pos(0, some(string), None) & info([], ~doc="Query to run"))
  );
};

let json = {
  Cmdliner.(
    Arg.(value & pos(1, some(string), None) & info([], ~doc="JSON file"))
  );
};

let kind = {
  open Cmdliner;
  let kindEnum = Arg.enum([("file", Runtime.File), ("inline", Inline)]);
  Arg.(
    value
    & opt(kindEnum, ~vopt=Runtime.File, File)
    & info(
        ["k", "kind"],
        ~doc="Input kind, either a JSON file or inline JSON",
      )
  );
};

let verbose = {
  Cmdliner.(
    Arg.value(
      Arg.flag(
        Arg.info(
          ["v", "verbose"],
          ~doc="Activate verbossity. Not used for now",
        ),
      ),
    )
  );
};

let debug = {
  Cmdliner.(
    Arg.value(
      Arg.flag(Arg.info(~doc="Activate debug mode", ["d", "debug"])),
    )
  );
};

let color = {
  Cmdliner.(
    Arg.value(
      Arg.flag(
        Arg.info(
          ~doc="Enable or disable color in the output",
          ["c", "no-color"],
        ),
      ),
    )
  );
};

let term = {
  Cmdliner.(
    Term.(const(execution) $ query $ json $ kind $ verbose $ debug $ color)
  );
};

let info =
  Cmdliner.(
    Cmd.info(
      "query-json",
      ~version=Info.version,
      ~doc="Run operations on JSON",
      ~man=[
        `S(Manpage.s_description),
        `P(Info.description),
        `P("query-json '.dependencies' package.json"),
        `S(Manpage.s_bugs),
        `P("Report them to " ++ Info.issues_url),
      ],
    )
  );

let cmd = Cmdliner.Cmd.v(info, term);

let _ = Stdlib.exit(Cmdliner.Cmd.eval(cmd));
