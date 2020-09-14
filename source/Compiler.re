open Ast;
open Console;

type noun =
  | StartsWithVocal(string)
  | StartsWithConsonant(string);

let makeErrorWrongOperation = (op, memberKind, value: Json.t) => {
  enter(1)
  ++ "Error:  Trying to "
  ++ Chalk.bold(op)
  ++ " on "
  ++ (
    switch (memberKind) {
    | StartsWithVocal(m) => "an " ++ Chalk.bold(m)
    | StartsWithConsonant(m) => "a " ++ Chalk.bold(m)
    }
  )
  ++ "."
  ++ enter(2)
  ++ "Recived value:"
  ++ enter(1)
  ++ indent(4)
  ++ Chalk.gray(Json.toString(value, ~colorize=false, ~summarize=true));
};

let makeError = (name: string, json: Json.t) => {
  switch (json) {
  | `List(_list) =>
    makeErrorWrongOperation(name, StartsWithConsonant("list"), json)
  | `Assoc(_assoc) =>
    makeErrorWrongOperation(name, StartsWithVocal("object"), json)
  | `Bool(_b) =>
    makeErrorWrongOperation(name, StartsWithConsonant("bool"), json)
  | `Float(_f) =>
    makeErrorWrongOperation(name, StartsWithConsonant("float"), json)
  | `Int(_i) => makeErrorWrongOperation(name, StartsWithVocal("int"), json)
  | `Null => makeErrorWrongOperation(name, StartsWithConsonant("null"), json)
  | `String(_identifier) =>
    makeErrorWrongOperation(name, StartsWithConsonant("string"), json)
  };
};

let keys = (json: Json.t) => {
  switch (json) {
  | `Assoc(_list) =>
    Ok(`List(Json.keys(json) |> List.map(i => `String(i))))
  | _ => Error(makeError("keys", json))
  };
};

let length = (json: Json.t) => {
  switch (json) {
  | `List(list) => Ok(`Int(list |> List.length))
  | _ => Error(makeError("length", json))
  };
};

let apply =
    (str: string, fn: (float, float) => float, left: Json.t, right: Json.t) => {
  switch (left, right) {
  | (`Float(l), `Float(r)) => Ok(`Float(fn(l, r)))
  | (`Int(l), `Float(r)) => Ok(`Float(fn(float_of_int(l), r)))
  | (`Float(l), `Int(r)) => Ok(`Float(fn(l, float_of_int(r))))
  | (`Int(l), `Int(r)) =>
    Ok(`Float(fn(float_of_int(l), float_of_int(r))))
  | _ => Error(makeError(str, left))
  };
};

let compare =
    (str: string, fn: (float, float) => bool, left: Json.t, right: Json.t) => {
  switch (left, right) {
  | (`Float(l), `Float(r)) => Ok(fn(l, r))
  | (`Int(l), `Float(r)) => Ok(fn(float_of_int(l), r))
  | (`Float(l), `Int(r)) => Ok(fn(l, float_of_int(r)))
  | (`Int(l), `Int(r)) => Ok(fn(float_of_int(l), float_of_int(r)))
  | _ => Error(makeError(str, right))
  };
};

let condition =
    (str: string, fn: (bool, bool) => bool, left: Json.t, right: Json.t) => {
  switch (left, right) {
  | (`Bool(l), `Bool(r)) => Ok(fn(l, r))
  | _ => Error(makeError(str, right))
  };
};

let gt = compare(">", (l, r) => l > r);
let gte = compare(">=", (l, r) => l >= r);
let lt = compare("<", (l, r) => l < r);
let lte = compare("<=", (l, r) => l <= r);
let and_ = condition("and", (l, r) => l && r);
let or_ = condition("or", (l, r) => l || r);
let not_ = condition("not", (l, _) => !l);

let eq = condition("==", (l, r) => l == r);
let notEq = condition("!=", (l, r) => l != r);

let add = apply("+", (l, r) => l +. r);
let sub = apply("-", (l, r) => l -. r);
let mult = apply("-", (l, r) => l *. r);
let div = apply("-", (l, r) => l /. r);

let filter = (fn: Json.t => bool, json: Json.t) => {
  switch (json) {
  | `List(list) => Ok(`List(List.filter(fn, list)))
  | _ => Error(makeError("filter", json))
  };
};

let id: Json.t => Json.t = i => i;

let makeEmptyListError = op => {
  enter(1) ++ "Error:  Trying to " ++ Chalk.bold(op) ++ " on an empty array.";
};

