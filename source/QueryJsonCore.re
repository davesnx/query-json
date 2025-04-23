module Location = {
  type t = {
    loc_start: Lexing.position,
    loc_end: Lexing.position,
  };
  let none = {
    loc_start: Lexing.dummy_pos,
    loc_end: Lexing.dummy_pos,
  };
};

let last_position = ref(Location.none);

exception LexerError(string);

let provider =
    (~debug, buf): (Tokenizer.token, Lexing.position, Lexing.position) => {
  let (start, stop) = Sedlexing.lexing_positions(buf);
  let token =
    switch (Tokenizer.tokenize(buf)) {
    | Ok(t) => t
    | Error(e) => raise(LexerError(e))
    };

  last_position :=
    Location.{
      loc_start: start,
      loc_end: stop,
    };

  if (debug) {
    print_endline(Tokenizer.show_token(token));
  };

  (token, start, stop);
};

let menhir = MenhirLib.Convert.Simplified.traditional2revised(Parser.program);

let parse = (~debug=false, input): result(Ast.expression, string) => {
  let buf = Sedlexing.Utf8.from_string(input);
  let next_token = () => provider(~debug, buf);

  switch (menhir(next_token)) {
  | ast =>
    if (debug) {
      print_endline(Ast.show_expression(ast));
    };
    Ok(ast);
  | exception _exn =>
    let Location.{loc_start, loc_end, _} = last_position^;
    Error(Console.Errors.make(~input, ~start=loc_start, ~end_=loc_end));
  };
};

let run = (query, json) => {
  let result =
    parse(query)
    |> Result.map(Compiler.compile)
    |> Result.bind(_, runtime => {
         switch (Json.parseString(json)) {
         | Ok(input) => runtime(input)
         | Error(err) => Error(err)
         }
       });

  switch (result) {
  | Ok(res) =>
    Ok(
      res
      |> List.map(Json.toString(~colorize=false, ~summarize=false))
      |> String.concat("\n"),
    )
  | Error(e) => Error(e)
  };
};

let printError = Console.Errors.printError;
let usage = Console.usage;
