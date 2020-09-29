open Js_of_ocaml;
open Source;

let renderError = e => Console.Errors.printError(e);

type out = result(string, string);

let to_bs_result = (res: out) => {
  switch (res) {
  | Ok(str) =>
    Js.Unsafe.obj([|
      ("_0", Js.Unsafe.inject(Js.string(str))),
      ("TAG", Js.Unsafe.inject(0)),
    |])
  | Error(str) =>
    Js.Unsafe.obj([|
      ("_0", Js.Unsafe.inject(Js.string(str))),
      ("TAG", Js.Unsafe.inject(1)),
    |])
  };
};

let run = (query, json) => {
  let js_query = Js.to_string(query);
  let js_json = Js.to_string(json);
  let input = Json.parseString(js_json);

  let result =
    Main.parse(~debug=true, js_query)
    |> Result.map(Compiler.compile)
    |> Result.map(runtime => {
         switch (input) {
         | Ok(inp) => runtime(inp)
         | Error(err) => Error(err)
         }
       });

  (
    switch (result) {
    | Ok(res) =>
      switch (res) {
      | Ok(r) => Ok(Json.toString(~colorize=false, ~summarize=false, r))
      | Error(e) => Error(e)
      }
    | Error(err) => Error(err)
    }
  )
  |> to_bs_result;
};

Js.export("run", run);
