open React.Dom.Dsl;
open Html;
open Jsoo_css;

let noop2 = (_, _) => ();

module Router = {
  /* include ReasonReactRouter; */
};

/* module Base64 = {
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
}; */

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

module Spacer = {
  type spacer = Top | Bottom | Left | Right;
  let className = (~direction as _, ~value=0, _) => {
    Emotion.(make([|
      /* switch (direction) {
        | Top => marginTop(px(value * 8))
        | Bottom => marginBottom(px(value * 8))
        | Left => marginLeft(px(value * 8))
        | Right => marginRight(px(value * 8))
      } */
    |]))
  };

  [@react.component]
  let make = (~direction: spacer, ~value: int, ~children) => {
    <div className={className(~direction, ~value, ())}>
      ...children
    </div>
  }
};

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

let columnhalf = Emotion.(make([|
  width(`percent(50.)),
  height(`percent(100.))
|]));

let row = Emotion.(make([|
  display(`flex),
  flexDirection(`row),
  width(`percent(100.)),
  height(`percent(100.))
|]));

module Header = {
  let menu = Emotion.(make([|
    width(vw(100.)),
    height(vh(7.)),
    background(rgb(32, 33, 37)),
  |]));

  let wrapper = Emotion.(make([|
    width(vw(75.)),
    height(`percent(100.)),
    /* margin2(~h=0, ~w=`auto), */
    display(`flex),
    justifyContent(`spaceBetween),
    alignItems(`center)
  |]));

  let distribute = Emotion.(make([|
    display(`flex),
    flexDirection(`row),
    alignItems(`center)
  |]));

  let link = Emotion.(make([|
    textDecoration(`none),
    color(hex("FAFAFA")),
    cursor(`pointer),
    display(`inlineFlex),
    alignItems(`center),

    selector("&:hover", [|
      opacity(0.6)
    |]),
  |]));

  let button = Emotion.(make([|
    unsafe("border", "none"),
    color(hex("FAFAFA")),
    backgroundColor(rgb(43, 75, 175)),
    cursor(`pointer),

    selector("&:hover", [|
      backgroundColor(rgba(43, 75, 175, `percent(80.))),
    |]),
  |]));


  [@react.component]
  let make = (~onShareClick) => {
    <Spacer direction=Bottom value=4>
      <div className=menu>
        <div className=wrapper>
          <div className=distribute>
            <Text color=`White kind=`H2> {"query-json" |> React.string} </Text>
          </div>
          <div className=distribute>
            <a className=link
              href="https://twitter.com/davesnx" target="_blank" rel="noopener">
              <Icons.Twitter />
            </a>
            <Spacer direction=Left value={2}>
              <a className=link
                href="https://github.com/davesnx/query-json"
                target="_blank"
                rel="noopener">
                <Icons.Github />
              </a>
            </Spacer>
            <Spacer direction=Left value={2}>
              <button className=button onClick=onShareClick>
                <Text> {"Share unique URL" |> React.string} </Text>
              </button>
            </Spacer>
          </div>
        </div>
      </div>
    </Spacer>;
  };
};

module Query = {
  let className = Emotion.(make([|
    width(`percent(100)),
    border(`none),
    background(`rgb(32, 33, 36)),
    fontSize(px(18)),
    color(rgb(237, 242, 247)),
  |]));

  [@react.component]
  let make = (~value, ~placeholder, ~onChange) => {
    let onChangeHandler = event => {
      let value = React.Event.Form.target(event)##value;
      onChange(value);
    };

    <input
      type_="text"
      value
      placeholder
      onChange=onChangeHandler
      className
    />;
  };
};

module Json = {
  [@react.component]
  let make = (~value as _, ~onChange) => {
    let _onChangeHandler = (_event, value) => {
      onChange(value);
    };

    /* <Editor
      mode=Editor.Json
      value
      onChange=onChangeHandler
      isReadOnly=false
    />; */
    React.null;
  };
};

let box = Emotion.(make([|
  backgroundColor(rgb(237, 242, 247)),
  height(`percent(100)),
  width(`percent(100)),
  borderRadius(px(6)),
|]));

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
        /* Js.String.replaceByRe([%re "/\[\\d+m/g"], "", e) */
        ""
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

/* [@react.component]
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
      <Spacer direction=Bottom value={2} />
      <Row>
        <ColumnHalf>
          <Json
            value={Option.getWithDefault(state.json, "")}
            onChange=onJsonChange
          />
          <Spacer direction=Right value={2} />
        </ColumnHalf>
        <ColumnHalf>
          <div>
            <Spacer direction=Left value={2}>
              {switch (state.output) {
               | Some(value) => <Output value />
               | None => <EmptyOutput />
               }}
            </Spacer>
          </div>
        </ColumnHalf>
      </Row>
    </Container>
  </Page>;
};
 */
