let parse: (~debug: bool=?, string) => result(Ast.expression, string);
let run: (string, string) => result(string, string);
let printError: string => string;
let usage: unit => string;
