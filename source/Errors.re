open Console;

let printError = str =>
  enter(1)
  ++ Chalk.red(Chalk.bold("Error"))
  ++ Chalk.red(":")
  ++ indent(1)
  ++ str
  ++ enter(1);

let renamed = (f, name) =>
  "'" ++ f ++ "' is not valid in q, use '" ++ name ++ "' instead";
let notImplemented = f => "'" ++ f ++ "' is not implemented";
let missing = f =>
  "'"
  ++ f
  ++ "' looks like a function and maybe is not implemented or missing in the parser. Either way, could you open an issue 'https://github.com/davesnx/query-json/issues/new'";

let keyWithString = k =>
  "."
  ++ string_of_int(int_of_float(k))
  ++ " is not valid. If you want to access a field that is a number, use double-quotes:"
  ++ "'."
  ++ doubleQuotes(string_of_int(int_of_float(k)))
  ++ "'";
