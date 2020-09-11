open Ast;

module Json = {
  type t = Yojson.Basic.t;
  include Yojson.Basic.Util;
};

type noun =
  | StartsWithVocal(string)
  | StartsWithConsonant(string);

let makeErrorWrongOperation = (op, memberKind, value: Json.t) => {
  "\nERROR: Trying to "
  ++ op
  ++ " on "
  ++ (
    switch (memberKind) {
    | StartsWithVocal(m) => "an " ++ m
    | StartsWithConsonant(m) => "a " ++ m
    }
  )
  ++ "."
  ++ "\n\nThe value recived is:\n"
  ++ Yojson.Basic.pretty_to_string(value);
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

/* TODO: Handle error */
let keys = json => Ok(`List(Json.keys(json) |> List.map(i => `String(i))));

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

let gt = compare(">", (l, r) => l > r);
let gte = compare(">=", (l, r) => l >= r);
let lt = compare("<", (l, r) => l < r);
let lte = compare("<=", (l, r) => l <= r);
let eq = compare("==", (l, r) => l == r);
let notEq = compare("!=", (l, r) => l != r);

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

let head = (json: Json.t) => {
  switch (json) {
  | `List(list) =>
    /* TODO: Making sure list have at least one item */
    Ok(Json.index(0, `List(list)))
  | _ => Error(makeError("head", json))
  };
};

let tail = (json: Json.t) => {
  switch (json) {
  | `List(list) =>
    /* TODO: Making sure list have at least one item */
    let lastIndex = List.length(list) - 1;
    Ok(Json.index(lastIndex, `List(list)));
  | _ => Error(makeError("tail", json))
  };
};

/* TODO: Run this on Assoc only */
let member = (key, json) => Ok(Json.member(key, json));

/* TODO: Run this on List only, String as well? */
let index = (key, json) => Ok(Json.index(key, json));

let rec compile = (expression: expression, json): result(Json.t, string) => {
  switch (expression) {
  | Identity => Ok(id(json))
  | Keys => keys(json)
  | Key(key) => member(key, json)
  | Index(idx) => index(idx, json)
  | Head => head(json)
  | Tail => tail(json)
  | Length => length(json)
  | Map(expr) => map(expr, json)
  | Addition(left, right) => pair(left, right, add, json)
  | Subtraction(left, right) => pair(left, right, sub, json)
  | Multiply(left, right) => pair(left, right, mult, json)
  | Division(left, right) => pair(left, right, div, json)
  | Literal(literal) =>
    switch (literal) {
    | Bool(b) => Ok(`Bool(b))
    | Number(float) => Ok(`Float(float))
    | String(string) => Ok(`String(string))
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
        }
      },
      json,
    )
  | _ => Error(show_expression(expression) ++ " is not implemented")
  };
}
and pair = (left, right, op, json) => {
  let l = compile(left, json);
  let r = compile(right, json);

  switch (l, r) {
  | (Ok(l), Ok(r)) => op(l, r)
  | (Error(err), _) => Error(err)
  | (_, Error(err)) => Error(err)
  };
}
and condition = (left, right, op, json) => {
  let l = compile(left, json);
  let r = compile(right, json);

  switch (l, r) {
  | (Ok(l), Ok(r)) =>
    switch (op(l, r)) {
    | Ok(b) => b
    /* If the condition fails, return false */
    | Error(_err) => false
    }
  | (Error(_err), _) => false
  | (_, Error(_err)) => false
  };
}
and map = (expr: expression, json: Json.t) => {
  switch (json) {
  | `List(_list) =>
    /* TODO: Making sure list have at least one item */
    /* TODO: compiler(expr, item) |> Result.get_ok can raise exn */
    Ok(Json.map(item => compile(expr, item) |> Result.get_ok, json))
  | _ => Error(makeError("map", json))
  };
};