let head = (json: Json.t) => {
  switch (json) {
  | `List(list) =>
    List.length(list) > 0
      ? Ok(Json.index(0, `List(list))) : Error(makeEmptyListError("head"))

  | _ => Error(makeError("head", json))
  };
};

let tail = (json: Json.t) => {
  switch (json) {
  | `List(list) =>
    List.length(list) > 0
      ? {
        let lastIndex = List.length(list) - 1;
        Ok(Json.index(lastIndex, `List(list)));
      }
      : Error(makeEmptyListError("head"))
  | _ => Error(makeError("tail", json))
  };
};

let makeErrorMissingMember = (op, value: Json.t) => {
  enter(1)
  ++ "Error:  Trying to "
  ++ Chalk.bold(op)
  ++ " on "
  ++ Chalk.gray(Json.toString(value, ~colorize=false, ~summarize=true))
  ++ " and it doesn't exist.";
};

let member = (key: string, opt: bool, json: Json.t) => {
  switch (json) {
  | `Assoc(_assoc) =>
    let accessMember = Json.member(key, json);
    switch (accessMember, opt) {
    | (`Null, true) => Ok(accessMember)
    | (`Null, false) => Error(makeErrorMissingMember("." ++ key, json))
    | (_, false) => Ok(accessMember)
    | (_, true) => Ok(accessMember)
    };
  | _ => Error(makeError("." ++ key, json))
  };
};

let index = (value: int, json: Json.t) => {
  switch (json) {
  | `List(_list) => Ok(Json.index(value, json))
  | _ => Error(makeError("[" ++ string_of_int(value) ++ "]", json))
  };
};

let rec compile = (expression: expression, json): result(Json.t, string) => {
  switch (expression) {
  | Identity => Ok(id(json))
  | Keys => keys(json)
  | Key(key, opt) => member(key, opt, json)
  | Index(idx) => index(idx, json)
  | Head => head(json)
  | Tail => tail(json)
  | Length => length(json)
  | Map(expr) => map(expr, json)
  | Addition(left, right) => operation(left, right, add, json)
  | Subtraction(left, right) => operation(left, right, sub, json)
  | Multiply(left, right) => operation(left, right, mult, json)
  | Division(left, right) => operation(left, right, div, json)
  | Literal(literal) =>
    switch (literal) {
    | Bool(b) => Ok(`Bool(b))
    | Number(float) => Ok(`Float(float))
    | String(string) => Ok(`String(string))
    | Null => Ok(`Null)
    }
  | Pipe(left, right) =>
    let cLeft = compile(left, json);
    switch (cLeft) {
    | Ok(l) => compile(right, l)
    | Error(err) => Error(err)
    };
  | Filter(conditional) =>
    filter(
      item => {
        switch (conditional) {
        | Greater(left, right) => condition(left, right, gt, item)
        | GreaterEqual(left, right) => condition(left, right, gte, item)
        | Lower(left, right) => condition(left, right, lt, item)
        | LowerEqual(left, right) => condition(left, right, lte, item)
        | Equal(left, right) => condition(left, right, eq, item)
        | NotEqual(left, right) => condition(left, right, notEq, item)
        | And(left, right) => condition(left, right, and_, item)
        | Or(left, right) => condition(left, right, or_, item)
        | Not(left, right) => condition(left, right, not_, item)
        }
      },
      json,
    )
  | _ => Error(show_expression(expression) ++ " is not implemented")
  };
}
and operation = (leftR, rightR, op, json) => {
  let exprLeft = compile(leftR, json);
  let exprRight = compile(rightR, json);

  switch (exprLeft, exprRight) {
  | (Ok(left), Ok(right)) => op(left, right)
  | (Error(err), _) => Error(err)
  | (_, Error(err)) => Error(err)
  };
}
and condition = (leftR, rightR, op, json) => {
  let exprLeft = compile(leftR, json);
  let exprRight = compile(rightR, json);

  switch (exprLeft, exprRight) {
  | (Ok(left), Ok(right)) =>
    switch (op(left, right)) {
    | Ok(boolean) => boolean
    /* If the condition fails, return false */
    | Error(_err) => false
    }
  | (Error(_err), _) => false
  | (_, Error(_err)) => false
  };
}
and map = (expr: expression, json: Json.t) => {
  switch (json) {
  | `List(list) =>
    /* TODO: compiler(expr, item) |> Result.get_ok can raise exn */
    List.length(list) > 0
      ? {
        Ok(Json.map(item => compile(expr, item) |> Result.get_ok, json));
      }
      : Error(makeEmptyListError("map"))
  | _ => Error(makeError("map", json))
  };
};
