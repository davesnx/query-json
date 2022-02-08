(*   type padding = {
    bottom: int;
    top: int;
  }

  type minimap = {
    enabled: bool;
  }

  type options = {
    fontSize: int;
    fontFamily: string;
    glyphMargin: bool;
    lineNumbersMinChars: int;
    padding: padding;
    minimap: minimap;
    wordWrap: string;
    selectionHighlight: bool;
    occurrencesHighlight: bool;
    matchBrackets: string;
    readOnly: bool;
  }

  [@@js.custom
    type monaco_react_import = Ojs.t

    let monaco_react_import_to_js = Fun.id

    let make : monaco_react_import = Js_of_ocaml.Js.Unsafe.js_expr {|require("@monaco-editor/react")|}
  ]
 *)
