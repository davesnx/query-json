open Ast;

module Json = {
  type t = Yojson.Basic.t;
  include Yojson.Basic.Util;
};

exception WrongOperation(string);

type noun =
  | StartsWithVocal(string)
  | StartsWithConsonant(string);

let wrongTypeOperation = (op, memberKind, value: Json.t) => {
  raise(
    WrongOperation(
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
      ++ Json.to_string(value),
    ),
  );
};

let raiseOperationInWrongType = (name, json) => {
  switch (json) {
  | `List(_list) =>
    wrongTypeOperation(name, StartsWithConsonant("list"), json)
  | `Assoc(_a) => wrongTypeOperation(name, StartsWithVocal("object"), json)
  | `Bool(_b) => wrongTypeOperation(name, StartsWithConsonant("bool"), json)
  | `Float(_f) =>
    wrongTypeOperation(name, StartsWithConsonant("float"), json)
  | `Int(_i) => wrongTypeOperation(name, StartsWithVocal("int"), json)
  | `Null => wrongTypeOperation(name, StartsWithConsonant("null"), json)
  | `String(_identifier) =>
    wrongTypeOperation(name, StartsWithConsonant("string"), json)
  };
};
let keys = json => `List(Json.keys(json) |> List.map(i => `String(i)));
let length = json => `Int(json |> Json.to_list |> List.length);
let apply =
    (str: string, fn: (float, float) => float, left: Json.t, right: Json.t) => {
  switch (left, right) {
  | (`Float(l), `Float(r)) => `Float(fn(l, r))
  | (`Int(l), `Float(r)) => `Float(fn(float_of_int(l), r))
  | (`Float(l), `Int(r)) => `Float(fn(l, float_of_int(r)))
  | (`Int(l), `Int(r)) => `Float(fn(float_of_int(l), float_of_int(r)))
  | _ => raiseOperationInWrongType(str, left)
  };
};

let compare =
    (str: string, fn: (float, float) => bool, left: Json.t, right: Json.t) => {
  switch (left, right) {
  | (`Float(l), `Float(r)) => fn(l, r)
  | (`Int(l), `Float(r)) => fn(float_of_int(l), r)
  | (`Float(l), `Int(r)) => fn(l, float_of_int(r))
  | (`Int(l), `Int(r)) => fn(float_of_int(l), float_of_int(r))
  | _ => raiseOperationInWrongType(str, right)
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
  | `List(list) => `List(List.filter(fn, list))
  | _ => raiseOperationInWrongType("filter", json)
  };
};

let id: Json.t => Json.t = i => i;

exception WrongIndexAccess(string);

let head = (json: Json.t) => {
  switch (json) {
  | `List(list) =>
    /* TODO: Making sure list have a at least one item
       let item =
          try(List.nth(list, 0)) {
          | _ => raise(WrongIndexAccess("def"))
          }; */

    Json.index(0, `List(list))
  | _ => raiseOperationInWrongType("head", json)
  };
};

let tail = (json: Json.t) => {
  switch (json) {
  | `List(list) =>
    /* TODO: Making sure list have at least one item
       let item =
          try(List.nth(list, 0)) {
          | _ => raise(WrongIndexAccess("def"))
          }; */
    let lastIndex = List.length(list) - 1;
    Json.index(lastIndex, `List(list));
  | _ => raiseOperationInWrongType("head", json)
  };
};

exception CompilationError(string);

let rec compile = (expression: expression, json: Json.t) => {
  switch (expression) {
  | Identity => id(json)
  | Keys => keys(json)
  | Key(key) => Json.member(key, json)
  | Index(idx) => Json.index(idx, json)
  | Head => head(json)
  | Tail => tail(json)
  | Length => length(json)
  | Map(expr) => Json.map(compile(expr), json)
  | Addition(left, right) => add(compile(left, json), compile(right, json))
  | Subtraction(left, right) =>
    sub(compile(left, json), compile(right, json))
  | Multiply(left, right) =>
    mult(compile(left, json), compile(right, json))
  | Division(left, right) => div(compile(left, json), compile(right, json))
  | Literal(literal) =>
    switch (literal) {
    | Bool(b) => `Bool(b)
    | Number(float) => `Float(float)
    | String(string) => `String(string)
    }
  | Filter(conditional) =>
    filter(
      item => {
        switch (conditional) {
        | Greater(left, right) =>
          gt(compile(left, item), compile(right, item))
        | GreaterEqual(left, right) =>
          gte(compile(left, item), compile(right, item))
        | Lower(left, right) =>
          lt(compile(left, item), compile(right, item))
        | LowerEqual(left, right) =>
          lte(compile(left, item), compile(right, item))
        | Equal(left, right) =>
          eq(compile(left, item), compile(right, item))
        | NotEqual(left, right) =>
          notEq(compile(left, item), compile(right, item))
        }
      },
      json,
    )
  | Pipe(left, right) => compile(right, compile(left, json))
  | _ =>
    raise(
      CompilationError(show_expression(expression) ++ " is not implemented"),
    )
  };
};
