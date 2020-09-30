open Belt;

type response = result(string, string);

[@bs.module "../../_build/default/js/Js.bc.js"]
external queryJson: (string, string) => response = "run";

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
  height: 10vh;
  background: rgb(32, 33, 37);
  margin-bottom: 40px;
|}
];

module Header = {
  [@react.component]
  let make = () => {
    <Menu> <Text> "" </Text> </Menu>;
  };
};

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
|}
];

module Container = [%styled.main
  {|
  width: 75vw;
  height: 80vh;

  display: flex;
  flex-direction: row;
  justify-content: space-around;
|}
];

module ColumnHalf = [%styled.div {|
  width: 50%;
  height: 100%;
|}];

module Stack = [%styled.div
  {|
  display: flex;
  flex-direction: column;

  height: 100%;
  |}
];

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
        border: none;
        color: rgb(74, 85, 104);
        border-radius: 4px;
        font-size: 18px;
        background: rgb(237, 242, 247);
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

module EmptyResult = {
  [@react.component]
  let make = () => {
    let noop = (_, _) => ();
    <Editor value="" onChange=noop />;
  };
};

module Result = {
  [@react.component]
  let make = (~value: response, ~onChange) => {
    let text =
      switch (value) {
      | Ok(o) => o
      | Error(e) => e
      };

    let onChangeHandler = (_event, value) => {
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
      {...state, output: Some(result)};
    | None => state
    }
  };
};

[@react.component]
let make = () => {
  let (state, dispatch) =
    React.useReducer(
      reduce,
      {query: "", json: Some(mockJson), output: None},
    );

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

  <Page>
    <Header />
    <Container>
      <ColumnHalf>
        <Stack>
          <Query
            value={state.query}
            placeholder="Type the filter, ex: '.'"
            onChange=onQueryChange
          />
          <SpacerBottom />
          <Json
            value={Option.getWithDefault(state.json, "")}
            onChange=onJsonChange
          />
        </Stack>
        <SpacerRight />
      </ColumnHalf>
      <ColumnHalf>
        <div className="non-scroll">
          <SpacerLeft>
            {switch (state.output) {
             | Some(value) => <Result value onChange=onResultChange />
             | None => <EmptyResult />
             }}
          </SpacerLeft>
        </div>
      </ColumnHalf>
    </Container>
  </Page>;
};
