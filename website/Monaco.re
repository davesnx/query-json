let noop2 = (_, _) => ();

module Mode = {
  type t =
    | Text
    | Json;

  let to_language =
    fun
    | Text => "text"
    | Json => "json";
};

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
  [@react.component]
  external make:
    (
      ~language: string,
      ~height: string,
      ~value: string,
      ~onChange: (React.Event.Form.t, string) => unit,
      ~className: string=?,
      ~style: React.Dom.Style.t,
      ~theme: string,
      ~options: options
    ) =>
    React.element =
    {|require("@monaco-editor/react").Editor|};
};

let options = {
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

type onChange = | Write((React.Event.Form.t, string) => unit) | ReadOnly;

let isReadOnly = fun
  | Write(_) => false
  | ReadOnly => true;

[@react.component]
let make =
    (
      ~value: string,
      ~onChange as onChangeValue: onChange,
      ~mode
    ) => {
  let onChange = switch (onChangeValue) {
    | ReadOnly => noop2
    | Write(handler) => handler
  };

  <External
    language={Mode.to_language(mode)}
    height="100%"
    value
    onChange
    options={...options, readOnly: isReadOnly(onChangeValue)}
    theme="dark"
    style=React.Dom.Style.(make([|padding("8px")|]))
  />;
};
