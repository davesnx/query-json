open Js_of_ocaml;
open Source;

let to_bs_result = (res: result(string, string)) => {
  switch (res) {
  | Ok(str) =>
    Js.Unsafe.obj([|
      ("TAG", Js.Unsafe.inject(0)),
      ("_0", Js.Unsafe.inject(Js.string(str))),
    |])
  | Error(str) =>
    Js.Unsafe.obj([|
      ("TAG", Js.Unsafe.inject(1)),
      ("_0", Js.Unsafe.inject(Js.string(str))),
    |])
  };
};

let run = (rawQuery, rawJson) => {
  let query = Js.to_string(rawQuery);
  let json = Js.to_string(rawJson);

  let result =
    Main.parse(~debug=false, query)
    |> Result.map(Compiler.compile)
    |> Result.map(runtime => {
         switch (Json.parseString(json)) {
         | Ok(input) => runtime(input)
         | Error(err) => Error(err)
         }
       });

  (
    switch (result) {
    | Ok(res) =>
      switch (res) {
      | Ok(r) =>
        Ok(
          r
          |> List.map(Json.toString(~colorize=false, ~summarize=false))
          |> String.concat("\n"),
        )
      | Error(e) => Error(e)
      }
    | Error(err) => Error(err)
    }
  )
  |> to_bs_result;
};

Js.export("run", run);
