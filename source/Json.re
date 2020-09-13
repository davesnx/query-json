type t = Yojson.Basic.t;
include Yojson.Basic.Util;

let parseFile = Yojson.Basic.from_file;
let parseString = Yojson.Basic.from_file;

let (pp_print_string, pp_print_bool, pp_print_list, fprintf, asprintf) =
  Format.(pp_print_string, pp_print_bool, pp_print_list, fprintf, asprintf);

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

let list = (sep, ppx, out, l) => {
  let pp_sep = (out, ()) => fprintf(out, "%s@ ", sep);
  pp_print_list(~pp_sep, ppx, out, l);
};

let rec format =
        (~colorize: bool, ~summarize: bool, out: Format.formatter, json: t)
        : unit =>
  switch (json) {
  | `Int(n) =>
    if (colorize) {
      fprintf(out, "\x1b[32m%d\x1b[39m", n);
    } else {
      fprintf(out, "%d", n);
    }
  | `Float(n) =>
    if (colorize) {
      fprintf(out, "\x1b[32m%f\x1b[39m", n);
    } else {
      fprintf(out, "%f", n);
    }
  | `String(s) =>
    if (colorize) {
      fprintf(out, "\x1b[32m\"%s\"\x1b[39m", string(s));
    } else {
      fprintf(out, "\"%s\"", string(s));
    }
  | `Null => pp_print_string(out, "null")
  | `Bool(b) => pp_print_bool(out, b)
  | `List([]) => pp_print_string(out, "[]")
  | `List(l) =>
    fprintf(
      out,
      "[@;<1 0>@[<hov>%a@]@;<1 -2>]",
      list(",", format(~colorize, ~summarize)),
      l,
    )
  | `Assoc([]) => pp_print_string(out, "{}")
  | `Assoc(l) =>
    fprintf(
      out,
      "{@;<1 0>%a@;<1 -2>}",
      list(",", field(~colorize, ~summarize)),
      l,
    )
  }
and field = (~colorize, ~summarize, out, (name, x)) =>
  fprintf(
    out,
    colorize ? "@[<hv2>\x1b[34m%s\x1b[39m: %a@]" : "@[<hv2>\"%s\": %a@]",
    string(name),
    format(~colorize, ~summarize),
    x,
  );

let pretty = (~colorize, ~summarize, out, json) =>
  fprintf(out, "@[<hv2>%a@]", format(~colorize, ~summarize), (json :> t));
let toString = (json, ~colorize=true, ~summarize) =>
  asprintf("%a", pretty(~colorize, ~summarize), json);
