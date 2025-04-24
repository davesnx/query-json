let run = Core.run

let () =
  Js_of_ocaml.Js.export "query-json"
    (object%js
       val run = Js_of_ocaml.Js.wrap_callback run
    end)
