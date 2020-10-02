open Ast;
open Console;

type noun =
  | StartsWithVocal(string)
  | StartsWithConsonant(string);

let makeErrorWrongOperation = (op, memberKind, value: Json.t) => {
  "Trying to "
  ++ Formatting.singleQuotes(Chalk.bold(op))
  ++ " on "
  ++ (
    switch (memberKind) {
    | StartsWithVocal(m) => "an " ++ Chalk.bold(m)
    | StartsWithConsonant(m) => "a " ++ Chalk.bold(m)
    }
  )
  ++ ":"
  ++ Formatting.enter(1)
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

let empty = Ok([]);

module Results {
  let return = x => Ok([x]);

  let lift2 =
      (f: ('a, 'b) => 'c, mx: result('a, string), my: result('b, string))
      : result('c, string) => {
    switch (mx) {
    | Ok(x) =>
      switch (my) {
      | Ok(y) => Ok(f(x, y))
      | Error(err) => Error(err)
      }
    | Error(err) => Error(err)
    };
  };

  let collect =
      (xs: list(result(list('a), string))): result(list('a), string) =>
    List.fold_right(lift2((@)), xs, empty);

  let bind =
      (mx: result(list('a), string), f: 'a => result(list('b), string))
      : result(list('b), string) => {
    switch (mx) {
    | Ok(xs) => collect(List.map(f, xs))
    | Error(err) => Error(err)
    };
  };
}


let keys = (json: Json.t) => {
  switch (json) {
  | `Assoc(_list) =>
    Results.return(`List(Json.keys(json) |> List.map(i => `String(i))))
  | _ => Error(makeError("keys", json))
  };
};

let length = (json: Json.t) => {
  switch (json) {
  | `List(list) => Results.return(`Int(list |> List.length))
  | _ => Error(makeError("length", json))
  };
};

let not_ = (json: Json.t) => {
  switch (json) {
  | `Bool(false)
  | `Null => Results.return(`Bool(true))
  | _ => Results.return(`Bool(false))
  };
};

let apply =
    (str: string, fn: (float, float) => float, left: Json.t, right: Json.t) => {
  switch (left, right) {
  | (`Float(l), `Float(r)) => Results.return(`Float(fn(l, r)))
  | (`Int(l), `Float(r)) => Results.return(`Float(fn(float_of_int(l), r)))
  | (`Float(l), `Int(r)) => Results.return(`Float(fn(l, float_of_int(r))))
  | (`Int(l), `Int(r)) =>
    Results.return(`Float(fn(float_of_int(l), float_of_int(r))))
  | _ => Error(makeError(str, left))
  };
};

let compare =
    (str: string, fn: (float, float) => bool, left: Json.t, right: Json.t) => {
  switch (left, right) {
  | (`Float(l), `Float(r)) => Results.return(`Bool(fn(l, r)))
  | (`Int(l), `Float(r)) => Results.return(`Bool(fn(float_of_int(l), r)))
  | (`Float(l), `Int(r)) => Results.return(`Bool(fn(l, float_of_int(r))))
  | (`Int(l), `Int(r)) =>
    Results.return(`Bool(fn(float_of_int(l), float_of_int(r))))
  | _ => Error(makeError(str, right))
  };
};

let condition =
    (str: string, fn: (bool, bool) => bool, left: Json.t, right: Json.t) => {
  switch (left, right) {
  | (`Bool(l), `Bool(r)) => Results.return(`Bool(fn(l, r)))
  | _ => Error(makeError(str, right))
  };
};

let gt = compare(">", (>));
let gte = compare(">=", (>=));
let lt = compare("<", (<));
let lte = compare("<=", (<=));
let and_ = condition("and", (&&));
let or_ = condition("or", (||));

/* Does OCaml equality on Json.t implies JSON equality? */
let eq = (l, r) => Results.return(`Bool(l == r));
let notEq = (l, r) => Results.return(`Bool(l != r));

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

let makeEmptyListError = op => {
  "Trying to "
  ++ Formatting.singleQuotes(Chalk.bold(op))
  ++ " on an empty array.";
};

let head = (json: Json.t) => {
  switch (json) {
  | `List(list) =>
    List.length(list) > 0
      ? Results.return(Json.index(0, `List(list)))
      : Error(makeEmptyListError("head"))

  | _ => Error(makeError("head", json))
  };
};

let tail = (json: Json.t) => {
  switch (json) {
  | `List(list) =>
    List.length(list) > 0
      ? {
        let lastIndex = List.length(list) - 1;
        Results.return(Json.index(lastIndex, `List(list)));
      }
      : Error(makeEmptyListError("head"))
  | _ => Error(makeError("tail", json))
  };
};

let makeErrorMissingMember = (op, key, value: Json.t) => {
  "Trying to "
  ++ Formatting.doubleQuotes(Chalk.bold(op))
  ++ " on an object, that don't have the field "
  ++ Formatting.doubleQuotes(key)
  ++ ":"
  ++ Formatting.enter(1)
  ++ Chalk.gray(Json.toString(value, ~colorize=false, ~summarize=true));
};

let member = (key: string, opt: bool, json: Json.t) => {
  switch (json) {
  | `Assoc(_assoc) =>
    let accessMember = Json.member(key, json);
    switch (accessMember, opt) {
    | (`Null, true) => Results.return(accessMember)
    | (`Null, false) => Error(makeErrorMissingMember("." ++ key, key, json))
    | (_, false) => Results.return(accessMember)
    | (_, true) => Results.return(accessMember)
    };
  | _ => Error(makeError("." ++ key, json))
  };
};

let index = (value: int, json: Json.t) => {
  switch (json) {
  | `List(_list) => Results.return(Json.index(value, json))
  | _ => Error(makeError("[" ++ string_of_int(value) ++ "]", json))
  };
};

let rec compile =
        (expression: expression, json): result(list(Json.t), string) => {
  switch (expression) {
  | Identity => Results.return(json)
  | Empty => empty
  | Keys => keys(json)
  | Key(key, opt) => member(key, opt, json)
  | Index(idx) => index(idx, json)
  | Head => head(json)
  | Tail => tail(json)
  | Length => length(json)
  | Not => not_(json)
  | Map(expr) => map(expr, json)
  | Addition(left, right) => operation(left, right, add, json)
  | Subtraction(left, right) => operation(left, right, sub, json)
  | Multiply(left, right) => operation(left, right, mult, json)
  | Division(left, right) => operation(left, right, div, json)
  | Literal(literal) =>
    switch (literal) {
    | Bool(b) => Results.return(`Bool(b))
    | Number(float) => Results.return(`Float(float))
    | String(string) => Results.return(`String(string))
    | Null => Results.return(`Null)
    }
  | Pipe(left, right) => Results.bind(compile(left, json), compile(right))
  | Select(conditional) =>
    Results.bind(compile(conditional, json), res =>
      switch (res) {
      | `Bool(b) => b ? Results.return(json) : empty
      | _ => Error(makeError("select", res))
      }
    )
  | Greater(left, right) => operation(left, right, gt, json)
  | GreaterEqual(left, right) => operation(left, right, gte, json)
  | Lower(left, right) => operation(left, right, lt, json)
  | LowerEqual(left, right) => operation(left, right, lte, json)
  | Equal(left, right) => operation(left, right, eq, json)
  | NotEqual(left, right) => operation(left, right, notEq, json)
  | And(left, right) => operation(left, right, and_, json)
  | Or(left, right) => operation(left, right, or_, json)
  | List(expr) => Result.bind(compile(expr, json), xs => Results.return(`List(xs)))
  | Comma(leftR, rightR) =>
    Result.bind(compile(leftR, json), left =>
      Result.bind(compile(rightR, json), right => Ok(left @ right))
    )
  | _ => Error(show_expression(expression) ++ " is not implemented")
  };
}
and operation = (leftR, rightR, op, json) => {
  Results.bind(compile(leftR, json), left =>
    Results.bind(compile(rightR, json), right => op(left, right))
  );
}
and map = (expr: expression, json: Json.t) => {
  switch (json) {
  | `List(list) =>
    List.length(list) > 0
      ? {
        Results.collect(List.map(item => compile(expr, item), list)) |> Result.map(x => [`List(x)])
      }
      : Error(makeEmptyListError("map"))
  | _ => Error(makeError("map", json))
  };
};
