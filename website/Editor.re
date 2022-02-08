type mode =
  | Text
  | Json;

let noop2 = (_, _) => ();

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
  readOnly: false,
};

[@react.component]
let make =
    (
      ~value: string,
      ~onChange: (React.Event.Form.t, string) => unit,
      ~mode,
      ~isReadOnly: bool,
    ) => {
  let language =
    switch (mode) {
    | Text => "text"
    | Json => "json"
    };

  let onChange = isReadOnly ? noop2 : onChange;

  <Monaco
    language
    height="100%"
    value
    onChange
    options={...options, readOnly: isReadOnly}
    theme="dark"
    style={React.Dom.Style.(make([|padding("8px")|]))}
  />;
};
