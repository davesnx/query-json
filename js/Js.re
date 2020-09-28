open Js_of_ocaml;
open Source;

let renderError = e => print_endline(Console.Errors.printError(e));

let run = (query, json) => {
  let _js_query = Js.to_string(query);
  let js_json = Js.to_string(json);
  let input = Json.parseString(js_json);
  switch (input) {
  | Ok(inp) => print_endline(inp |> Json.pretty_to_string)
  | Error(_err) => ()
  };
  /* Main.parse(~debug=false, js_query)
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
               Json.toString(o, ~colorize=true, ~summarize=false)
               |> print_endline
             )
          |> Result.map_error(renderError)
        )
     |> Result.map_error(renderError); */
};

Js_of_ocaml.Js.export("run", run);
