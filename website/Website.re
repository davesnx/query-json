module App = {
  [@react.component]
  let make = () => {
    <p>{"Hello world"->React.string}</p>
  }
};

React.Dom.renderToElementWithId(<App />, "root");
