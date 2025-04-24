let remove_hash hash =
  Js.String.substring ~start:1 ~end_:(Js.String.length hash) hash

let get_hash () =
  let window = Webapi.Dom.window in
  let location = Webapi.Dom.Window.location window in
  match Webapi.Dom.Location.hash location with
  | "" -> None
  | hash -> Some (remove_hash hash)
  | exception _ -> None

let set_hash hash =
  let window = Webapi.Dom.window in
  let location = Webapi.Dom.Window.location window in
  Webapi.Dom.Location.setHash location hash
