open Source;
open Source.Compiler;
open Source.Console;

let run = (query: option(string), json: string) => {
  let input = Source.Json.parseString(json);

  switch (query) {
  | Some(q) =>
    Main.parse(~debug=false, q)
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
    |> Result.map_error(e => print_endline(Errors.printError(e)))
  | None => Ok(Ok(print_endline(usage())))
  };
};

/* Js_of_ocaml.Js.export(
     "queryJson",
     [%js
       {
         as _;
         pub add = (x, y) => x +. y;
         pub abs = x => abs_float(x);
         val zero = 0.
       }
     ],
   );
    */
