let run query input =
  match Json.parse_string input with
  | Ok json -> Core.run query json
  | Error e -> Error e

let () =
  Js_of_ocaml.Js.export "query-json"
    (object%js
       val run = Js_of_ocaml.Js.wrap_callback run
    end)
