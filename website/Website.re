open React.Dom.Dsl;
open Html;
open Jsoo_css;

module App = {
  [@react.component]
  let make = () => {
    let style =
      Inline.(
        style([|padding2(~v=`px(10), ~h=`px(5)), color(Colors.grey)|])
      );
    <p style> {"Hello world" |> React.string} </p>;
  };
};

React.Dom.renderToElementWithId(<App />, "root");
