open React.Dom.Dsl;
open Html;
open Jsoo_css;

module Router = {
  open Js_of_ocaml;
  let getHash = (): option(string) => {
    let url = Url.Current.get();
    switch (url) {
      | Some(Http(http_url)) => Some(http_url.hu_fragment)
      | Some(Https(http_url)) => Some(http_url.hu_fragment)
      | _ => None
    }
  };

  let setHash = (_hash): unit => {
    ();
    /* Url.Current.setHash(hash); */
  };
};

module Value = {
  type t;
  type prop = string;
  external pure_js_expr: string => 'a = "caml_pure_js_expr";
  external get: (t, prop) => t = "caml_js_get";
  external set: (t, prop, t) => unit = "caml_js_set";
  external apply: (t, array(t)) => 'a = "caml_js_fun_call";

  external of_string: string => t = "caml_jsstring_of_string";
  external to_string: t => string = "caml_string_of_jsstring";
  let global = pure_js_expr("globalThis");
};

module Base64 = {
  type data = Value.t;
  let encode = bs =>
    switch (Value.apply(Value.get(Value.global, "btoa"), Value.([|of_string(bs)|]))) {
    | Ok(v) => Ok(Value.to_string(v))
    | Error(e) => Error(e)
    };

  let decode = s =>
    switch (Value.apply(Value.get(Value.global, "atob"), Value.([|of_string(s)|]))) {
    | Ok(v) => Ok(Value.to_string(v))
    | Error(e) => Error(e)
    };
};

let empty = opt => {
  switch (opt) {
  | Some(o) => o
  | None => ""
  };
};

let mockJson = {|{
  "store": {
    "books": [
      {
        "category": "reference",
        "author": "Nigel Rees",
        "title": "Sayings of the Century",
        "price": 8.95
      },
      {
        "category": "fiction",
        "author": "Evelyn Waugh",
        "title": "Sword of Honour",
        "price": 12.99
      },
      {
        "category": "fiction",
        "author": "Herman Melville",
        "title": "Moby Dick",
        "isbn": "0-553-21311-3",
        "price": 8.99
      },
      {
        "category": "fiction",
        "author": "J. R. R. Tolkien",
        "title": "The Lord of the Rings",
        "isbn": "0-395-19395-8",
        "price": 22.99
      }
    ]
  }
}
|};

let page = Emotion.(make([|
  display(`flex),
  flexDirection(`column),
  alignItems(`center),
  height(vh(100.)),
  backgroundColor(hex("0a0a0a")),
|]));

let container = Emotion.(make([|
  width(`vw(75.)),
  height(`vh(80.))
|]));

let columnHalf = Emotion.(make([|
  width(`percent(50.)),
  height(`percent(100.))
|]));

let row = Emotion.(make([|
  display(`flex),
  flexDirection(`row),
  width(`percent(100.)),
  height(`percent(100.))
|]));

let box = Emotion.(make([|
  backgroundColor(rgb(237, 242, 247)),
  height(`percent(100.)),
  width(`percent(100.)),
  borderRadius(px(6)),
|]));

type t = {
  query: string,
  json: option(string),
  output: option(result(string, string)),
};

type actions =
  | UpdateQuery(string)
  | UpdateJson(string)
  | ComputeOutput;

let reduce = (state, action) => {
  switch (action) {
  | UpdateQuery(query) => {...state, query}
  | UpdateJson(json) => {...state, json: Some(json)}
  | ComputeOutput =>
    switch (state.json) {
    | Some(json) =>
      let result = QueryJsonJs.run(state.query, json);
      {...state, output: Some(result)};
    | None => state
    }
  };
};

/* module QueryParams = {
  [@deriving jsobject]
  type hash = {
    query: string,
    json: option(string),
  };
  let toState = qp => {
    {query: qp.query, json: qp.json, output: None};
  };

  let decode = (json) => {
    switch (hash_of_jsobject(json)) {
    | Ok(o) => Ok(o)
    | Error(_) => Error("Problem decoding QueryParams")
    };
  };

  let encode = (queryParams: hash): string => {
    jsobject_of_hash(queryParams);
  };
}; */

[@react.component]
let make = () => {
  let _hash = Router.getHash();

  /* let urlState =
    switch (hash) {
    | None => None
    | Some(data) => {
        let base64 = Base64.decode(data);
        let json = Result.map(base64, Js.Json.parseExn);
        let res = Result.bind(json, QueryParams.decode)
        res |> Result.to_option;
      };
    };

  let initialState =
    switch (urlState) {
    | Some(state) =>
      let result = queryJson(state.query, empty(state.json));
      let newState = QueryParams.toState(state);
      {...newState, output: Some(result)};
    | None => {query: "", json: Some(mockJson), output: None}
    }; */

  let initialState = {query: "", json: Some(mockJson), output: None};
  let (state, dispatch) = React.useReducer(reduce, initialState);

  let onQueryChange = value => {
    dispatch(UpdateQuery(value));
    dispatch(ComputeOutput);
  };

  let onJsonChange = value => {
    dispatch(UpdateJson(value));
    dispatch(ComputeOutput);
  };

  let onShareClick = _ => {
    ();
    /* let searchParams =
      QueryParams.encode({query: state.query, json: state.json});
    let encodedHash = Base64.encode(searchParams);

    switch (encodedHash) {
    | Ok(hash) => Router.setHash(hash)
    | Error(_) => ()
    }; */
  };

  <div className=page>
    <Header onShareClick />
    <div className=container>
      <Spacer direction=Bottom value=2>
        <TextInput
          value={state.query}
          placeholder="Type the filter, for example: '.'"
          onChange=onQueryChange
        />
      </Spacer>
      <div className=row>
        <div className=columnHalf>
          <Spacer direction=Right value=2>
            <Editor.Json
              value={Option.value(state.json, ~default="")}
              onChange=onJsonChange
            />
          </Spacer>
        </div>
        <div className=columnHalf>
          <div>
            <Spacer direction=Left value=2>
              {switch (state.output) {
               | Some(value) => <Editor.Output value />
               | None => <Editor.Empty />
               }}
            </Spacer>
          </div>
        </div>
      </div>
    </div>
  </div>;
};
