open React.Dom.Dsl;
open Html;
open Jsoo_css;

/*       input, textarea {
                padding: 8px;
              }

              textarea:active,
              input:active,
              textarea:focus,
              input:focus {
                /* background: rgb(237, 242, 247); */
                outline: 2px solid rgba(50, 100, 255, 0.6);
              }
         */

let interaction =
  Emotion.(outline(px(2), `solid, rgba(50, 100, 255, `num(0.6))));

let className =
  Emotion.(
    make([|
      width(`percent(100.)),
      unsafe("border", "none"),
      borderRadius(px(6)),
      background(rgb(32, 33, 36)),
      fontSize(px(18)),
      color(rgb(237, 242, 247)),
      padding(px(8)),
      focus([|interaction|]),
      active([|interaction|]),
    |])
  );

let get = (key, obj) => Ojs.get_prop_ascii(obj, key) |> Ojs.string_of_js;

[@react.component]
let make = (~value, ~placeholder, ~onChange) => {
  let onChangeHandler = event => {
    let value = React.Event.Form.target(event) |> get("value");
    onChange(value);
  };

  <input
    autoFocus=true
    className
    type_="text"
    value
    placeholder
    onChange=onChangeHandler
  />;
};
