module Typography = {
  type size = [ | `Small | `Medium | `Large | `XXLarge];
  type leading = [ | `None | `Tight | `Snug | `Normal | `Relaxed | `Loose];
  type align = [ | `Left | `Right | `Center | `Justify];
  type tracking = [ | `Tight | `Normal | `Wide];
  type weight = [
    | `Thin
    | `Light
    | `Normal
    | `Medium
    | `Semibold
    | `Bold
    | `Extrabold
    | `Black
  ];

  type fontFamily = [ | `Sans | `Mono];

  [@react.component]
  let make =
      (
        ~color as _,
        ~tracking=`Normal,
        ~size=`Medium,
        ~weight=`Normal,
        ~leading=`Normal,
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

    let _size =
      switch (size) {
      | `XSmall => "text-xs"
      | `Small => "text-sm"
      | `Medium => "text-md"
      | `Large => "text-lg"
      | `XLarge => "text-xl"
      | `XXLarge => "text-xxl"
      };

    let _weight =
      switch (weight) {
      | `Hairline => "font-hairline"
      | `Thin => "font-thin"
      | `Light => "font-light"
      | `Normal => "font-normal"
      | `Medium => "font-medium"
      | `Semibold => "font-semibold"
      | `Bold => "font-bold"
      | `Extrabold => "font-extrabold"
      | `Black => "font-black"
      };

    let _align =
      switch (align) {
      | `Left => "text-left"
      | `Right => "text-right"
      | `Justify => "text-justify"
      | `Center => "text-center"
      };

    let _lineHeight =
      switch (leading) {
      | `None => "leading-none"
      | `Tight => "leading-tight"
      | `Snug => "leading-snug"
      | `Normal => "leading-normal"
      | `Relaxed => "leading-relaxed"
      | `Loose => "leading-loose"
      };

    let _fontFamily =
      switch (fontFamily) {
      | `Sans => "font-sans"
      | `Mono => "font-mono"
      };

    <span> children </span>;
  };
};

type kinds = [ | `H1 | `H2 | `H3 | `H4 | `H5 | `Body | `Label];

[@react.component]
let make =
    (
      ~color=`Mono500,
      ~align=`Left,
      ~inline=false,
      ~uppercase=false,
      ~truncate=false,
      ~children,
      ~kind=`Body,
      ~fontFamily=?,
      ~tracking=?,
    ) => {
  let (size, weight, leading) =
    switch (kind) {
    | `H1 => (`XLarge, `Semibold, `Normal)
    | `H2 => (`Large, `Semibold, `Normal)
    | `H3 => (`Medium, `Semibold, `Normal)
    | `H4 => (`Small, `Semibold, `Normal)
    | `H5 => (`Small, `Normal, `Normal)
    | `Body => (`Medium, `Normal, `Normal)
    | `Label => (`Small, `Medium, `Loose)
    };

  <Typography
    size
    weight
    align
    inline
    color
    truncate
    uppercase
    leading
    ?fontFamily
    ?tracking>
    {React.string(children)}
  </Typography>;
};
