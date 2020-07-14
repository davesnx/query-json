open Sedlexing;
open Utf8;
open Token;

let alpha = [%sedlex.regexp? 'a'..'z'];
let digit = [%sedlex.regexp? '0'..'9'];
let number = [%sedlex.regexp?
  (Opt('+' | '-'), Plus(digit), Opt('.', Plus(digit)))
];
let identifier = [%sedlex.regexp? (alpha, Star(alpha | digit))];
let named_parameter = [%sedlex.regexp? (Plus(alpha), '=')];

let whitespace = [%sedlex.regexp? Plus('\n' | '\t' | ' ')];

let tokenize = buf =>
  switch%sedlex (buf) {
  | eof => Ok(EOF)
  | whitespace => Ok(WHITESPACE)
  | number =>
    let number = lexeme(buf) |> float_of_string;
    Ok(NUMBER(number));
  | '"' =>
    let rec read_until_quote = acc =>
      switch%sedlex (buf) {
      | "\\\"" => read_until_quote(acc ++ lexeme(buf))
      | '"' => acc
      | any => read_until_quote(acc ++ lexeme(buf))
      | _ => failwith("unrecheable")
      };
    let content = read_until_quote("");
    Ok(STRING(content));
  | identifier => Ok(IDENTIFIER(lexeme(buf)))
  | named_parameter =>
    let string = lexeme(buf);
    let name = String.sub(string, 0, String.length(string) - 1);
    Ok(ATTRIBUTE(name));
  | "</" => Ok(CLOSE_TAG)
  | '<' => Ok(OPEN_TAG)
  | '>' => Ok(GREATER_THAN)
  | _ => Error("unknown character somewhere")
  };
