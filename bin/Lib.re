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

module Lib = {
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
      tryingToOperateInAWrongType(name, "int: %d\n", Some(string_of_int(i)))
    | `Null => tryingToOperateInAWrongType(name, "null", None)
    | `String(s) => tryingToOperateInAWrongType(name, "string", Some(s))
    };
  };

  let key = (id, json: Yojson.Basic.t) => {
    switch (json) {
    | `String(x) => filter_member(x)
    | _ => operationInWrongType("." ++ id, json)
    };
  };

  let truncate = (json: Yojson.Basic.t) => {
    switch (json) {
    | `Float(f) => f +. 1.
    | _ => operationInWrongType("truncate", json)
    };
  };

  let mapper = (f, json: list(Yojson.Basic.t)) => {
    List.map(
      item => {
        switch ((item: Yojson.Basic.t)) {
        | `List(list) => List.map(f, list)
        | _ => operationInWrongType("map", item)
        }
      },
      json,
    );
  };
};
