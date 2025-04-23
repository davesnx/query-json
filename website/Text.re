module Typography = {
  type color = [
    | `White
    | `Dark
    | `Grey
  ];

  type size = [
    | `Small
    | `Medium
    | `Large
    | `XXLarge
  ];

  type leading = [
    | `None
    | `Tight
    | `Snug
    | `Normal
    | `Relaxed
    | `Loose
  ];

  type weight = [
    | `Normal
    | `Bold
  ];

  [@react.component]
  let make =
      (~color as _, ~size as _=`Medium, ~weight as _=`Normal, ~children) => {
    /* let size =
         switch (size) {
         | `XSmall => fontSize(px(14))
         | `Small => fontSize(px(16))
         | `Medium => fontSize(px(18))
         | `Large => fontSize(px(20))
         | `XLarge => fontSize(px(26))
         | `XXLarge => fontSize(px(45))
         };

       let weight =
         switch (weight) {
         | `Normal => fontWeight(`num(400))
         | `Bold => fontWeight(`num(700))
         };

       let color =
         switch (colorValue) {
         | `White => color(hex("FAFAFA"))
         | `Black => color(`rgb((21, 21, 21)))
         | `Grey => color(hex("949495"))
         }; */

    let className = "Emotion.make([|color, size, weight|])";

    <span className> children </span>;
  };
};

type kinds = [
  | `H1
  | `H2
  | `H3
  | `H4
  | `H5
  | `Body
  | `Label
];

[@react.component]
let make = (~color=`White, ~kind=`Body, ~children) => {
  let (size, weight) =
    switch (kind) {
    | `H1 => (`XLarge, `Bold)
    | `H2 => (`Large, `Normal)
    | `H3 => (`Medium, `Normal)
    | `H4 => (`Small, `Normal)
    | `H5 => (`Medium, `Bold)
    | `Body => (`Medium, `Normal)
    | `Label => (`Small, `Normal)
    };

  <Typography size weight color> children </Typography>;
};
