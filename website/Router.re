open Js_of_ocaml;
let getHash = () =>
  try(Some(Url.Current.get_fragment() |> Url.urldecode)) {
  | _ => None
  };

let setHash = (hash): unit => {
  Url.Current.set_fragment(hash |> Url.urlencode(~with_plus=true));
};
