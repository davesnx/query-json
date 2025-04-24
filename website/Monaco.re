let noop = _ => ();

type mode =
  | Text
  | Json;

let mode_to_string =
  fun
  | Text => "text"
  | Json => "json";

type padding = {
  bottom: int,
  top: int,
};

type minimap = {enabled: bool};

type options = {
  fontSize: int,
  fontFamily: string,
  glyphMargin: bool,
  lineNumbersMinChars: int,
  padding,
  minimap,
  wordWrap: string,
  selectionHighlight: bool,
  occurrencesHighlight: bool,
  matchBrackets: string,
  readOnly: bool,
};

module External = {
  [@mel.module "@monaco-editor/react"] [@react.component]
  external make:
    (
      ~language: string,
      ~height: string,
      ~value: string,
      ~onChange: string => unit,
      ~className: string=?,
      ~style: ReactDOM.Style.t,
      ~theme: string,
      ~options: options
    ) =>
    React.element =
    "default";
};

let options: options = {
  fontSize: 16,
  fontFamily: "IBM Plex Mono",
  glyphMargin: false,
  lineNumbersMinChars: 3,
  padding: {
    top: 8,
    bottom: 8,
  },
  minimap: {
    enabled: false,
  },
  wordWrap: "on",
  selectionHighlight: false,
  occurrencesHighlight: false,
  matchBrackets: "never",
  readOnly: false,
};

type onChange =
  | Write(string => unit)
  | ReadOnly;

let isReadOnly =
  fun
  | Write(_) => false
  | ReadOnly => true;

[@react.component]
let make = (~value: string, ~onChange as onChangeValue: onChange, ~mode: mode) => {
  let onChange =
    switch (onChangeValue) {
    | ReadOnly => noop
    | Write(handler) => handler
    };

  let options = {
    ...options,
    readOnly: isReadOnly(onChangeValue),
  };

  <External
    value
    onChange
    options
    theme="dark"
    language={mode_to_string(mode)}
    height="100%"
    style=ReactDOM.Style.(make(~padding="8px", ~height="100%", ()))
  />;
};
