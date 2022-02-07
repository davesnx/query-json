open Belt;

let noop2 = (_, _) => ();

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

module Menu = [%styled.div
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

module SpacerBottom = [%styled.div "margin-bottom: 16px"];
module SpacerTop = [%styled.div "margin-top: 16px"];
module SpacerRight = [%styled.div "margin-right: 16px"];
module SpacerLeft = [%styled.div "margin-left: 16px; height: 100%;"];

module Page = [%styled.div
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
  align-items: center;
  |}
];

module Button = [%styled.button
  {|
  border: none;
  color: #FAFAFA;
  background: rgb(43, 75, 175);
  cursor: pointer;

  &:hover {
    background: rgba(43, 75, 175, 0.8);
  }
|}
];

module Link = [%styled.a
  {|
  text-decoration: none;
  color: #FAFAFA;
  cursor: pointer;

  display: inline-flex;
  align-items: center;

  &:hover {
    opacity: 0.6;
  }
|}
];

module Header = {
  [@react.component]
  let make = (~onShareClick) => {
    <Menu>
      <Wrapper>
        <Distribute>
          <Text color=`White kind=`H2> "query-json" </Text>
        </Distribute>
        <Distribute>
          <Link
            href="https://twitter.com/davesnx" target="_blank" rel="noopener">
            <Icons.Twitter />
          </Link>
          <SpacerLeft />
          <Link
            href="https://github.com/davesnx/query-json"
            target="_blank"
            rel="noopener">
            <Icons.Github />
          </Link>
          <SpacerLeft />
          <Button onClick=onShareClick>
            <Text> "Share unique URL" </Text>
          </Button>
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
      className=[%cx
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

    <Editor
      mode=Editor.Json
      value
      onChange=onChangeHandler
      isReadOnly=false
    />;
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
    <Editor mode=Editor.Text value="" onChange=noop2 isReadOnly=true />;
  };
};

module Output = {
  [@react.component]
  let make = (~value: response) => {
    let text =
      switch (value) {
      | Ok(o) => o
      | Error(e) =>
        /* TODO:
            Instead of removing the '[m' characters from Console and Compiler.
            They shoudn't add those if there's colorize=false.
            To sovle that, you would need to pass the flag to all Chalk and Compiler
            calls, which is a tedious task. Instead, we remove them here ^^ */
        Js.String.replaceByRe([%re "/\[\\d+m/g"], "", e)
      };

    let hasError = Result.isError(value);

    <Editor
      mode={hasError ? Editor.Text : Editor.Json}
      value=text
      isReadOnly=hasError
      onChange=noop2
    />;
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
  | ComputeOutput;

let reduce = (state, action) => {
  switch (action) {
  | UpdateQuery(query) => {...state, query}
  | UpdateJson(json) => {...state, json: Some(json)}
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
          <div>
            <SpacerLeft>
              {switch (state.output) {
               | Some(value) => <Output value />
               | None => <EmptyOutput />
               }}
            </SpacerLeft>
          </div>
        </ColumnHalf>
      </Row>
    </Container>
  </Page>;
};
