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
  {|require("@monaco-editor/react")|};
