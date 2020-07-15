open Parser;

let ast = parse({|
  <log><sum>2 4</sum></log>
|}) |> Option.get;

Eval.eval(Env.initial_env, ast);
