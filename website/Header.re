open React.Dom.Dsl;
open Html;
open Jsoo_css;

let menu =
  Emotion.(
    make([|
      width(vw(100.)),
      padding2(~h=`zero, ~v=`px(20)),
      background(rgb(32, 33, 37)),
    |])
  );

let wrapper =
  Emotion.(
    make([|
      width(vw(75.)),
      height(`percent(100.)),
      margin2(~v=`px(0), ~h=`auto),
      display(`flex),
      justifyContent(`spaceBetween),
      alignItems(`center),
    |])
  );

let distribute =
  Emotion.(
    make([|display(`flex), flexDirection(`row), alignItems(`center)|])
  );

let link =
  Emotion.(
    make([|
      textDecoration(`none),
      color(hex("FAFAFA")),
      cursor(`pointer),
      transition("opacity", ~duration=200, ~timingFunction=`easeInOut),
      selector("&:hover", [|opacity(0.6)|]),
    |])
  );

let iconlink =
  Emotion.(
    make([|
      width(px(26)),
      height(px(26)),
      textDecoration(`none),
      color(hex("FAFAFA")),
      cursor(`pointer),
      display(`inlineFlex),
      alignItems(`center),
      transition("opacity", ~duration=200, ~timingFunction=`easeInOut),
      selector("&:hover", [|opacity(0.6)|]),
    |])
  );

let button_ =
  Emotion.(
    make([|
      unsafe("border", "none"),
      borderRadius(px(6)),
      padding2(~v=px(8), ~h=px(12)),
      color(hex("FAFAFA")),
      backgroundColor(rgb(43, 75, 175)),
      cursor(`pointer),
      transition(
        "background-color",
        ~duration=200,
        ~timingFunction=`easeInOut,
      ),
      selector(
        "&:hover",
        [|backgroundColor(rgba(43, 75, 175, `percent(80.)))|],
      ),
    |])
  );

[@react.component]
let make = (~onShareClick) => {
  <div className=menu>
    <div className=wrapper>
      <div className=distribute>
        <a
          className=link
          href="https://query-json.netlify.app"
          target="_blank"
          rel="noopener">
          <Text color=`White kind=`H2>
            {"query-json playground" |> React.string}
          </Text>
        </a>
      </div>
      <div className=distribute>
        <Text color=`Grey kind=`Label> {"Made by" |> React.string} </Text>
        <Spacer direction=Left value=1 />
        <a
          className=iconlink
          href="https://twitter.com/davesnx"
          target="_blank"
          rel="noopener">
          <Icons.Twitter />
        </a>
        <Spacer direction=Left value=4 />
        <Text color=`Grey kind=`Label> {"Code in" |> React.string} </Text>
        <Spacer direction=Left value=1 />
        <a
          className=iconlink
          href="https://github.com/davesnx/query-json"
          target="_blank"
          rel="noopener">
          <Icons.Github />
        </a>
        <Spacer direction=Left value=4>
          <button className=button_ onClick=onShareClick>
            <Text kind=`H4> {"Generate unique URL" |> React.string} </Text>
          </button>
        </Spacer>
      </div>
    </div>
  </div>;
};
