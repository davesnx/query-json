let remove_hash hash =
  Js.String.substring ~start:1 ~end_:(Js.String.length hash) hash

let get_hash () =
  let location = Web.Window.location Web.window in
  match Web.Location.hash location with
  | "" -> None
  | hash -> Some (remove_hash hash)
  | exception _ -> None

let set_hash hash =
  let location = Web.Window.location Web.window in
  Web.Location.setHash location hash
