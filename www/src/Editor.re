module Monaco = {
  type padding = {
    bottom: int,
    top: int,
  };

  type minimap = {enabled: bool};

  /* Partial list of https://microsoft.github.io/monaco-editor/api/modules/monaco.editor.html */
  /* https://microsoft.github.io/monaco-editor/playground.html */
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
  };

  [@react.component] [@bs.module "@monaco-editor/react"]
  external make:
    (
      ~language: string,
      ~height: string,
      ~value: string,
      ~onChange: (ReactEvent.Form.t, string) => unit,
      ~className: string=?,
      ~style: ReactDOMRe.Style.t=?,
      ~theme: string,
      ~options: options
    ) =>
    React.element =
    "default";
};

let options: Monaco.options = {
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
};

[@react.component]
let make = (~value: string, ~onChange) => {
  <Monaco
    language="json"
    height="100%"
    value
    onChange
    options
    theme="dark"
    style={ReactDOMRe.Style.make(~padding="8px", ())}
  />;
};
