[@bs.val] external document: Js.t({..}) = "document";
let container = document##createElement("div");
let () = document##body##appendChild(container);

ReactDOMRe.render(<App />, container);
