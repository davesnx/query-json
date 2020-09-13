open Source;
open Source.Compiler;

type inputKind =
  | File
  | Inline;

let run =
    (
      query: string,
      input: string,
      kind: inputKind,
      _verbose: bool,
      debug: bool,
      noColor: bool,
    ) => {
  let json =
    switch (kind) {
    | File => Source.Json.parseFile(input)
    | Inline => Source.Json.parseString(input)
    };

  Main.parse(~debug, query)
  |> Result.map(compile)
  |> Result.map(runtime => runtime(json))
  |> Result.map(res =>
       res
       |> Result.map(o =>
            Source.Json.toString(o, ~colorize=!noColor, ~summarize=false)
            |> print_endline
          )
       |> Result.map_error(print_endline)
     )
  |> Result.map_error(print_endline);
};

open Cmdliner;
open Term;

let query = {
  let doc = "Query to run";
  Arg.(value & pos(0, string, ".") & info([], ~doc));
};

let json = {
  let doc = "JSON file";
  Arg.(required & pos(1, some(string), None) & info([], ~doc));
};

let kind = {
  let doc = "input kind";
  let kindEnum = Arg.enum([("file", File), ("inline", Inline)]);
  Arg.(value & opt(kindEnum, ~vopt=File, File) & info(["k", "kind"], ~doc));
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

let cmd = {
  (
    Term.(const(run) $ query $ json $ kind $ verbose $ debug $ noColor),
    Term.info(
      "q",
      ~version=Info.version,
      ~doc="Run operations on JSON",
      ~exits=Term.default_exits,
      ~man=[
        `S(Manpage.s_description),
        `P(Info.description),
        `P("q '.dependencies' package.json"),
        `S(Manpage.s_bugs),
        `P("Report them to " ++ Info.bugUrl),
      ],
    ),
  );
};

exit(eval(cmd));
