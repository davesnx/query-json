open QueryJsonCore;

let run = (query, json) => {
  let result =
    Main.parse(~debug=false, query)
    |> Result.map(Compiler.compile)
    |> Result.map(runtime => {
         switch (Json.parseString(json)) {
         | Ok(input) => runtime(input)
         | Error(err) => Error(err)
         }
       });

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
  };
};
