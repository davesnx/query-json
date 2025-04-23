let interaction = "Emotion.(outline(px(2), `solid, rgba(50, 100, 255, `num(0.6))))";

let className = "border-none Emotion.(
    make([|
      width(`percent(100.)),
      borderRadius(px(6)),
      background(rgb(32, 33, 36)),
      fontSize(px(18)),
      color(rgb(237, 242, 247)),
      padding(px(8)),
      focus([|interaction|]),
      active([|interaction|]),
    |])
  )";

[@react.component]
let make = (~value, ~placeholder, ~onChange) => {
  let onChangeHandler = event => {
    let target = React.Event.Form.target(event);
    onChange(target##value);
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
