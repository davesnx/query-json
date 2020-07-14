let initial_env = Env.initial_env;

// let example =
//   Apply(
//     Identifier("log"),
//     Apply(
//       Apply(Identifier("+"), Literal(Float(5.2))),
//       Literal(Float(2.3)),
//     ),
//   );

// switch (Eval.eval(initial_env, example)) {
// | Ok(_) => ()
// | Error(error) => failwith(error)
// };

// read_all({|<log>"abc"</log>|});

open Parser;

let ast = parse({|
  <log><sum>2 4</sum></log>
|}) |> Option.get;

Eval.eval(Env.initial_env, ast);
