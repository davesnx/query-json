open React.Dom.Dsl;
open Html;
open Jsoo_css;

type spacer =
  | Top
  | Bottom
  | Left
  | Right
  | All;

let className = (~direction as directionValue, ~value) => {
  Emotion.(
    make([|
      switch (directionValue) {
      | Top => marginTop(px(value * 8))
      | Bottom => marginBottom(px(value * 8))
      | Left => marginLeft(px(value * 8))
      | Right => marginRight(px(value * 8))
      | All => margin(px(value * 8))
      },
    |])
  );
};

[@react.component]
let make = (~direction: spacer, ~value: int=0, ~children=[React.null]) => {
  <div className={className(~direction, ~value)}> ...children </div>;
};
