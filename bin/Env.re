open Eval;

include Env;

let sum = _ =>
  fun
  | Float(a) =>
    Native(
      _ =>
        (
          fun
          | Float(b) => Ok(Float(a +. b))
          | _ => failwith("something is not something")
        ),
    )
    |> Result.ok
  | _ => Error("something is not something");

let log = (_, value) => {
  Console.log(Eval.show_value(value));
  Ok(Void);
};
let initial_env = [
  ("yes", Boolean(true)),
  ("no", Boolean(false)),
  ("sum", Native(sum)),
  ("log", Native(log)),
];
let initial_env = initial_env |> List.to_seq |> Env.of_seq;
