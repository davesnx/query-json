module Monaco = {
  type padding = {
    bottom: int,
    top: int,
  };

  type minimap = {enabled: bool};

  /* Partial list of https://microsoft.github.io/monaco-editor/api/modules/monaco.editor.html */
  type options = {
    fontSize: int,
    fontFamily: string,
    glyphMargin: bool,
    lineNumbersMinChars: int,
    padding,
    minimap,
  };

  [@react.component] [@bs.module "@monaco-editor/react"]
  external make:
    (
      ~language: string,
      ~height: string,
      ~value: string,
      ~onChange: (ReactEvent.Form.t, string) => unit,
      ~className: string,
      ~style: ReactDOMRe.Style.t=?,
      ~theme: string,
      ~options: options
    ) =>
    React.element =
    "default";
};

[@react.component]
let make = (~value: string, ~onChange) => {
  <Monaco
    language="json"
    height="100%"
    value
    onChange
    options={
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
    }
    theme="dark"
    style={ReactDOMRe.Style.make(~padding="8px", ())}
    className=[%css {|
         border-radius: 4px;
       |}]
  />;
};
