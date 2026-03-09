let run query input =
  match Json.parse_string input with
  | Ok json ->
      Core.run ~debug:false ~colorize:false ~verbose:false ~raw:false
        ~summarize:false query json
  | Error err ->
      Error err

let arity_to_js (arity : Language.arity) =
  match arity with
  | No_args ->
      Js_of_ocaml.Js.Unsafe.obj
        [|
          ( "type",
            Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string "no_args")
          );
        |]
  | One_arg desc ->
      Js_of_ocaml.Js.Unsafe.obj
        [|
          ( "type",
            Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string "one_arg")
          );
          ("arg1", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string desc));
        |]
  | Two_args (d1, d2) ->
      Js_of_ocaml.Js.Unsafe.obj
        [|
          ( "type",
            Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string "two_args")
          );
          ("arg1", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string d1));
          ("arg2", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string d2));
        |]
  | Three_args (d1, d2, d3) ->
      Js_of_ocaml.Js.Unsafe.obj
        [|
          ( "type",
            Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string "three_args")
          );
          ("arg1", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string d1));
          ("arg2", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string d2));
          ("arg3", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string d3));
        |]
  | Variable_args desc ->
      Js_of_ocaml.Js.Unsafe.obj
        [|
          ( "type",
            Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string "variable_args")
          );
          ("arg1", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string desc));
        |]

let applicable_to_js (a : Language.applicable_to) =
  let str =
    match a with
    | String ->
        "string"
    | Array ->
        "array"
    | Object ->
        "object"
    | Number ->
        "number"
    | Bool ->
        "boolean"
    | Nil ->
        "null"
    | Any ->
        "any"
  in
  Js_of_ocaml.Js.string str

let function_info_to_js (f : Language.function_info) =
  let example =
    match f.example with
    | Some e ->
        Js_of_ocaml.Js.Optdef.return (Js_of_ocaml.Js.string e)
    | None ->
        Js_of_ocaml.Js.Optdef.empty
  in
  Js_of_ocaml.Js.Unsafe.obj
    [|
      ("name", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string f.name));
      ( "aliases",
        Js_of_ocaml.Js.Unsafe.inject
          (Js_of_ocaml.Js.array
             (Array.of_list (List.map Js_of_ocaml.Js.string f.aliases))
          )
      );
      ( "description",
        Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string f.description)
      );
      ("example", Js_of_ocaml.Js.Unsafe.inject example);
      ( "applicableTo",
        Js_of_ocaml.Js.Unsafe.inject
          (Js_of_ocaml.Js.array
             (Array.of_list (List.map applicable_to_js f.applicable_to))
          )
      );
      ("arity", Js_of_ocaml.Js.Unsafe.inject (arity_to_js f.arity));
    |]

let category_to_js (c : Language.category) =
  Js_of_ocaml.Js.Unsafe.obj
    [|
      ("name", Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string c.name));
      ( "description",
        Js_of_ocaml.Js.Unsafe.inject (Js_of_ocaml.Js.string c.description)
      );
      ( "functions",
        Js_of_ocaml.Js.Unsafe.inject
          (Js_of_ocaml.Js.array
             (Array.of_list (List.map function_info_to_js c.functions))
          )
      );
    |]

let get_categories () =
  Js_of_ocaml.Js.array
    (Array.of_list (List.map category_to_js Language.all_categories))

let () =
  Js_of_ocaml.Js.export "query-json"
    object%js
      val run = Js_of_ocaml.Js.wrap_callback run
      val categories = Js_of_ocaml.Js.wrap_callback get_categories
    end
