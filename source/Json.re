open Printf;
open Console;

type t = Yojson.Basic.t;
include Yojson.Basic.Util;

let (pp_print_string, pp_print_bool, pp_print_list, fprintf, asprintf) =
  Format.(pp_print_string, pp_print_bool, pp_print_list, fprintf, asprintf);

/*
 TODO: Return result(string, string)

 let parseString = str =>
    try(Ok(Yojson.Basic.from_string(str))) {
    | e => Error(Printexc.to_string(e))
    };

  let parseFile = file =>
    try(Ok(Yojson.Basic.from_file(file))) {
    | e => Error(Printexc.to_string(e))
    };
   */

let parseFile = Yojson.Basic.from_file;
let parseString = Yojson.Basic.from_string;

let string = str => {
  let buf = Buffer.create(String.length(str) * 5 / 4);
  for (i in 0 to String.length(str) - 1) {
    switch (str.[i]) {
    | '\\' => Buffer.add_string(buf, {|\\|})
    | '"' => Buffer.add_string(buf, {|\"|})
    | '\n' => Buffer.add_string(buf, {|\n|})
    | '\t' => Buffer.add_string(buf, {|\t|})
    | '\r' => Buffer.add_string(buf, {|\r|})
    | '\b' => Buffer.add_string(buf, {|\b|})
    | ('\000' .. '\031' | '\127') as c =>
      Printf.bprintf(buf, "\\u%04X", Char.code(c))
    | c => Buffer.add_char(buf, c)
    };
  };
  Buffer.contents(buf);
};

let quotes = str => "\"" ++ str ++ "\"";
let array = Easy_format.list;
let record = Easy_format.list;

let id = (i: string): string => i;

module Color = {
  let rec format = (json: t) =>
    switch (json) {
    | `Null => Easy_format.Atom("null" |> Chalk.green, Easy_format.atom)
    | `Bool(b) =>
      Easy_format.Atom(string_of_bool(b) |> Chalk.green, Easy_format.atom)
    | `Int(i) =>
      Easy_format.Atom(i |> string_of_int |> Chalk.green, Easy_format.atom)
    | `Float(f) =>
      Easy_format.Atom(f |> string_of_float |> Chalk.green, Easy_format.atom)
    | `String(s) =>
      Easy_format.Atom(string(s) |> quotes |> Chalk.green, Easy_format.atom)
    | `List([]) => Easy_format.Atom("[]", Easy_format.atom)
    | `List(l) =>
      Easy_format.List(("[", ",", "]", array), List.map(format, l))
    | `Assoc([]) => Easy_format.Atom("{}", Easy_format.atom)
    | `Assoc(l) =>
      Easy_format.List(("{", ",", "}", record), List.map(format_field, l))
    }
  and format_field = ((name, json)) => {
    let s =
      sprintf("%s:", string(name) |> quotes |> Chalk.blue |> Chalk.bold);

    Easy_format.Label(
      (Easy_format.Atom(s, Easy_format.atom), Easy_format.label),
      format(json),
    );
  };
};

module Summarize = {
  let rec format = (json: t) =>
    switch (json) {
    | `Null => Easy_format.Atom("null" |> Chalk.green, Easy_format.atom)
    | `Bool(b) =>
      Easy_format.Atom(string_of_bool(b) |> Chalk.green, Easy_format.atom)
    | `Int(i) =>
      Easy_format.Atom(i |> string_of_int |> Chalk.green, Easy_format.atom)
    | `Float(f) =>
      Easy_format.Atom(f |> string_of_float |> Chalk.green, Easy_format.atom)
    | `String(s) =>
      Easy_format.Atom(string(s) |> quotes |> Chalk.green, Easy_format.atom)
    | `List([]) => Easy_format.Atom("[]", Easy_format.atom)
    | `List(l) =>
      Easy_format.List(("[", ",", "]", array), List.map(format, l))
    | `Assoc([]) => Easy_format.Atom("{}", Easy_format.atom)
    | `Assoc(l) =>
      Easy_format.List(("{", ",", "}", record), List.map(format_field, l))
    }
  and format_field = ((name, json)) => {
    let s =
      sprintf("%s:", string(name) |> quotes |> Chalk.blue |> Chalk.bold);

    Easy_format.Label(
      (Easy_format.Atom(s, Easy_format.atom), Easy_format.label),
      format(json),
    );
  };
};

module NoColor = {
  let rec format = (json: t) =>
    switch (json) {
    | `Null => Easy_format.Atom("null", Easy_format.atom)
    | `Bool(b) => Easy_format.Atom(string_of_bool(b), Easy_format.atom)
    | `Int(i) => Easy_format.Atom(i |> string_of_int, Easy_format.atom)
    | `Float(f) => Easy_format.Atom(f |> string_of_float, Easy_format.atom)
    | `String(s) => Easy_format.Atom(string(s) |> quotes, Easy_format.atom)
    | `List([]) => Easy_format.Atom("[]", Easy_format.atom)
    | `List(l) =>
      Easy_format.List(("[", ",", "]", array), List.map(format, l))
    | `Assoc([]) => Easy_format.Atom("{}", Easy_format.atom)
    | `Assoc(l) =>
      Easy_format.List(("{", ",", "}", record), List.map(format_field, l))
    }
  and format_field = ((name, json)) => {
    let s = sprintf("%s:", string(name) |> quotes);

    Easy_format.Label(
      (Easy_format.Atom(s, Easy_format.atom), Easy_format.label),
      format(json),
    );
  };
};

let toString = (json: t, ~colorize, ~summarize) =>
  switch (colorize, summarize) {
  | (true, _) => Easy_format.Pretty.to_string(Color.format(json))
  | (false, false) => Easy_format.Pretty.to_string(NoColor.format(json))
  | (_, true) => Easy_format.Pretty.to_string(Summarize.format(json))
  };
