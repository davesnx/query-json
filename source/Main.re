open Ast;
open Tokenizer;
open Console.Errors;

let menhir = MenhirLib.Convert.Simplified.traditional2revised(Parser.program);

let last_position = ref(Location.none);

exception LexerError(string);

let provider =
    (~debug, buf): (token, Stdlib__lexing.position, Stdlib__lexing.position) => {
  let (start, stop) = Sedlexing.lexing_positions(buf);
  let token =
    switch (tokenize(buf)) {
    | Ok(t) => t
    | Error(e) => raise(LexerError(e))
    };

  last_position :=
    Location.{loc_start: start, loc_end: stop, loc_ghost: false};

  if (debug) {
    print_endline(token |> show_token);
  };

  (token, start, stop);
};

let parse = (input: string, ~debug: bool): result(expression, string) => {
  let buf = Sedlexing.Utf8.from_string(input);
  let lexer = () => provider(~debug, buf);

  try(Ok(menhir(lexer))) {
  | exn =>
    let Location.{loc_start, loc_end, _} = last_position^;
    Error(make(~input, ~start=loc_start, ~end_=loc_end, exn));
  };
};
