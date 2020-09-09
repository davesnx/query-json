open Source;
open Source.Compiler;

type inputKind =
  | File
  | Inline;

let run = (query: string, file: string, _verbose: bool) => {
  let json = Yojson.Basic.from_file(file);
  let program = Main.parse(query);
  let runtime = compile(program);

  Yojson.Basic.pretty_to_string(runtime(json)) |> print_endline;
};

open Cmdliner;
open Term;

let query = {
  let doc = "Query to run";
  Arg.(value & pos(0, string, ".") & info([], ~docv="QUERY", ~doc));
};

let json = {
  let doc = "JSON file";
  Arg.(value & pos(1, file, "package.json") & info([], ~docv="FILE", ~doc));
};

let verbose = {
  let doc = "Activate verbossity";
  Arg.(value & flag & info(["v", "verbose"], ~doc));
};

let cmd = {
  (
    Term.(const(run) $ query $ json $ verbose),
    Term.info(
      "q",
      ~version=Info.version,
      ~doc="Run operations on JSON",
      ~exits=Term.default_exits,
      ~man=[
        `S(Manpage.s_description),
        `P("$(tname)" ++ Info.description),
        `P("q '.dependencies' package.json"),
        `S(Manpage.s_bugs),
        `P("Report them to ."),
      ],
    ),
  );
};

exit(eval(cmd));
