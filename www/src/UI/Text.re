module Typography = {
  type color = [ | `White | `Dark | `Grey];
  type size = [ | `Small | `Medium | `Large | `XXLarge];
  type leading = [ | `None | `Tight | `Snug | `Normal | `Relaxed | `Loose];
  type align = [ | `Left | `Right | `Center | `Justify];
  type tracking = [ | `Tight | `Normal | `Wide];
  type weight = [ | `Normal | `Bold];

  type fontFamily = [ | `Sans | `Mono];

  [@react.component]
  let make =
      (
        ~color,
        ~tracking=`Normal,
        ~size=`Medium,
        ~weight=`Normal,
        ~align=`Left,
        ~inline as _,
        ~uppercase as _,
        ~truncate as _,
        ~fontFamily: fontFamily=`Sans,
        ~children,
      ) => {
    let _tracking =
      switch (tracking) {
      | `Tighter => "tracking-tighter"
      | `Tight => "tracking-tight"
      | `Normal => "tracking-normal"
      | `Wide => "tracking-wide"
      | `Wider => "tracking-wider"
      | `Widest => "tracking-widest"
      };

    let size =
      switch (size) {
      | `XSmall => [%cx "font-size: 14px"]
      | `Small => [%cx "font-size: 16px"]
      | `Medium => [%cx "font-size: 18px"]
      | `Large => [%cx "font-size: 20px"]
      | `XLarge => [%cx "font-size: 26px"]
      | `XXLarge => [%cx "font-size: 45px"]
      };

    let weight =
      switch (weight) {
      | `Normal => [%cx "font-weight: 400"]
      | `Bold => [%cx "font-weight: 700"]
      };

    let _align =
      switch (align) {
      | `Left => "text-left"
      | `Right => "text-right"
      | `Justify => "text-justify"
      | `Center => "text-center"
      };

    let _fontFamily =
      switch (fontFamily) {
      | `Sans => "font-sans"
      | `Mono => "font-mono"
      };

    let color =
      switch (color) {
      | `White => [%cx "color: #FAFAFA"]
      | `Black => [%cx "color: rgb(21, 21, 21);"]
      | `Grey => [%cx "color: #949495"]
      };

    let className = color ++ " " ++ size ++ " " ++ weight;

    <span className> children </span>;
  };
};

type kinds = [ | `H1 | `H2 | `H3 | `H4 | `H5 | `Body | `Label];

[@react.component]
let make =
    (
      ~color=`White,
      ~align=`Left,
      ~inline=false,
      ~uppercase=false,
      ~truncate=false,
      ~children,
      ~kind=`Body,
      ~fontFamily=?,
      ~tracking=?,
    ) => {
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

  <Typography
    size weight align inline color truncate uppercase ?fontFamily ?tracking>
    {React.string(children)}
  </Typography>;
};
