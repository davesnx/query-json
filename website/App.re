open React.Dom.Dsl;
open Html;
open Jsoo_css;

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

let page =
  Emotion.(
    make([|
      display(`flex),
      flexDirection(`column),
      alignItems(`center),
      height(vh(100.)),
      backgroundColor(hex("0a0a0a")),
    |])
  );

let container = Emotion.(make([|width(`vw(75.)), height(`vh(80.))|]));

let columnHalf =
  Emotion.(
    make([|
      width(`percent(50.)),
      height(`percent(100.)),
      paddingBottom(px(8)),
    |])
  );

let row =
  Emotion.(
    make([|
      display(`flex),
      flexDirection(`row),
      width(`percent(100.)),
      height(`percent(100.)),
    |])
  );

let box =
  Emotion.(
    make([|
      backgroundColor(rgb(237, 242, 247)),
      height(`percent(100.)),
      width(`percent(100.)),
      borderRadius(px(6)),
    |])
  );

type t = {
  query: string,
  json: option(string),
};

type actions =
  | UpdateQuery(string)
  | UpdateJson(string);

let reduce = state =>
  fun
  | UpdateQuery(query) => {...state, query}
  | UpdateJson(json) => {...state, json: Some(json)};

module QueryParams = {
  type t = {
    query: string,
    json: option(string),
  };

  let decode = json => {
    Jsonoo.Decode.{
      query: json |> field("query", string),
      json: json |> nullable(field("json", string)),
    };
  };

  let encode = t => {
    Jsonoo.Encode.(
      object_([
        ("query", string(t.query)),
        ("json", nullable(string, t.json)),
      ])
    );
  };

  let toString = t => {
    t |> encode |> Jsonoo.stringify;
  };

  let fromString = str => {
    str |> Jsonoo.try_parse_opt |> Option.map(decode);
  };

  let toHash = state => {
    state |> toString |> Base64.encode;
  };
};

/* Option.bind with pipe-last friendly */
let bind = (f, o) =>
  switch (o) {
  | None => None
  | Some(v) => f(v)
  };

[@react.component]
let make = () => {
  let hash = Router.getHash();
  Printf.eprintf("%s", hash |> Option.value(~default="hash roto"));

  let stateFromHash =
    hash |> bind(Base64.decode) |> bind(QueryParams.fromString);

  let initialState =
    switch (stateFromHash) {
    | Some({query, json}) => {query, json}
    | None => {query: "", json: Some(mockJson)}
    };
  let (state, dispatch) = React.useReducer(reduce, initialState);

  let onQueryChange = value => {
    dispatch(UpdateQuery(value));
  };

  let onJsonChange = value => {
    dispatch(UpdateJson(value));
  };

  let output =
    switch (state.json, state.query) {
    | (Some(_), "")
    | (None, _) => None
    | (Some(json), _) => Some(QueryJsonJs.run(state.query, json))
    };

  let onShareClick = _ => {
    let hash = QueryParams.toHash({query: state.query, json: state.json});
    switch (hash) {
    | Some(hash) => Router.setHash(hash)
    | None => Printf.eprintf("Error decoding")
    };
  };

  <div className=page>
    <Header onShareClick />
    <Spacer direction=Bottom value=2 />
    <div className=container>
      <Spacer direction=Bottom value=2>
        <TextInput
          value={state.query}
          onChange=onQueryChange
          placeholder="Type the query to filter against the JSON below. For example: '.store'"
        />
      </Spacer>
      <div className=row>
        <div className=columnHalf>
          <Editor.Json
            value={Option.value(state.json, ~default="")}
            onChange=onJsonChange
          />
        </div>
        <Spacer direction=Right value=2 />
        <div className=columnHalf>
          {switch (output) {
           | Some(value) => <Editor.Output value />
           | None => <Editor.Empty />
           }}
        </div>
      </div>
    </div>
  </div>;
};
