open Belt;

[@bs.module "query-json-js"]
external queryJson: (string, string) => string = "run";

let mockJson = {|
  {
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
|};

module Header = {
  [@react.component]
  let make = () => {
    <Text> "Hello world" </Text>;
  };
};

module Page = {
  [@react.component]
  let make = (~children) => {
    children;
  };
};

module Query = {
  [@react.component]
  let make = (~value, ~placeholder, ~onChange) => {
    let onChangeHandler = event => {
      let value = ReactEvent.Form.target(event)##value;
      onChange(value);
    };

    <input type_="text" value placeholder onChange=onChangeHandler />;
  };
};

module Json = {
  [@react.component]
  let make = (~value, ~onChange) => {
    let onChangeHandler = event => {
      let value = ReactEvent.Form.target(event)##value;
      onChange(value);
    };

    <textarea value onChange=onChangeHandler />;
  };
};

module Result = {
  [@react.component]
  let make = (~text) =>
    <div> <pre> <code> {React.string(text)} </code> </pre> </div>;
};

type t = {
  query: string,
  json: option(string),
  result: option(string),
};

type actions =
  | UpdateQuery(string)
  | UpdateJson(string)
  | ComputeResult;

let reduce = (state, action) => {
  switch (action) {
  | UpdateQuery(query) => {...state, query}
  | UpdateJson(json) => {...state, json: Some(json)}
  | ComputeResult =>
    switch (state.json) {
    | Some(_json) =>
      /* let result = queryJson(state.query, json); */
      {...state, result: None}
    | None => state
    }
  };
};

[@react.component]
let make = () => {
  let (state, dispatch) =
    React.useReducer(
      reduce,
      {query: "", json: Some(mockJson), result: None},
    );

  let onQueryChange = value => {
    dispatch(UpdateQuery(value));
    dispatch(ComputeResult);
  };

  let onJsonChange = value => {
    dispatch(UpdateQuery(value));
    dispatch(ComputeResult);
  };

  <Page>
    <Header />
    <Query
      value={state.query}
      placeholder="Type the filter, ex: '.'"
      onChange=onQueryChange
    />
    <Json
      value={Option.getWithDefault(state.json, "")}
      onChange=onJsonChange
    />
    <Result text={Option.getWithDefault(state.result, "")} />
  </Page>;
};
