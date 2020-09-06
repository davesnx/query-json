open Source;
open Source.Compiler;

let stdinMock = {|
  {
    "store": {
      "books": [
        { "category": "reference",
          "author": "Nigel Rees",
          "title": "Sayings of the Century",
          "price": 8
        },
        { "category": "fiction",
          "author": "Evelyn Waugh",
          "title": "Sword of Honour",
          "price": 12
        },
        { "category": "fiction",
          "author": "Herman Melville",
          "title": "Moby Dick",
          "isbn": "0-553-21311-3",
          "price": 8
        },
        { "category": "fiction",
          "author": "J. R. R. Tolkien",
          "title": "The Lord of the Rings",
          "isbn": "0-395-19395-8",
          "price": 22
        }
      ]
    },
    "people": {
      "Team Mark": 23,
      "Team Valerie": 12,
      "Team Jor": 0,
      "No team": "No score"
    }
  }
|};

let main = () => {
  let json = Yojson.Basic.from_string(stdinMock);
  let inputMock = {|. | .store | .books|};
  let program = Main.parse(inputMock);
  let runtime: Json.t => Json.t = compile(program);
  Yojson.Basic.pretty_to_string(runtime(json));
};

main() |> print_endline;
