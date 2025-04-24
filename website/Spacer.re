type spacer =
  | Top
  | Bottom
  | Left
  | Right
  | All;

let className = (~direction as _, ~value as _) => {
  "Emotion.(\n    make([|\n      switch (directionValue) {\n      | Top => marginTop(px(value * 8))\n      | Bottom => marginBottom(px(value * 8))\n      | Left => marginLeft(px(value * 8))\n      | Right => marginRight(px(value * 8))\n      | All => margin(px(value * 8))\n      },\n    |])\n  )";
};

[@react.component]
let make = (~direction: spacer, ~value: int=0, ~children=React.null) => {
  <div className={className(~direction, ~value)}> children </div>;
};
