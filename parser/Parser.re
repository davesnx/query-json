module Ast = Ast;
let expression_value =
  MenhirLib.Convert.Simplified.traditional2revised(
    Xml_parser.expression_value,
  );

let provider = (buf, ()) => {
  let token = Tokenizer.tokenize(buf) |> Result.get_ok;
  let (start, stop) = Sedlexing.lexing_positions(buf);
  (token, start, stop);
};

let parse = code => {
  let buf = Sedlexing.Utf8.from_string(code);
  expression_value(provider(buf));
};
