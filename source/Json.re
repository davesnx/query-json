include Yojson.Safe;
include Yojson.Safe.Util;

let quotes = str => "\"" ++ str ++ "\"";

let parseString = str =>
  try(Ok(Yojson.Safe.from_string(str))) {
  | e =>
    Error(Printexc.to_string(e) ++ " There was an error reading the string")
  };

let parseFile = file =>
  try(Ok(Yojson.Safe.from_file(file))) {
  | e =>
    Error(Printexc.to_string(e) ++ " There was an error reading the file")
  };

let parseChannel = channel =>
  try(Ok(Yojson.Safe.from_channel(channel))) {
  | e =>
    Error(
      Printexc.to_string(e)
      ++ " There was an error reading from standard input",
    )
  };

let encode = str => {
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

let float_to_string = float =>
  if (Stdlib.Float.equal(Stdlib.Float.round(float), float)) {
    float |> Float.to_int |> Int.to_string;
  } else {
    Printf.sprintf("%g", float);
  };

module Color = {
  let rec format = (json: t) =>
    switch (json) {
    | `Null => Easy_format.Atom(Chalk.green("null"), Easy_format.atom)
    | `Bool(b) =>
      Easy_format.Atom(Chalk.green(Bool.to_string(b)), Easy_format.atom)
    | `Int(i) =>
      Easy_format.Atom(Chalk.green(Int.to_string(i)), Easy_format.atom)
    | `Float(f) =>
      Easy_format.Atom(Chalk.green(float_to_string(f)), Easy_format.atom)
    | `String(s) =>
      Easy_format.Atom(Chalk.green(quotes(encode(s))), Easy_format.atom)
    | `Intlit(s) => Easy_format.Atom(Chalk.green(s), Easy_format.atom)
    | `Variant(s, _opt) =>
      Easy_format.Atom(Chalk.green(encode(s)), Easy_format.atom)
    | `Tuple([])
    | `List([]) => Easy_format.Atom("[]", Easy_format.atom)
    | `Tuple(l)
    | `List(l) =>
      Easy_format.List(
        ("[", ",", "]", Easy_format.list),
        List.map(format, l),
      )
    | `Assoc([]) => Easy_format.Atom("{}", Easy_format.atom)
    | `Assoc(l) =>
      Easy_format.List(
        ("{", ",", "}", Easy_format.list),
        List.map(format_field, l),
      )
    }
  and format_field = ((name, json)) => {
    let s =
      Printf.sprintf(
        "%s:",
        name |> encode |> quotes |> Chalk.blue |> Chalk.bold,
      );

    Easy_format.Label(
      (Easy_format.Atom(s, Easy_format.atom), Easy_format.label),
      format(json),
    );
  };
};

module Summarize = {
  let rec format = (json: t) =>
    switch (json) {
    | `Null => Easy_format.Atom("null", Easy_format.atom)
    | `Bool(b) => Easy_format.Atom(Bool.to_string(b), Easy_format.atom)
    | `Int(i) => Easy_format.Atom(Int.to_string(i), Easy_format.atom)
    | `Intlit(s) => Easy_format.Atom(s, Easy_format.atom)
    | `Float(f) => Easy_format.Atom(float_to_string(f), Easy_format.atom)
    | `String(s) => Easy_format.Atom(encode(s) |> quotes, Easy_format.atom)
    | `List([]) => Easy_format.Atom("[]", Easy_format.atom)
    | `Variant(s, _opt) => Easy_format.Atom(s, Easy_format.atom)
    | `Tuple(l)
    | `List(l) =>
      Easy_format.List(
        ("[", ",", "]", Easy_format.list),
        List.map(format, l),
      )
    | `Assoc([]) => Easy_format.Atom("{}", Easy_format.atom)
    | `Assoc(l) =>
      Easy_format.List(
        ("{", ",", "}", Easy_format.list),
        List.map(format_field, l),
      )
    }
  and format_field = ((name, _json)) => {
    let s = Printf.sprintf("%s:", encode(name) |> quotes);

    Easy_format.Label(
      (Easy_format.Atom(s, Easy_format.atom), Easy_format.label),
      Easy_format.Atom("...", Easy_format.atom),
    );
  };
};

module NoColor = {
  let rec format = (json: t) =>
    switch ((json: t)) {
    | `Null => Easy_format.Atom("null", Easy_format.atom)
    | `Bool(b) => Easy_format.Atom(Bool.to_string(b), Easy_format.atom)
    | `Int(i) => Easy_format.Atom(Int.to_string(i), Easy_format.atom)
    | `Intlit(s) => Easy_format.Atom(s, Easy_format.atom)
    | `Float(f) => Easy_format.Atom(float_to_string(f), Easy_format.atom)
    | `String(s) => Easy_format.Atom(quotes(encode(s)), Easy_format.atom)
    | `Variant(s, _opt) =>
      Easy_format.Atom(quotes(encode(s)), Easy_format.atom)
    | `List([]) => Easy_format.Atom("[]", Easy_format.atom)
    | `Tuple(l)
    | `List(l) =>
      Easy_format.List(
        ("[", ",", "]", Easy_format.list),
        List.map(format, l),
      )
    | `Assoc([]) => Easy_format.Atom("{}", Easy_format.atom)
    | `Assoc(l) =>
      Easy_format.List(
        ("{", ",", "}", Easy_format.list),
        List.map(format_field, l),
      )
    }
  and format_field = ((name, json)) => {
    let s = Printf.sprintf("%s:", encode(name) |> quotes);

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
