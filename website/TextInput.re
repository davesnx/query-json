open React.Dom.Dsl;
open Html;
open Jsoo_css;

let className =
  Emotion.(
    make([|
      width(`percent(100.)),
      unsafe("border", "none"),
      background(rgb(32, 33, 36)),
      fontSize(px(18)),
      color(rgb(237, 242, 247)),
    |])
  );

[@react.component]
let make = (~value, ~placeholder, ~onChange) => {
  let onChangeHandler = _event => {
    let value = ""; /* React.Event.Form.target(event)##value; */
    onChange(value);
  };

  <input className type_="text" value placeholder onChange=onChangeHandler />;
};
