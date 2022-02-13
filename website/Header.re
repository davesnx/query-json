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
      display(`inlineFlex),
      alignItems(`center),
      selector("&:hover", [|opacity(0.6)|]),
    |])
  );

let button_ =
  Emotion.(
    make([|
      unsafe("border", "none"),
      padding2(~v=px(8), ~h=px(12)),
      color(hex("FAFAFA")),
      backgroundColor(rgb(43, 75, 175)),
      cursor(`pointer),
      selector(
        "&:hover",
        [|backgroundColor(rgba(43, 75, 175, `percent(80.)))|],
      ),
    |])
  );

[@react.component]
let make = (~onShareClick) => {
  <Spacer direction=Bottom value=4>
    <div className=menu>
      <div className=wrapper>
        <div className=distribute>
          <Text color=`White kind=`H2> {"query-json playground" |> React.string} </Text>
        </div>
        <div className=distribute>
          <a
            className=link
            href="https://twitter.com/davesnx"
            target="_blank"
            rel="noopener">
            <Icons.Twitter />
          </a>
          <Spacer direction=Left value=2>
            <a
              className=link
              href="https://github.com/davesnx/query-json"
              target="_blank"
              rel="noopener">
              <Icons.Github />
            </a>
          </Spacer>
          <Spacer direction=Left value=2>
            <button className=button_ onClick=onShareClick>
              <Text> {"Share unique URL" |> React.string} </Text>
            </button>
          </Spacer>
        </div>
      </div>
    </div>
  </Spacer>;
};
