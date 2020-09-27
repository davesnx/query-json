open Js_of_ocaml;
open Source;
open Source.Compiler;
open Source.Console;

let run = (query, json) => {
  let js_query = Js.to_string(query);
  let js_json = Js.to_string(json);
  let input = Source.Json.parseString(js_json);

  Main.parse(~debug=false, js_query)
  |> Result.map(compile)
  |> Result.map(runtime => {
       switch (input) {
       | Ok(inp) => runtime(inp)
       | Error(err) => Error(err)
       }
     })
  |> Result.map(res =>
       res
       |> Result.map(o =>
            Source.Json.toString(o, ~colorize=true, ~summarize=false)
            |> print_endline
          )
       |> Result.map_error(e => print_endline(Errors.printError(e)))
     )
  |> Result.map_error(e => print_endline(Errors.printError(e)));
};

Js_of_ocaml.Js.export("run", run);
