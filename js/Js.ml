let run query input =
  match Json.parse_string input with
  | Ok json ->
      Core.run ~debug:false ~colorize:false ~verbose:false ~raw:false
        ~summarize:false query json
  | Error e -> Error e

let () =
  Js_of_ocaml.Js.export "query-json"
    (object%js
       val run = Js_of_ocaml.Js.wrap_callback run
    end)
