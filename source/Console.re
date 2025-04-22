module Formatting = {
  let indent = n => String.make(n * 2, ' ');
  let enter = n => String.make(n, '\n');

  let doubleQuotes = str => "\"" ++ str ++ "\"";
  let singleQuotes = str => "'" ++ str ++ "'";
};

module Errors = {
  let printError = str =>
    Formatting.enter(1)
    ++ Chalk.red(Chalk.bold("Error"))
    ++ Chalk.red(":")
    ++ Formatting.indent(1)
    ++ str
    ++ Formatting.enter(1);

  let positionToString = (start, end_) =>
    Printf.sprintf(
      "[line: %d, char: %d-%d]",
      start.Lexing.pos_lnum,
      start.Lexing.pos_cnum - start.Lexing.pos_bol,
      end_.Lexing.pos_cnum - end_.Lexing.pos_bol,
    );

  let extractExn = (str: string) => {
    let first = String.index_opt(str, '(');
    let last = String.rindex_opt(str, ')');
    switch (first, last) {
    | (Some(firstIndex), Some(lastIndex)) =>
      let first = firstIndex + 2;
      let length = lastIndex - firstIndex - 1 - 2;
      String.sub(str, first, length);
    | (_, _) => str
    };
  };

  let make = (~input, ~start: Lexing.position, ~end_: Lexing.position) => {
    let pointerRange = String.make(end_.pos_cnum - start.pos_cnum, '^');

    Chalk.red(Chalk.bold("Parse error: "))
    ++ "Problem parsing at position "
    ++ positionToString(start, end_)
    ++ Formatting.enter(2)
    ++ "Input:"
    ++ Formatting.indent(1)
    ++ Chalk.green(Chalk.bold(input))
    ++ Formatting.enter(1)
    ++ Formatting.indent(4)
    ++ String.make(start.pos_cnum, ' ')
    ++ Chalk.gray(pointerRange);
  };

  let renamed = (f, name) =>
    Formatting.singleQuotes(f)
    ++ " is not valid in q, use "
    ++ Formatting.singleQuotes(name)
    ++ " instead";

  let notImplemented = f =>
    Formatting.singleQuotes(f) ++ " is not implemented";

  let missing = f =>
    Formatting.singleQuotes(f)
    ++ " looks like a function and maybe is not implemented or missing in the parser. Either way, could you open an issue 'https://github.com/davesnx/query-json/issues/new'";
};

let usage = () =>
  Formatting.enter(1)
  ++ Chalk.bold("query-json [OPTIONS] [QUERY] [JSON]")
  ++ Formatting.enter(2)
  ++ "OPTIONS:"
  ++ Formatting.enter(1)
  ++ Formatting.indent(2)
  ++ "-c, --no-color: Enable or disable color in the output"
  ++ Formatting.enter(1)
  ++ Formatting.indent(2)
  ++ "-k [VAL], --kind[=VAL]: input kind. "
  ++ Formatting.doubleQuotes("file")
  ++ " | "
  ++ Formatting.doubleQuotes("inline")
  ++ Formatting.enter(1)
  ++ Formatting.indent(2)
  ++ "-v, --verbose: Activate verbossity"
  ++ Formatting.enter(1)
  ++ Formatting.indent(2)
  ++ "-d, --debug: Print AST"
  ++ Formatting.enter(1)
  ++ Formatting.indent(2)
  ++ "--version: Show version information."
  ++ Formatting.enter(2)
  ++ "EXAMPLE:"
  ++ " query-json '.dependencies' package.json"
  ++ Formatting.enter(2)
  ++ "MORE: https://github.com/davesnx/query-json"
  ++ Formatting.enter(1);
