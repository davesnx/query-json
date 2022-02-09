type mode =
  | Text
  | Json;

let noop2 = (_, _) => ();

/*
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
     readOnly: bool,
   };

   [@react.component] [@bs.module "@monaco-editor/react"]
   external make:
     (
       ~language: string,
       ~height: string,
       ~value: string,
       ~onChange: (React.Event.Form.t, string) => unit,
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
   readOnly: false,
 };

 [@react.component]
 let make =
     (
       ~value: string,
       ~onChange: (ReactEvent.Form.t, string) => unit,
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
     style={ReactDOMRe.Style.make(~padding="8px", ())}
   />;
 };
 */

module Editor = {
  [@react.component]
  let make =
      (
        ~value as _: string,
        ~onChange as _: (React.Event.Form.t, string) => unit,
        ~mode as _,
        ~isReadOnly as _: bool,
      ) => {
    React.null;
  };
};

module Empty = {
  [@react.component]
  let make = () => {
    <Editor mode=Text value="" onChange=noop2 isReadOnly=true />;
  };
};

module Output = {
  [@react.component]
  let make = (~value) => {
    let text =
      switch (value) {
      | Ok(o) => o
      | Error(_e) =>
        /* TODO:
           Instead of removing the '[m' characters from Console and Compiler.
           They shoudn't add those if there's colorize=false.
           To sovle that, you would need to pass the flag to all Chalk and Compiler
           calls, which is a tedious task. Instead, we remove them here ^^ */
        /* Js.String.replaceByRe([%re "/\[\\d+m/g"], "", e) */
        ""
      };

    let hasError = Result.is_error(value);

    <Editor
      mode={hasError ? Text : Json}
      value=text
      isReadOnly=hasError
      onChange=noop2
    />;
  };
};

module Json = {
  [@react.component]
  let make = (~value, ~onChange) => {
    let onChangeHandler = (_event, value) => {
      onChange(value);
    };

    <Editor mode=Json value onChange=onChangeHandler isReadOnly=false />;
  };
};
