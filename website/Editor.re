module Empty = {
  [@react.component]
  let make = () => {
    <Monaco mode=Text value="" onChange=ReadOnly />;
  };
};

module Output = {
  [@react.component]
  let make = (~value) => {
    let text =
      switch (value) {
      | Ok(o) => o
      | Error(e) =>
        /* TODO:
           Instead of removing the '[m' characters from Console and Compiler.
           They shoudn't add those if there's colorize=false.
           To sovle that, you would need to pass the flag to all Chalk and Compiler
           calls, which is a tedious task. Instead, we remove them here ^^ */
        let re = Js_of_ocaml.Regexp.regexp("\\[\\d*m");
        Js_of_ocaml.Regexp.global_replace(re, e, "");
      };

    let hasError = Result.is_error(value);

    <Monaco mode={hasError ? Text : Json} value=text onChange=ReadOnly />;
  };
};

module Json = {
  [@react.component]
  let make = (~value, ~onChange) => {
    <Monaco mode=Json value onChange={Write(onChange)} />;
  };
};
