open Belt;

module Router = {
  include ReasonReactRouter;
};

type response = result(string, string);

[@bs.module "../../_build/default/js/Js.bc.js"]
external queryJson: (string, string) => response = "run";

module Base64 = {
  [@bs.val] external btoa: string => string = "window.btoa";
  [@bs.val] external atob: string => string = "window.atob";

  let encode = string =>
    try(Ok(btoa(string))) {
    | _exn => Error("There was a problem turning string to Base64")
    };

  let decode = string =>
    try(Ok(atob(string))) {
    | _exn => Error("There was a problem turning Base64 to string")
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

module Menu = [%styled
  {|
  width: 100vw;
  height: 7vh;
  background: rgb(32, 33, 37);
  margin-bottom: 32px;
|}
];

module Wrapper = [%styled.main
  {|
  width: 75vw;
  height: 100%;
  margin: 0 auto;

  display: flex;
  justify-content: space-between;
  align-items: center;
|}
];

module SpacerBottom = [%styled "margin-bottom: 16px"];
module SpacerTop = [%styled "margin-top: 16px"];
module SpacerRight = [%styled "margin-right: 16px"];
module SpacerLeft = [%styled "margin-left: 16px; height: 100%;"];

module Page = [%styled
  {|
  display: flex;
  flex-direction: column;
  align-items: center;
  height: 100vh;
  background: #0a0a0a;
|}
];

module Container = [%styled.main {|
  width: 75vw;
  height: 80vh;
|}];

module ColumnHalf = [%styled.div {|
  width: 50%;
  height: 100%;
|}];

module Row = [%styled.div
  {|
  display: flex;
  flex-direction: row;

  width: 100%;
  height: 100%;
  |}
];

module Distribute = [%styled.div
  {|
  display: flex;
  flex-direction: row;
  |}
];

module Button = [%styled.button
  {|
  border: none;
  color: white;
  background: rgb(50, 100, 255);
|}
];

module Header = {
  [@react.component]
  let make = (~onShareClick) => {
    <Menu>
      <Wrapper>
        <Distribute>
          <Text color=`White> "query-json" </Text>
          <SpacerLeft />
          <Text color=`Grey kind=`Body>
            "Faster and simpler implementation of jq in Reason Native"
          </Text>
        </Distribute>
        <Distribute>
          <Button onClick=onShareClick> <Text> "Share" </Text> </Button>
          <SpacerLeft />
          <Text color=`White> "github-logo" </Text>
          <SpacerLeft />
          <Text color=`White> "twitter-logo" </Text>
        </Distribute>
      </Wrapper>
    </Menu>;
  };
};

module Query = {
  [@react.component]
  let make = (~value, ~placeholder, ~onChange) => {
    let onChangeHandler = event => {
      let value = ReactEvent.Form.target(event)##value;
      onChange(value);
    };

    <input
      type_="text"
      value
      placeholder
      onChange=onChangeHandler
      className=[%css
        {|
        width: 100%;
        border: none;
        background: rgb(32, 33, 36);
        font-size: 18px;
        color: rgb(237, 242, 247);
    |}
      ]
    />;
  };
};

module Json = {
  [@react.component]
  let make = (~value, ~onChange) => {
    let onChangeHandler = (_event, value) => {
      onChange(value);
    };

    <Editor value onChange=onChangeHandler />;
  };
};

module Box = [%styled.div
  {|
  background: rgb(237, 242, 247);
  height: 100%;
  width: 100%;

  border-radius: 4px;
|}
];

module EmptyOutput = {
  [@react.component]
  let make = () => {
    let noop = (_, _) => ();
    <Editor value="" onChange=noop />;
  };
};

module Output = {
  [@react.component]
  let make = (~value: response, ~onChange) => {
    let text =
      switch (value) {
      | Ok(o) => o
      | Error(e) =>
        /* TODO: Instead of removing the '[m' characters, Console and Compiler
            shoudn't add those if there's colorize=false. It's a tedious task, to break all the Chalk calls and Compiler calls. That's why we transform the output.
           */
        Js.String.replaceByRe([%re "/\[\d+m/g"], "", e)
      };

    let hasError = Result.isOk(value);

    let onChangeHandler = (_event, value) =>
      if (!hasError) {
        onChange(value);
      };

    <Editor value=text onChange=onChangeHandler />;
  };
};

type t = {
  query: string,
  json: option(string),
  output: option(response),
};

type actions =
  | UpdateQuery(string)
  | UpdateJson(string)
  | UpdateResult(string)
  | ComputeOutput;

let reduce = (state, action) => {
  switch (action) {
  | UpdateQuery(query) => {...state, query}
  | UpdateJson(json) => {...state, json: Some(json)}
  | UpdateResult(value) => {...state, output: Some(Ok(value))}
  | ComputeOutput =>
    switch (state.json) {
    | Some(json) =>
      let result = queryJson(state.query, json);
      Js.log(result);
      {...state, output: Some(result)};
    | None => state
    }
  };
};

module QueryParams = {
  [@decco]
  type t = {
    query: string,
    json: option(string),
  };
  let toState = qp => {
    {query: qp.query, json: qp.json, output: None};
  };

  let decode = (json: Js.Json.t) => {
    switch (t_decode(json)) {
    | Ok(o) => Ok(o)
    | Error(_) => Error("Problem decoding QueryParams")
    };
  };

  let encode = (queryParams): Js.Json.t => {
    t_encode(queryParams);
  };
};

[@react.component]
let make = () => {
  let url = Router.useUrl();

  let urlState =
    switch (url.hash) {
    | data when String.length(data) > 0 =>
      let base64 = Base64.decode(data);
      let json = Result.map(base64, Js.Json.parseExn);
      switch (Result.flatMap(json, QueryParams.decode)) {
      | Ok(res) => Some(res)
      | Error(_) => None
      };
    | "" => None
    | _ => None
    };

  let initialState =
    switch (urlState) {
    | Some(state) =>
      let result = queryJson(state.query, empty(state.json));
      let newState = QueryParams.toState(state);
      {...newState, output: Some(result)};
    | None => {query: "", json: Some(mockJson), output: None}
    };

  let (state, dispatch) = React.useReducer(reduce, initialState);

  let onQueryChange = value => {
    dispatch(UpdateQuery(value));
    dispatch(ComputeOutput);
  };

  let onJsonChange = value => {
    dispatch(UpdateJson(value));
    dispatch(ComputeOutput);
  };

  let onResultChange = value => {
    dispatch(UpdateResult(value));
  };

  let onShareClick = _ => {
    let seachParams =
      QueryParams.encode({query: state.query, json: state.json});
    let searchString = Js.Json.stringifyWithSpace(seachParams, 2);
    let encodedSearch = Base64.encode(searchString);

    switch (encodedSearch) {
    | Ok(url) => Router.push("#" ++ url)
    | Error(_) => ()
    };
  };

  <Page>
    <Header onShareClick />
    <Container>
      <Query
        value={state.query}
        placeholder="Type the filter, ex: '.'"
        onChange=onQueryChange
      />
      <SpacerBottom />
      <Row>
        <ColumnHalf>
          <Json
            value={Option.getWithDefault(state.json, "")}
            onChange=onJsonChange
          />
          <SpacerRight />
        </ColumnHalf>
        <ColumnHalf>
          <div className="non-scroll">
            <SpacerLeft>
              {switch (state.output) {
               | Some(value) => <Output value onChange=onResultChange />
               | None => <EmptyOutput />
               }}
            </SpacerLeft>
          </div>
        </ColumnHalf>
      </Row>
    </Container>
  </Page>;
};
