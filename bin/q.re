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
      _colorize: bool,
    ) => {
  let json =
    switch (kind) {
    | File => Yojson.Basic.from_file(input)
    | Inline => Yojson.Basic.from_string(input)
    };

  Main.parse(~debug, query)
  |> Result.map(compile)
  |> Result.map(runtime =>
       runtime(json) |> Yojson.Basic.pretty_to_string |> print_endline
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

let colorize = {
  let doc = "Enable or disable color in the output";
  Arg.(value & flag & info(["c", "colorize"], ~doc));
};

let cmd = {
  (
    Term.(const(run) $ query $ json $ kind $ verbose $ debug $ colorize),
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
