let element = Webapi.Dom.Document.querySelector("#root", Webapi.Dom.document);

switch (element) {
| Some(el) =>
  let root = ReactDOM.Client.createRoot(el);
  let _ = ReactDOM.Client.render(root, <App />);
  ();
| None => Js.log("No root element found")
};
