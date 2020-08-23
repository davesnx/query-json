open Yojson.Basic.Util;

exception WrongOperation(string);

module ErrorWrapper = {
  type t = {
    message: string,
    error: exn,
  };

  let stack = [];
};

let safe = (msg, f) =>
  try(f()) {
  | error =>
    let wrappedError: ErrorWrapper.t = {message: msg, error};
    List.append(ErrorWrapper.stack, [wrappedError]);
  };

let tryingToOperateInAWrongType = (op, memberKind, value: option(string)) => {
  switch (value) {
  | Some(v) =>
    raise(
      WrongOperation(
        "Trying to "
        ++ op
        ++ " on a '"
        ++ v
        ++ "' which is '"
        ++ memberKind
        ++ "'",
      ),
    )
  | None =>
    raise(WrongOperation("Trying to " ++ op ++ "on a " ++ memberKind))
  };
};

let operationInWrongType = (name, json) => {
  switch (json) {
  | `List(_list) => tryingToOperateInAWrongType(name, "list", None)
  | `Assoc(_a) => tryingToOperateInAWrongType(name, "object", Some("obj"))
  | `Bool(b) =>
    tryingToOperateInAWrongType(name, "bool", Some(string_of_bool(b)))
  | `Float(f) =>
    tryingToOperateInAWrongType(name, "float", Some(string_of_float(f)))
  | `Int(i) =>
    tryingToOperateInAWrongType(name, "int", Some(string_of_int(i)))
  | `Null => tryingToOperateInAWrongType(name, "null", None)
  | `String(identifier) =>
    tryingToOperateInAWrongType(name, "string", Some(identifier))
  };
};

let sum = (amount: int, json): Yojson.Basic.t => {
  switch (json) {
  | `Float(float) => `Float(float_of_int(amount) +. float)
  | `Int(int) => `Float(float_of_int(amount + int))
  | _ => operationInWrongType("+", json)
  };
};

/* .store.books | map(.price + 10) */
/* let transformedProgram = json => {
     json
     |> member("store")
     |> member("books")
     |> map(item => sum(10, member("price", item)));
   }; */

let keys = json => `List(keys(json) |> List.map(i => `String(i)));

/* .store.books[0].keys */
/* let transformedProgram = json => {
     json |> member("store") |> member("books") |> index(0) |> keys;
   };
    */

let length = json => `Int(json |> to_list |> List.length);

/* .store.books.length */
/* let transformedProgram = json => {
     json |> member("store") |> member("books") |> length;
   };
    */

let gt = (json: Yojson.Basic.t, value: float): bool => {
  switch (json) {
  | `Float(float) => float > value
  | `Int(int) => int > int_of_float(value)
  | _ => operationInWrongType(">", json)
  };
};

let gte = (json: Yojson.Basic.t, value: float): bool => {
  switch (json) {
  | `Float(float) => float >= value
  | `Int(int) => int >= int_of_float(value)
  | _ => operationInWrongType(">=", json)
  };
};

let lt = (json: Yojson.Basic.t, value: float): bool => {
  switch (json) {
  | `Float(float) => float < value
  | `Int(int) => int < int_of_float(value)
  | _ => operationInWrongType("<", json)
  };
};

let lte = (json: Yojson.Basic.t, value: float): bool => {
  switch (json) {
  | `Float(float) => float <= value
  | `Int(int) => int <= int_of_float(value)
  | _ => operationInWrongType("<=", json)
  };
};

let filter = (fn: Yojson.Basic.t => bool, json: Yojson.Basic.t) => {
  switch (json) {
  | `List(list) => `List(List.filter(fn, list))
  | _ => operationInWrongType("filter", json)
  };
};

let id: 'a => 'a = i => i;

/* .store.books | filter(.price > 10) */
/* let transformedProgram = json => {
     json
     |> member("store")
     |> member("books")
     |> filter(item => gt(member("price", item), 10.));
   };
    */
