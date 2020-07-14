open Parser;
open Ast;

module Env = Map.Make(String);

[@deriving show]
type value =
  | Void
  | String(string)
  | Float(float)
  | Boolean(bool)
  | Function(identifier, expression) // TODO: parameters in defined functions
  | Native((list((identifier, value)), value) => result(value, string));

let (let.ok) = Result.bind;

let rec eval = (env: Env.t(value), expr) =>
  switch (expr) {
  | Ast.Void => Ok(Void)
  | Literal(String(string)) => Ok(String(string))
  | Literal(Float(float)) => Ok(Float(float))
  | Identifier(identifier) =>
    Env.find_opt(identifier, env)
    |> Option.to_result(~none="identifier not found")
  | Apply(fn, named_arguments, argument) =>
    let.ok fn_value = eval(env, fn);
    let.ok named_arguments =
      List.fold_left(
        (args, (name, arg)) => {
          let.ok args = args;
          let.ok arg = eval(env, arg);
          Ok([(name, arg), ...args]);
        },
        Ok([]),
        named_arguments,
      );
    let.ok argument = eval(env, argument);
    switch (fn_value) {
    | Native(fn) => fn(named_arguments, argument)
    | Function(parameter, body) =>
      let env = Env.add(parameter, argument, env);
      eval(env, body);
    | value => Error(show_value(value) ++ " is not a function")
    };
  | Function(parameters, body) => Ok(Function(parameters, body))
  | Binding((identifier, value), return_value) =>
    // TODO: recursive values
    let.ok value = eval(env, value);
    let env = Env.add(identifier, value, env);
    eval(env, return_value);
  };
