let rec representation : Json.t -> string = function
  | `Null ->
      "Null"
  | `Bool b ->
      Printf.sprintf "Bool(%b)" b
  | `String s ->
      Printf.sprintf "String(%S)" s
  | `Int n ->
      Printf.sprintf "Int(%d)" n
  | `Int64 n ->
      Printf.sprintf "Int64(%Ld)" n
  | `Big_int n ->
      "Big_int(" ^ Z.to_string n ^ ")"
  | `Float n ->
      Printf.sprintf "Float(bits=%Lx)" (Int64.bits_of_float n)
  | `Decimal d ->
      Printf.sprintf "Decimal(%s,%d)" (Z.to_string d.coeff) d.scale
  | `List items ->
      "List[" ^ String.concat ";" (List.map representation items) ^ "]"
  | `Assoc fields ->
      "Assoc["
      ^ String.concat ";"
          (List.map
             (fun (k, v) -> Printf.sprintf "%S:%s" k (representation v))
             fields
          )
      ^ "]"

let result_representation : Interpreter.execute_result -> string = function
  | Ok values ->
      "Ok[" ^ String.concat ";" (List.map representation values) ^ "]"
  | Error error ->
      "Error(" ^ error ^ ")"
  | Halt code ->
      Printf.sprintf "Halt(%d)" code

let check_result label expected actual =
  Alcotest.check Alcotest.string label
    (result_representation expected)
    (result_representation actual)

let check_backend expected plan =
  let name = function
    | Execution.For_test.Compiled ->
        "Compiled"
    | Interpreted ->
        "Interpreted"
  in
  Alcotest.check Alcotest.string "backend" (name expected)
    (name (Execution.For_test.backend plan))

let parse query =
  match Core.parse ~debug:false ~colorize:false query with
  | Ok expr ->
      expr
  | Error error ->
      Alcotest.failf "Cannot parse %S: %s" query error

let fold_collect ~colorize ~verbose ?env plan input : Interpreter.execute_result
    =
  match
    Execution.fold ~colorize ~verbose ?env ~init:[]
      ~f:(fun acc value -> value :: acc)
      plan input
  with
  | Completed values ->
      Ok (List.rev values)
  | Failed error ->
      Error error
  | Halted code ->
      Halt code

let interpreter_fold_collect ~colorize ~verbose ?env expr input :
    Interpreter.execute_result =
  match
    Interpreter.fold ~colorize ~verbose ?env ~init:[]
      ~f:(fun acc value -> value :: acc)
      expr input
  with
  | Completed values ->
      Ok (List.rev values)
  | Failed error ->
      Error error
  | Halted code ->
      Halt code

let differential ?expected ?env backend expr inputs =
  let plan = Execution.prepare expr in
  check_backend backend plan;
  List.iter
    (fun (colorize, verbose) ->
      List.iter
        (fun input ->
          let reference =
            Interpreter.execute ~colorize ~verbose ?env expr input
          in
          let actual = Execution.execute ~colorize ~verbose ?env plan input in
          check_result
            (Ast.show_expression expr ^ " on " ^ representation input)
            reference actual;
          check_result "fold collection" reference
            (fold_collect ~colorize ~verbose ?env plan input);
          check_result "interpreter fold collection" reference
            (interpreter_fold_collect ~colorize ~verbose ?env expr input);
          Option.iter
            (fun expected -> check_result "specified result" expected actual)
            expected;
          check_backend backend plan
        )
        (inputs @ inputs)
    )
    [ (false, false); (true, false); (false, true); (true, true) ]

let compiled ?expected name query inputs =
  Alcotest.test_case name `Quick (fun () ->
      differential ?expected Execution.For_test.Compiled (parse query) inputs
  )

let interpreted ?expected name query inputs =
  Alcotest.test_case name `Quick (fun () ->
      differential ?expected Execution.For_test.Interpreted (parse query) inputs
  )

let obj fields : Json.t = `Assoc fields
let ints values : Json.t = `List (List.map (fun n -> `Int n) values)
let empty_obj = obj []

type expected_stream_cut = Expected_root | Expected_member of string

let check_no_stream_cut backend query =
  let plan = Execution.prepare (parse query) in
  check_backend backend plan;
  match Execution.For_test.stream_cut plan with
  | None ->
      ()
  | Some _ ->
      Alcotest.failf "%S unexpectedly has a stream cut" query

let stream_cut_analysis () =
  let eligible =
    [
      (".[]", Expected_root, ".", [ `Null; `Int 1; empty_obj ]);
      ( ".[] | .value",
        Expected_root,
        ".value",
        [ obj [ ("value", `Int 1) ]; empty_obj ]
      );
      ( ".[] | select(.active) | .value",
        Expected_root,
        "select(.active) | .value",
        [
          obj [ ("active", `Bool true); ("value", `Int 1) ];
          obj [ ("active", `Bool false); ("value", `Int 2) ];
        ]
      );
      (".rows[]", Expected_member "rows", ".", [ `Int 1; empty_obj ]);
      ( ".rows[] | .value",
        Expected_member "rows",
        ".value",
        [ obj [ ("value", `Int 1) ]; empty_obj ]
      );
      ( ".[\"line-items\"][] | .id",
        Expected_member "line-items",
        ".id",
        [ obj [ ("id", `Int 1) ] ]
      );
      ( ".rows[] | select(.active) | [.value, .other]",
        Expected_member "rows",
        "select(.active) | [.value, .other]",
        [
          obj [ ("active", `Bool true); ("value", `Int 1); ("other", `Int 2) ];
          obj [ ("active", `Bool false) ];
        ]
      );
      ( ".rows[] | map(.id)",
        Expected_member "rows",
        "map(.id)",
        [ `List [ obj [ ("id", `Int 1) ]; obj [ ("id", `Int 2) ] ] ]
      );
      ( ".[] | (., .value)",
        Expected_root,
        "., .value",
        [ obj [ ("value", `Int 1) ] ]
      );
    ]
  in
  List.iter
    (fun (query, expected_cut, residual_query, inputs) ->
      let plan = Execution.prepare (parse query) in
      check_backend Execution.For_test.Compiled plan;
      let residual =
        match (expected_cut, Execution.For_test.stream_cut plan) with
        | Expected_root, Some (Root_items residual) ->
            residual
        | Expected_member expected, Some (Member_items (actual, residual)) ->
            Alcotest.check Alcotest.string "stream member" expected actual;
            residual
        | Expected_root, _ ->
            Alcotest.failf "%S does not have the expected root cut" query
        | Expected_member member, _ ->
            Alcotest.failf "%S does not have the expected %S member cut" query
              member
      in
      check_backend Execution.For_test.Compiled residual;
      let expected_residual = Execution.prepare (parse residual_query) in
      check_backend Execution.For_test.Compiled expected_residual;
      List.iter
        (fun input ->
          check_result
            (query ^ " residual on " ^ representation input)
            (Execution.execute ~colorize:false ~verbose:false expected_residual
               input
            )
            (Execution.execute ~colorize:false ~verbose:false residual input)
        )
        inputs
    )
    eligible;
  List.iter
    (check_no_stream_cut Execution.For_test.Compiled)
    [
      ".";
      "null";
      ".rows";
      ".[0]";
      ".[0, 1]";
      "empty";
      "select(.)";
      ". + 1";
      "[]";
      "[.[]]";
      "map(.) | .[]";
      ".rows | map(.id) | .[]";
      ".a.b[]";
      ". | .[]";
      ".[0] | .[]";
      ".[], .[]";
      ".rows[], .rows[]";
      ".rows | (., .[])";
    ];
  List.iter
    (check_no_stream_cut Execution.For_test.Interpreted)
    [
      ".[] | .value?";
      ".rows[] | length";
      "fn selected: .rows[] | .value; selected";
      ".[]?";
    ]

let numeric_matrix () =
  let decimal s : Json.t = `Decimal (Json.Decimal.of_lexeme_exn s) in
  let left =
    [
      `Int 7;
      `Int Int.max_int;
      `Int64 Int64.max_int;
      `Big_int (Z.of_string "922337203685477580812345");
      decimal "0.1";
      decimal "-3.25";
      `Float 0.1;
      `Float (-0.0);
    ]
  in
  let right =
    [
      `Int 3;
      `Int64 3L;
      `Big_int (Z.of_int 3);
      decimal "3.0";
      decimal "0.2";
      `Float 3.0;
      `Int 0;
      `Int64 0L;
      `Big_int Z.zero;
      decimal "0.0";
      `Float 0.0;
    ]
  in
  let inputs =
    List.concat_map
      (fun l -> List.map (fun r -> obj [ ("l", l); ("r", r) ]) right)
      left
  in
  List.iter
    (fun op ->
      differential Execution.For_test.Compiled
        Ast.(Operation (Key "l", op, Key "r"))
        inputs
    )
    Ast.
      [
        Add;
        Subtract;
        Multiply;
        Divide;
        Modulo;
        Equal;
        Not_equal;
        Greater_than;
        Greater_than_or_equal;
        Less_than;
        Less_than_or_equal;
        And;
        Or;
      ]

let unsupported_structure () =
  let open Ast in
  let number = Literal (Number (Integer "1")) in
  let unsupported =
    [
      Optional Identity;
      Variable "x";
      Env_var "HOME";
      Fn0 Now;
      Fn0 Debug;
      Fn0 Stderr;
      Fn0 Halt;
      Fn0 Length;
      Fn1 (With_expr (Map_values, Identity));
      Fn2 (Limit, number, Identity);
      Fn ("f", [], Identity);
      Apply ("f", []);
      As (Identity, Pat_var "x", Variable "x");
      If_then_else (Identity, number, Identity);
      Try (Identity, Some number, None);
      Update (Identity, number);
      Assign (Key "x", number);
      Alternative (Identity, number);
      Reduce (Index [], Pat_var "x", number, Identity);
      Foreach (Index [], Pat_var "x", number, Identity, Identity);
      Dynamic_access number;
      Slice (Some 0, Some 1);
      Slice_expr (Some number, None);
      Object [];
      Object [ (Literal (String "x"), Some Identity) ];
      Range (number, None, None);
      Fma (number, number, number);
      Operation (Comma (number, number), Add, number);
      Operation (number, Add, Fn0 Empty);
      Operation (Fn1 (With_expr (Select, Identity)), Add, number);
    ]
  in
  List.iter
    (fun expr ->
      List.iter
        (fun wrapped ->
          check_backend Execution.For_test.Interpreted
            (Execution.prepare wrapped)
        )
        [
          expr;
          Pipe (Identity, expr);
          Pipe (expr, Identity);
          Pipe (Fn0 Empty, expr);
          Comma (number, expr);
          Comma (expr, number);
          List (Some expr);
          Fn1 (With_expr (Map, expr));
          Fn1 (With_expr (Select, expr));
          Operation (number, Add, expr);
        ]
    )
    unsupported

let literal_timing () =
  let open Ast in
  List.iter
    (fun bad ->
      let literal = Literal (Number bad) in
      differential Execution.For_test.Compiled literal [ `Null ];
      differential ~expected:(Interpreter.Ok []) Execution.For_test.Compiled
        (Pipe (Fn0 Empty, literal))
        [ `Null ];
      differential
        ~expected:(Interpreter.Ok [ `List [] ])
        Execution.For_test.Compiled
        (Fn1 (With_expr (Map, literal)))
        [ `List [] ];
      differential Execution.For_test.Compiled
        (Comma (Key "missing", literal))
        [ empty_obj ];
      differential Execution.For_test.Compiled
        (Operation (Key "missing", Add, literal))
        [ empty_obj ];
      differential Execution.For_test.Interpreted
        (Pipe (Fn0 Empty, Optional literal))
        [ `Null ];
      differential Execution.For_test.Interpreted
        (Comma (Identity, Optional literal))
        [ `Null ]
    )
    [
      Integer "not-an-integer";
      Decimal "not-a-decimal";
      Decimal "1e999999999999999999999";
    ]

let environment_reuse () =
  let expr = parse "., $x" in
  let plan = Execution.prepare expr in
  check_backend Execution.For_test.Interpreted plan;
  List.iter
    (fun env ->
      check_result "per-call environment"
        (Interpreter.execute ~colorize:false ~verbose:false ~env expr `Null)
        (Execution.execute ~colorize:false ~verbose:false ~env plan `Null);
      check_result "per-call fold environment"
        (Interpreter.execute ~colorize:false ~verbose:false ~env expr `Null)
        (fold_collect ~colorize:false ~verbose:false ~env plan `Null);
      differential ~env Execution.For_test.Interpreted expr [ `Null ];
      differential ~env Execution.For_test.Compiled (parse ".") [ `Null ]
    )
    [ [ ("x", `Int 1) ]; []; [ ("x", `String "next") ]; [] ]

let stream_compositions () =
  let open Ast in
  let atoms =
    [
      Identity;
      Key "x";
      Index [];
      Index [ -1 ];
      Index [ 0; -1; 0 ];
      Fn0 Empty;
      Literal Null;
      Literal (Bool false);
      List None;
      Fn1 (With_expr (Select, Identity));
    ]
  in
  let inputs =
    [
      `Null;
      `Int 1;
      empty_obj;
      obj [ ("x", `Int 2); ("a", `Bool false) ];
      ints [];
      ints [ 0; 1; 2 ];
      `List [ ints []; ints [ 1; 2 ] ];
      `List [ obj [ ("x", `Int 3) ]; empty_obj ];
    ]
  in
  List.iter
    (fun left ->
      List.iter
        (fun right ->
          List.iter
            (fun expr -> differential Execution.For_test.Compiled expr inputs)
            [
              Pipe (left, right);
              Comma (left, right);
              List (Some (Pipe (left, right)));
              Fn1 (With_expr (Map, Comma (left, right)));
              Pipe (left, Fn1 (With_expr (Select, right)));
            ]
        )
        atoms
    )
    atoms

let long_filtered_stream () =
  let expr = parse ".[] | select(false, false) | .missing" in
  differential ~expected:(Interpreter.Ok []) Execution.For_test.Compiled expr
    [ `List (List.init 20000 (fun n -> `Int n)) ]

let fold_late_error () =
  List.iter
    (fun (backend, query) ->
      let expr = parse query in
      let plan = Execution.prepare expr in
      check_backend backend plan;
      let seen = ref [] in
      let result =
        Execution.fold ~colorize:false ~verbose:false ~init:()
          ~f:(fun () value -> seen := value :: !seen)
          plan empty_obj
      in
      check_result "values before failure"
        (Ok [ `Int 1; `Int 2 ])
        (Ok (List.rev !seen));
      match result with
      | Failed error ->
          check_result "late error"
            (Interpreter.execute ~colorize:false ~verbose:false expr empty_obj)
            (Error error)
      | _ ->
          Alcotest.fail "expected fold failure"
    )
    [
      (Execution.For_test.Compiled, "1, 2, .missing, 3");
      (Execution.For_test.Compiled, "1, 2, 1 % 0, 3");
      (Execution.For_test.Interpreted, "1, 2, .missing, length");
      (Execution.For_test.Interpreted, "1, 2, 1 % 0, length");
      (Execution.For_test.Interpreted, "1, 2, error(\"stop\"), 3");
      (Execution.For_test.Interpreted, "1, 2, break, 3");
    ]

let check_callback_exception ?(at = 1) call =
  let exception Callback_error of int ref in
  let expected = Callback_error (ref 42) in
  let calls = ref 0 in
  let original_backtrace = ref "" in
  let recording = Printexc.backtrace_status () in
  Printexc.record_backtrace true;
  Fun.protect
    ~finally:(fun () -> Printexc.record_backtrace recording)
    (fun () ->
      let callback _ =
        incr calls;
        if !calls = at then (
          try raise expected
          with exn ->
            let backtrace = Printexc.get_raw_backtrace () in
            original_backtrace := Printexc.raw_backtrace_to_string backtrace;
            Printexc.raise_with_backtrace exn backtrace
        )
      in
      match call callback with
      | _ ->
          Alcotest.fail "callback exception did not escape"
      | exception actual ->
          let backtrace = Printexc.get_backtrace () in
          Alcotest.check Alcotest.bool "same exception instance" true
            (actual == expected);
          Alcotest.check Alcotest.int "stops at failing callback" at !calls;
          Alcotest.check Alcotest.bool "callback backtrace recorded" true
            (!original_backtrace <> "");
          Alcotest.check Alcotest.bool "callback backtrace preserved" true
            (String.starts_with ~prefix:!original_backtrace backtrace)
    )

let fold_callback_exception () =
  List.iter
    (fun (backend, query) ->
      let expr = parse query in
      let plan = Execution.prepare expr in
      check_backend backend plan;
      List.iter
        (fun at ->
          check_callback_exception ~at (fun callback ->
              Execution.fold ~colorize:false ~verbose:false ~init:()
                ~f:(fun () value -> callback value)
                plan `Null
          );
          check_callback_exception ~at (fun callback ->
              Interpreter.fold ~colorize:false ~verbose:false ~init:()
                ~f:(fun () value -> callback value)
                expr `Null
          )
        )
        [ 1; 2 ];
      check_result "reuse after callback exception"
        (Interpreter.execute ~colorize:false ~verbose:false expr `Null)
        (fold_collect ~colorize:false ~verbose:false plan `Null)
    )
    [
      (Execution.For_test.Compiled, "1, 2");
      (Execution.For_test.Interpreted, "range(1; 3)");
      (Execution.For_test.Interpreted, "try (1, 2, error(\"query\")) catch 3");
      (Execution.For_test.Interpreted, "(1, 2, .missing)?");
      (Execution.For_test.Interpreted, "1, 2, halt");
    ]

let fold_halt () =
  List.iter
    (fun (query, code) ->
      let expr = parse query in
      differential ~expected:(Halt code) Execution.For_test.Interpreted expr
        [ `Null ];
      let seen = ref [] in
      let result =
        Execution.fold ~colorize:false ~verbose:false ~init:()
          ~f:(fun () value -> seen := value :: !seen)
          (Execution.prepare expr) `Null
      in
      check_result "values before halt"
        (Ok [ `Int 1; `Int 2 ])
        (Ok (List.rev !seen));
      match result with
      | Halted actual ->
          Alcotest.check Alcotest.int "halt code" code actual
      | _ ->
          Alcotest.fail "expected halted fold"
    )
    [ ("1, 2, halt, 3", 0); ("1, 2, halt_error(7), 3", 7) ]

let fold_long_stream () =
  let count = 100000 in
  let input = `List (List.init count (fun n -> `Int n)) in
  List.iter
    (fun (backend, query) ->
      let plan = Execution.prepare (parse query) in
      check_backend backend plan;
      match
        Execution.fold ~colorize:false ~verbose:false ~init:0
          ~f:(fun index value ->
            if value <> `Int index then Alcotest.fail "output order changed";
            index + 1
          )
          plan input
      with
      | Completed actual ->
          Alcotest.check Alcotest.int "output count" count actual
      | _ ->
          Alcotest.fail "expected completed fold"
    )
    [
      (Execution.For_test.Compiled, ".[]");
      (Execution.For_test.Interpreted, ".[]?");
    ]

let core_output () =
  List.iter
    (fun (query, input) ->
      let expr = parse query in
      List.iter
        (fun colorize ->
          List.iter
            (fun (raw, summarize) ->
              let expected =
                match
                  Interpreter.execute ~colorize ~verbose:false expr input
                with
                | Ok values ->
                    Ok
                      (String.concat "\n"
                         (List.map
                            (Json.to_string_pretty ~colorize ~summarize ~raw)
                            values
                         )
                      )
                | Error error ->
                    Error error
                | Halt _ ->
                    Alcotest.fail "unexpected halt"
              in
              Alcotest.check
                (Alcotest.result Alcotest.string Alcotest.string)
                query expected
                (Core.run ~colorize ~raw ~summarize query input);
              let output = Buffer.create 32 in
              let first = ref true in
              let seen = ref [] in
              let emit value =
                if !first then
                  first := false
                else
                  Buffer.add_char output '\n';
                Buffer.add_string output value;
                seen := value :: !seen
              in
              let actual =
                Core.run_iter ~colorize ~raw ~summarize ~emit query input
              in
              Alcotest.check
                (Alcotest.result Alcotest.string Alcotest.string)
                (query ^ " run_iter") expected
                (Result.map (fun () -> Buffer.contents output) actual);
              match Interpreter.execute ~colorize ~verbose:false expr input with
              | Ok values ->
                  Alcotest.check
                    (Alcotest.list Alcotest.string)
                    "one emit per result, without separators"
                    (List.map
                       (Json.to_string_pretty ~colorize ~summarize ~raw)
                       values
                    )
                    (List.rev !seen)
              | Error _ ->
                  ()
              | Halt _ ->
                  Alcotest.fail "unexpected halt"
            )
            [ (false, false); (true, false); (false, true); (true, true) ]
        )
        [ false; true ]
    )
    [
      (".[]", `List [ `String "first"; obj [ ("z", `Int 1); ("a", `Int 2) ] ]);
      (".[] | .x", `List [ obj [ ("x", `Int 1) ]; empty_obj ]);
      ("empty", `Null);
      ("map(. + 0.1)", ints [ 1; 2 ]);
      (".missing?", empty_obj);
      (".[]", `List [ `String ""; `String ""; `String "last"; `String "" ]);
      (".[]?", `List [ `String ""; `String "last"; `String "" ]);
    ]

let core_iter_errors () =
  List.iter
    (fun (query, expected_seen) ->
      let seen = ref [] in
      let actual =
        Core.run_iter ~colorize:false ~verbose:true
          ~emit:(fun value -> seen := value :: !seen)
          query empty_obj
      in
      Alcotest.check
        (Alcotest.list Alcotest.string)
        "emits before error" expected_seen (List.rev !seen);
      match actual with
      | Error error ->
          Alcotest.check
            (Alcotest.result Alcotest.string Alcotest.string)
            "same error as run"
            (Core.run ~colorize:false ~verbose:true query empty_obj)
            (Error error)
      | Ok () ->
          Alcotest.fail "expected run_iter error"
    )
    [
      ("1, .missing, 2", [ "1" ]);
      ("1, error(\"stop\")", [ "1" ]);
      ("1, .missing, length", [ "1" ]);
      ("1, 1 % 0, length", [ "1" ]);
      ("1, break, 2", [ "1" ]);
      ("[", []);
    ];
  List.iter
    (fun query ->
      check_callback_exception (fun emit ->
          Core.run_iter ~colorize:false ~emit query `Null
      )
    )
    [ "1, .missing"; "range(1; 3)"; "1, error(\"stop\")" ]

let parse_input text =
  match Json.parse_string text with
  | Ok input ->
      input
  | Error error ->
      Alcotest.failf "Cannot parse input %S: %s" text error

let load_input plan source =
  match Execution.load plan source with
  | Ok loaded ->
      loaded
  | Error error ->
      Alcotest.failf "Cannot load input: %s" error

let observe_fold call =
  let seen = ref [] in
  let result : Interpreter.execute_result =
    match
      call (fun acc value ->
          seen := value :: !seen;
          value :: acc
      )
    with
    | Execution.Completed values ->
        Ok (List.rev values)
    | Failed error ->
        Error error
    | Halted code ->
        Halt code
  in
  (result, List.rev !seen)

let check_fold label (expected, expected_seen) (actual, actual_seen) =
  check_result (label ^ " terminal") expected actual;
  check_result (label ^ " callback order") (Ok expected_seen) (Ok actual_seen)

let loaded_shapes =
  List.map
    (fun query -> (Execution.For_test.Compiled, query))
    [
      ".a";
      ".a.b";
      ".a | 1";
      ".a | empty";
      ".a | .[] | .b";
      ".a | (., .b)";
      ".a | .b | .c | .d";
      ".";
      ".[0]";
      ".a, .b";
      "[.a]";
      ".a + 1";
      ".[]";
    ]
  @ [ (Execution.For_test.Interpreted, ".a?") ]

let loaded_plan_matrix () =
  let inputs =
    [
      ("selected first", {|{"a":{"b":{"c":{"d":0.10}}},"z":[1,2]}|});
      ("selected middle", {|{"z":[1,2],"a":{"b":{"c":{"d":0.10}}},"b":9}|});
      ("selected last", {|{"z":[1,2],"a":{"b":{"c":{"d":0.10}}}}|});
      ("missing key", {|{"a-near":1,"b":2,"z":[3]}|});
      ("first duplicate wins", {|{"a":1,"a":{"b":2},"b":3}|});
      ("selected null", {|{"a":null,"a":2,"b":3}|});
      ("scalar root", "42");
      ("array root", {|[{"a":1},{"b":2}]|});
      ( "ordered selected stream",
        {|{"a":[{"b":0.10},{"b":9223372036854775807},{"b":9223372036854775808}],"z":0}|}
      );
      ( "selected late error",
        {|{"a":[{"b":"first"},{"other":2},{"b":"unreached"}],"z":0}|}
      );
      ("selected nested error", {|{"a":{"b":{"c":false}},"z":0}|});
    ]
  in
  List.iter
    (fun (backend, query) ->
      let plan = Execution.prepare (parse query) in
      check_backend backend plan;
      List.iter
        (fun (name, text) ->
          let input = parse_input text in
          let loaded = load_input plan (Json.Input.String text) in
          List.iter
            (fun (colorize, verbose) ->
              let label = query ^ " / " ^ name in
              let expected = Execution.execute ~colorize ~verbose plan input in
              let expected_fold =
                observe_fold (fun f ->
                    Execution.fold ~colorize ~verbose ~init:[] ~f plan input
                )
              in
              check_result (label ^ " full fold") expected (fst expected_fold);
              for _ = 1 to 2 do
                check_result
                  (label ^ " loaded execution")
                  expected
                  (Execution.execute_loaded ~colorize ~verbose loaded);
                check_fold label expected_fold
                  (observe_fold (fun f ->
                       Execution.fold_loaded ~colorize ~verbose ~init:[] ~f
                         loaded
                   )
                  )
              done
            )
            [ (false, false); (true, true) ]
        )
        inputs
    )
    loaded_shapes

let malformed_source_inputs =
  [ {|{"a":[{"b":1}],"discarded":"\q"}|}; {|{"a":[{"b":1}],"discarded":[2|} ]

let input_error text =
  match Json.parse_string text with
  | Error error ->
      error
  | Ok _ ->
      Alcotest.failf "Malformed input was accepted: %S" text

let loaded_plan_invalid_tail () =
  List.iter
    (fun text ->
      let expected = input_error text in
      List.iter
        (fun (_, query) ->
          Alcotest.check
            (Alcotest.result Alcotest.unit Alcotest.string)
            (query ^ " validates discarded tail")
            (Error expected)
            (Result.map
               (fun _ -> ())
               (Execution.load
                  (Execution.prepare (parse query))
                  (Json.Input.String text)
               )
            )
        )
        loaded_shapes
    )
    malformed_source_inputs

let loaded_callback_reuse () =
  List.iter
    (fun (query, text) ->
      let plan = Execution.prepare (parse query) in
      let input = parse_input text in
      let expected =
        Execution.execute ~colorize:false ~verbose:false plan input
      in
      List.iter
        (fun source ->
          let loaded = load_input plan source in
          List.iter
            (fun at ->
              check_callback_exception ~at (fun callback ->
                  Execution.fold_loaded ~colorize:false ~verbose:false ~init:()
                    ~f:(fun () value -> callback value)
                    loaded
              );
              check_result "loaded execute after callback exception" expected
                (Execution.execute_loaded ~colorize:false ~verbose:false loaded);
              check_fold "loaded fold after callback exception"
                (observe_fold (fun f ->
                     Execution.fold ~colorize:false ~verbose:false ~init:[] ~f
                       plan input
                 )
                )
                (observe_fold (fun f ->
                     Execution.fold_loaded ~colorize:false ~verbose:false
                       ~init:[] ~f loaded
                 )
                )
            )
            [ 1; 2 ]
        )
        [ Json.Input.String text; Json.Input.Value input ]
    )
    [
      (".a | .[] | .b", {|{"a":[{"b":1},{"b":2}]}|});
      (".a | (., .b)", {|{"a":{"b":2}}|});
      (".a? | .[] | .b", {|{"a":[{"b":1},{"b":2}]}|});
    ]

let observe_iter call =
  let seen = ref [] in
  let result = call (fun value -> seen := value :: !seen) in
  (result, List.rev !seen)

let check_iter label (expected, expected_seen) (actual, actual_seen) =
  Alcotest.check
    (Alcotest.result Alcotest.unit Alcotest.string)
    (label ^ " terminal") expected actual;
  Alcotest.check
    (Alcotest.list Alcotest.string)
    (label ^ " emitted prefix")
    expected_seen actual_seen

let core_source_calls () =
  List.iter
    (fun (query, text, error_prefix) ->
      let input = parse_input text in
      List.iter
        (fun colorize ->
          List.iter
            (fun (raw, summarize) ->
              let expected =
                Core.run ~colorize ~verbose:true ~raw ~summarize query input
              in
              let expected_iter =
                observe_iter (fun emit ->
                    Core.run_iter ~colorize ~verbose:true ~raw ~summarize ~emit
                      query input
                )
              in
              ( match (error_prefix, expected) with
              | None, Error error ->
                  Alcotest.failf "%s: expected success, got %s" query error
              | Some _, Ok _ ->
                  Alcotest.fail "expected a Core error"
              | _ ->
                  ()
              );
              Option.iter
                (fun prefix ->
                  check_iter
                    (query ^ " reference late error")
                    ( Result.map (fun _ -> ()) expected,
                      List.map
                        (Json.to_string_pretty ~colorize ~raw ~summarize)
                        prefix
                    )
                    expected_iter
                )
                error_prefix;
              List.iter
                (fun source ->
                  Alcotest.check
                    (Alcotest.result Alcotest.string Alcotest.string)
                    (query ^ " Core source output")
                    expected
                    (Core.run_input ~colorize ~verbose:true ~raw ~summarize
                       query source
                    );
                  check_iter
                    (query ^ " Core source iteration")
                    expected_iter
                    (observe_iter (fun emit ->
                         Core.run_input_iter ~colorize ~verbose:true ~raw
                           ~summarize ~emit query source
                     )
                    )
                )
                [ Core.String text; Core.Value input ]
            )
            [ (false, false); (true, false); (false, true); (true, true) ]
        )
        [ false; true ]
    )
    [
      ( ".a | .[]",
        {|{"a":["","a long string with more than twenty characters",{"z":1,"b":2},[1,2]],"z":0}|},
        None
      );
      (".", {|{"a":1,"a":2,"b":[3,4]}|}, None);
      (".a | empty", {|{"a":null,"z":0}|}, None);
      (".a?", {|{"other":1}|}, None);
      ( ".a | .[] | .b",
        {|{"a":[{"b":"first"},{"other":2},{"b":"unreached"}],"z":0}|},
        Some [ `String "first" ]
      );
      (".a | (., .b)", {|{"a":42,"z":0}|}, Some [ `Int 42 ]);
      (".a, .missing", {|{"a":"first","z":0}|}, Some [ `String "first" ]);
      ( "fn selected: .a[]; selected | .b",
        {|{"a":[{"b":"first"},{"other":2}]}|},
        Some [ `String "first" ]
      );
      (".a", {|{"a-near":1,"z":0}|}, Some []);
      ("[", {|{"a":1}|}, Some []);
    ]

let core_source_error_precedence () =
  List.iter
    (fun colorize ->
      let query_error =
        match Core.parse ~debug:false ~colorize "[" with
        | Error error ->
            error
        | Ok _ ->
            Alcotest.fail "expected an invalid query"
      in
      Alcotest.check
        (Alcotest.result Alcotest.string Alcotest.string)
        "valid JSON exposes query error" (Error query_error)
        (Core.run_input ~colorize "[" (Core.String {|{"a":1}|}));
      List.iter
        (fun text ->
          let expected = input_error text in
          Alcotest.check Alcotest.bool "distinct JSON and query errors" true
            (expected <> query_error);
          List.iter
            (fun query ->
              Alcotest.check
                (Alcotest.result Alcotest.string Alcotest.string)
                (query ^ " JSON error wins")
                (Error expected)
                (Core.run_input ~colorize query (Core.String text));
              check_iter
                (query ^ " validates before emitting")
                (Error expected, [])
                (observe_iter (fun emit ->
                     Core.run_input_iter ~colorize ~emit query (Core.String text)
                 )
                )
            )
            [ ".a"; ".a | empty"; ".a | .[] | .b"; ".a?"; "[" ]
        )
        malformed_source_inputs
    )
    [ false; true ]

let observe_source ?(colorize = false) ?(verbose = false) ?env plan source =
  observe_fold (fun f ->
      Execution.fold_source ~colorize ~verbose ?env ~init:[] ~f plan source
  )

(* Reimplements the validate-first path fold_source takes for plans without a
   stream cut, so tests can pin the atomic ground truth for comparison. *)
let observe_validated ?(colorize = false) ?(verbose = false) ?env plan source =
  observe_fold (fun f ->
      match Execution.load plan source with
      | Ok loaded ->
          Execution.fold_loaded ~colorize ~verbose ?env ~init:[] ~f loaded
      | Error error ->
          Execution.Failed error
  )

let source_plan_matrix () =
  let inputs =
    [
      "[]";
      "{}";
      "null";
      "false";
      "42";
      {|"scalar"|};
      "[0.10,9223372036854775807,9223372036854775808]";
      {|[{"id":1,"next":2},{"id":3,"next":4}]|};
      {|{"z":{"id":1},"a":{"id":2},"z":{"id":3}}|};
      {|[{"id":1},{},{"id":3}]|};
      {|[[{"id":1},{"id":2}],[{"id":3}]]|};
      {|[[{"id":1}],[{"id":2},{}],[{"id":3}]]|};
    ]
  in
  List.iter
    (fun suffix ->
      List.iter
        (fun head ->
          let query = head ^ suffix in
          let plan = Execution.prepare (parse query) in
          check_backend Execution.For_test.Compiled plan;
          Alcotest.check Alcotest.bool "eligible source plan" true
            (Option.is_some (Execution.For_test.stream_cut plan));
          let texts =
            if head = ".[]" then
              inputs
            else
              List.concat_map
                (fun text ->
                  [
                    {|{"rows":|} ^ text ^ {|,"rows":[99],"tail":0}|};
                    {|{"before":[1,2],"rows":|} ^ text ^ "}";
                  ]
                )
                inputs
              @ [ "null"; "42"; "[]"; "{}"; {|{"rows-near":1,"tail":2}|} ]
          in
          List.iter
            (fun text ->
              let input = parse_input text in
              List.iter
                (fun (colorize, verbose) ->
                  let expected =
                    observe_fold (fun f ->
                        Execution.fold_loaded ~colorize ~verbose ~init:[] ~f
                          (load_input plan (Json.Input.String text))
                    )
                  in
                  List.iter
                    (fun source ->
                      check_fold
                        (query ^ " on " ^ text)
                        expected
                        (observe_source ~colorize ~verbose plan source)
                    )
                    [ Json.Input.String text; Json.Input.Value input ]
                )
                [ (false, false); (true, true) ]
            )
            texts
        )
        [ ".[]"; ".rows[]" ]
    )
    [
      "";
      " | empty";
      " | .id";
      " | select(.id > 1) | .id";
      " | [.id, .next]";
      " | map(.id)";
      " | (., .id, .next)";
      " | .[] | (.id, .id + 10)";
    ]

let source_error_drain () =
  List.iter
    (fun (query, valid, malformed, expected_seen) ->
      let plan = Execution.prepare (parse query) in
      let expected = observe_validated plan (Json.Input.String valid) in
      ( match fst expected with
      | Error _ ->
          ()
      | _ ->
          Alcotest.fail "expected query error"
      );
      check_result "validated error prefix" (Ok expected_seen)
        (Ok (snd expected));
      check_fold "saved query error after valid tail" expected
        (observe_source plan (Json.Input.String valid));
      List.iter
        (fun text ->
          check_fold "later input error wins"
            (Error (input_error text), expected_seen)
            (observe_source plan (Json.Input.String text));
          check_fold "reuse after input error" expected
            (observe_source plan (Json.Input.Value (parse_input valid)))
        )
        malformed
    )
    [
      ( ".[] | (.id, .next)",
        {|[{"id":1},{"id":2,"next":3}]|},
        [ {|[{"id":1},{"id":2,"next":3},|}; {|[{"id":1},"\q"]|} ],
        [ `Int 1 ]
      );
      ( ".rows[] | .id",
        {|{"rows":[{"id":1},{},{"id":3}],"tail":[4]}|},
        [
          {|{"rows":[{"id":1},{},{"id":3}],"tail":[4|};
          {|{"rows":[{"id":1},{},{"id":3}],"rows":"\q"}|};
          {|{"rows":[{"id":1},{},"\q"]}|};
        ],
        [ `Int 1 ]
      );
      (".[] | 1 % 0", "[1,2,3]", [ "[1,2,"; "[1,2,3] trailing" ], []);
    ]

let source_invalid_tail () =
  List.iter
    (fun (query, text, prefix) ->
      let plan = Execution.prepare (parse query) in
      check_fold "successful items before malformed tail"
        (Error (input_error text), prefix)
        (observe_source plan (Json.Input.String text));
      check_fold "validating first never exposes an invalid input prefix"
        (Error (input_error text), [])
        (observe_validated plan (Json.Input.String text))
    )
    [
      (".[]", "[1,2,", [ `Int 1; `Int 2 ]);
      (".[]", "[1,2x]", [ `Int 1 ]);
      (".[]", {|{"a":1,"a":2,"b":"\q"}|}, [ `Int 1; `Int 2 ]);
      (".[] | (., . + 10)", "[1,2,", [ `Int 1; `Int 11; `Int 2; `Int 12 ]);
      (".rows[] | .id", {|{"rows":[{"id":1},{"id":2}x]}|}, [ `Int 1 ]);
      (".rows[]", {|{"rows":[1,2],"tail":"\q"}|}, [ `Int 1; `Int 2 ]);
      (".rows[]", {|{"rows":[1],"rows":[2,}|}, [ `Int 1 ]);
      (".rows[]", {|{"rows":[],"tail":"\q"}|}, []);
    ]

let source_validation_barriers () =
  List.iter
    (fun (query, valid, malformed) ->
      let plan = Execution.prepare (parse query) in
      Alcotest.check Alcotest.bool "no stream cut" true
        (Option.is_none (Execution.For_test.stream_cut plan));
      check_fold "barrier validates before callbacks"
        (Error (input_error malformed), [])
        (observe_source plan (Json.Input.String malformed));
      let expected = observe_validated plan (Json.Input.String valid) in
      List.iter
        (fun source ->
          check_fold "barrier valid input" expected (observe_source plan source)
        )
        [ Json.Input.String valid; Json.Input.Value (parse_input valid) ]
    )
    [
      ("[.[]]", "[1,2]", "[1,2,");
      ( ".rows | map(.id) | .[]",
        {|{"rows":[{"id":1}]}|},
        {|{"rows":[{"id":1}],"tail":"\q"}|}
      );
      (".[]?", "[1,2]", "[1,2,");
      ("fn items: .[]; items", "[1,2]", "[1,2,");
    ];
  let plan = Execution.prepare (parse ".[], $x, halt_error(7)") in
  check_fold "fallback environment and halt"
    (Halt 7, [ `Int 1; `Int 2; `Int 3 ])
    (observe_source ~env:[ ("x", `Int 3) ] plan (Json.Input.String "[1,2]"));
  check_fold "invalid input precedes fallback halt"
    (Error (input_error "[1,2,"), [])
    (observe_source ~env:[ ("x", `Int 3) ] plan (Json.Input.String "[1,2,"))

let source_callback_reuse () =
  List.iter
    (fun (query, text) ->
      let plan = Execution.prepare (parse query) in
      let expected = observe_validated plan (Json.Input.String text) in
      List.iter
        (fun source ->
          List.iter
            (fun at ->
              check_callback_exception ~at (fun callback ->
                  Execution.fold_source ~colorize:false ~verbose:false ~init:()
                    ~f:(fun () value -> callback value)
                    plan source
              );
              check_fold "source reuse after callback exception" expected
                (observe_source plan source)
            )
            [ 1; 2 ]
        )
        [ Json.Input.String text; Json.Input.Value (parse_input text) ];
      let file = Filename.temp_file "execution-source-" ".json" in
      Fun.protect
        ~finally:(fun () -> Sys.remove file)
        (fun () ->
          let channel = open_out file in
          Fun.protect
            ~finally:(fun () -> close_out_noerr channel)
            (fun () -> output_string channel text);
          check_callback_exception (fun callback ->
              Execution.fold_source ~colorize:false ~verbose:false ~init:()
                ~f:(fun () value -> callback value)
                plan (Json.Input.File file)
          );
          check_fold "source file after callback exception" expected
            (observe_source plan (Json.Input.File file))
        )
    )
    [
      (".[] | (., . + 10)", "[1,2]");
      (".rows[] | .id", {|{"rows":[{"id":1},{"id":2}]}|});
      (".[]?", "[1,2]");
    ];
  let plan = Execution.prepare (parse ".[] | .id") in
  List.iter
    (fun text ->
      ignore (observe_source plan (Json.Input.String text));
      check_fold "prepared plan recovers from failure"
        (Ok [ `Int 9 ], [ `Int 9 ])
        (observe_source plan (Json.Input.String {|[{"id":9}]|}))
    )
    [ {|[{"id":1},{},{"id":3}]|}; {|[{"id":1},|} ];
  check_callback_exception (fun callback ->
      Execution.fold_source ~colorize:false ~verbose:false ~init:()
        ~f:(fun () value -> callback value)
        plan (Json.Input.String {|[{"id":1},|})
  )

let core_streaming () =
  List.iter
    (fun (query, text, prefix) ->
      let expected_error = input_error text in
      check_iter "Core run_input_iter permits prefixes"
        (Error expected_error, prefix)
        (observe_iter (fun emit ->
             Core.run_input_iter ~colorize:false ~emit query (Core.String text)
         )
        );
      check_iter "Core debug forces validation first" (Error expected_error, [])
        (observe_iter (fun emit ->
             Core.run_input_iter ~debug:true ~colorize:false ~emit query
               (Core.String text)
         )
        )
    )
    [
      (".[]", "[1,2,", [ "1"; "2" ]);
      (".rows[] | .id", {|{"rows":[{"id":1},{},|}, [ "1" ]);
      ("[.[]]", "[1,2,", []);
      (".rows | map(.id) | .[]", {|{"rows":[{"id":1}],"tail":[|}, []);
      (".[]?", "[1,2,", []);
      ("fn items: .[]; items", "[1,2,", []);
      ("[", "[1,2,", []);
    ];
  List.iter
    (fun (query, text) ->
      let input = parse_input text in
      let expected =
        observe_iter (fun emit ->
            Core.run_iter ~colorize:false ~raw:true ~summarize:true ~emit query
              input
        )
      in
      List.iter
        (fun source ->
          check_iter "Core run_input_iter valid input" expected
            (observe_iter (fun emit ->
                 Core.run_input_iter ~colorize:false ~raw:true ~summarize:true
                   ~emit query source
             )
            )
        )
        [ Core.String text; Core.Value input ]
    )
    [
      (".[]", {|["","long string with more than twenty characters",3]|});
      (".rows[] | .id", {|{"rows":[{"id":1},{},{"id":3}]}|});
      (".rows[]", {|{"rows":42}|});
      ("[", "[1,2]");
    ];
  List.iter
    (fun (query, text) ->
      check_callback_exception (fun emit ->
          Core.run_input_iter ~colorize:false ~emit query (Core.String text)
      )
    )
    [ (".[]", "[1,2,"); (".rows[] | .id", {|{"rows":[{"id":1},|}) ]

let tests =
  [
    compiled "identity preserves representation" "."
      [
        `Null;
        `Int64 1L;
        `Big_int Z.one;
        `Float 1.0;
        obj [ ("z", `Int 1); ("a", `Int 2); ("z", `Int 3) ];
      ];
    compiled "all literals"
      "true, false, null, \"text\", 1, -2, 0.10, 1e3, 9223372036854775807, \
       9223372036854775808"
      [ `Null ];
    compiled
      ~expected:(Ok [ `Int 4 ])
      "nested paths" ".a.b[0].c"
      [ obj [ ("a", obj [ ("b", `List [ obj [ ("c", `Int 4) ] ]) ]) ] ];
    compiled
      ~expected:(Ok [ `Int 1 ])
      "first duplicate key" ".x"
      [ obj [ ("x", `Int 1); ("x", `Int 2) ] ];
    compiled
      ~expected:(Ok [ `Int 2; `Int 1; `Int 3 ])
      "object iteration order" ".[]"
      [ obj [ ("z", `Int 2); ("a", `Int 1); ("z", `Int 3) ] ];
    compiled
      ~expected:(Ok [ `Int 3; `Int 1; `Int 3; `Int 1 ])
      "negative and duplicate indices" ".[2, 0, -1, 0]"
      [ ints [ 1; 2; 3 ] ];
    compiled
      ~expected:(Ok [ `Int 3 ])
      "scalar negative index" ".[-1]"
      [ ints [ 1; 2; 3 ] ];
    compiled ~expected:(Ok []) "empty iteration" ".[]" [ ints []; empty_obj ];
    compiled
      ~expected:(Ok [ `Int 1; `Int 2; `Int 3; `Int 4 ])
      "depth-first pipe" ".[] | .[]"
      [ `List [ ints [ 1; 2 ]; ints [ 3; 4 ] ] ];
    compiled
      ~expected:(Ok [ `Int 1; `Int 11; `Int 2; `Int 12 ])
      "pipe into comma" ".[] | (., . + 10)"
      [ ints [ 1; 2 ] ];
    compiled
      ~expected:(Ok [ `Int 1; `Int 2; `Int 1; `Int 2 ])
      "comma restarts input" ".[], .[]"
      [ ints [ 1; 2 ] ];
    compiled
      ~expected:(Ok [ `List [ `Int 1; `Int 2; `Int 9 ] ])
      "list collection" "[.[], empty, 9]"
      [ ints [ 1; 2 ] ];
    compiled ~expected:(Ok [ `List [] ]) "empty list" "[]" [ `Null ];
    compiled
      ~expected:(Ok [ `List [] ])
      "empty collected list" "[empty]" [ `Null ];
    compiled ~expected:(Ok []) "empty does not run right pipe"
      "empty | .missing" [ `Null ];
    compiled ~expected:(Ok [ `Int 4 ]) "comma after empty" "empty, 4" [ `Null ];
    compiled
      ~expected:(Ok [ `List [ `Int 2; `Int 1; `Int 4; `Int 3 ] ])
      "map flattens each child stream" "map(. + 1, .)"
      [ ints [ 1; 3 ] ];
    compiled
      ~expected:(Ok [ `List [] ])
      "map empty" "map(empty)"
      [ ints [ 1; 2 ] ];
    compiled
      ~expected:(Ok [ `List [] ])
      "map empty input skips child" "map(.missing)"
      [ ints [] ];
    compiled
      ~expected:(Ok [ `List [ `List [ `Int 1; `Int 2 ]; `List [ `Int 3 ] ] ])
      "nested map and list" "map([.[]])"
      [ `List [ ints [ 1; 2 ]; ints [ 3 ] ] ];
    compiled
      ~expected:(Ok [ `Int 2; `Int 3 ])
      "select scalar" ".[] | select(. > 1)"
      [ ints [ 1; 2; 3 ] ];
    compiled
      ~expected:(Ok [ `Int 7; `Int 7; `Int 7; `Int 7 ])
      "select yields for every truthy result"
      "select(false, null, true, 0, \"\", [])"
      [ `Int 7 ];
    compiled ~expected:(Ok []) "select empty" "select(empty)" [ `Null ];
    compiled
      ~expected:(Ok [ `List [ `Int 2; `Int 3 ] ])
      "map select" "map(select(. > 1))"
      [ ints [ 1; 2; 3 ] ];
    compiled "exact scalar arithmetic"
      "0.1 + 0.2, 1 / 8, 1 / 3, 9223372036854775807 + 1, 1.20 * 3, 1e3 - 0.5"
      [ `Null ];
    compiled "operations on collected scalars" "[.[]] + map(. * 2)"
      [ ints [ 1; 2 ] ];
    compiled "boolean operations evaluate both sides" "false and .missing"
      [ empty_obj ];
    compiled "or evaluates both sides" "true or .missing" [ empty_obj ];
    compiled "left operand fails first" ".left + .right" [ empty_obj ];
    compiled "division and modulo errors" "1 / 0" [ `Null ];
    compiled "modulo exception" "1 % 0" [ `Null ];
    compiled "string operations" "\"ab\" * 3, \"a,b\" / \",\", \"a\" + \"b\""
      [ `Null ];
    compiled "list operators" ".l + .r, .l - .r"
      [ obj [ ("l", ints [ 2; 1; 2 ]); ("r", ints [ 2; 3 ]) ] ];
    compiled "object operator order" ".l + .r, .l * .r"
      [
        obj
          [
            ("l", obj [ ("z", obj [ ("x", `Int 1) ]); ("a", `Int 2) ]);
            ("r", obj [ ("z", obj [ ("y", `Int 3) ]); ("b", `Int 4) ]);
          ];
      ];
    compiled "missing key after yield and recovery" ".[] | .x"
      [
        `List [ obj [ ("x", `Int 1) ] ];
        `List [ obj [ ("x", `Int 1) ]; empty_obj ];
        `List [ obj [ ("x", `Int 9) ] ];
      ];
    compiled "index error after yield and recovery" ".[0, 2]"
      [ ints [ 1; 2; 3 ]; ints [ 1 ]; ints [ 9; 8; 7 ] ];
    compiled "negative index out of range" ".[-4]" [ ints [ 1; 2 ] ];
    compiled "list discards earlier yields" "[1, .missing]" [ empty_obj ];
    compiled "map discards prior items" "map(.x)"
      [
        `List [ obj [ ("x", `Int 1) ]; empty_obj ];
        ints [];
        `List [ obj [ ("x", `Int 2) ] ];
      ];
    compiled "select late error" "select(true, .missing)" [ empty_obj ];
    compiled "depth-first error precedence" "(.a, .missing) | (.x, .y)"
      [ obj [ ("a", obj [ ("x", `Int 1) ]) ] ];
    compiled "comma does not open later iterator early" ".missing, .[]"
      [ `Null ];
    compiled "downstream errors precede later source errors"
      "(1, .missing) | .[]" [ empty_obj ];
    compiled "input errors and suggestions" ".foo"
      [
        `Null;
        `Int 1;
        ints [];
        obj [ ("foo-bar", `Int 2) ];
        obj [ ("foo", `Int 9) ];
      ];
    compiled "iteration type errors" ".[]"
      [ `Null; `Bool false; `String "abc"; `Int 1 ];
    compiled "index type errors" ".[0]" [ `Null; empty_obj; `String "abc" ];
    compiled "map type errors" "map(.)" [ empty_obj; `Null; `String "abc" ];
    compiled "operator errors" ". + true, . < \"a\""
      [ `Null; `Int 1; empty_obj; ints [] ];
    interpreted
      ~expected:(Ok [ `Int 11; `Int 21; `Int 12; `Int 22 ])
      "left-major stream operation fallback" "(1, 2) + (10, 20)" [ `Null ];
    interpreted "optional access fallback" ".x?"
      [ empty_obj; obj [ ("x", `Int 1) ] ];
    interpreted "mixed pipe fallback" ".[] | .x?"
      [ `List [ empty_obj; obj [ ("x", `Int 2) ] ] ];
    interpreted "map child fallback" "map(.x?)" [ `List [ empty_obj ] ];
    interpreted "select child fallback" "select(.x?)" [ empty_obj ];
    interpreted "functions fallback" "fn double: . * 2; double" [ `Int 3 ];
    interpreted "binding fallback" ". as $x | $x + 1" [ `Int 3 ];
    interpreted "control fallback" "if . then 1 else 2 end"
      [ `Bool false; `Bool true ];
    interpreted "update fallback" ".x |= . + 1" [ obj [ ("x", `Int 1) ] ];
    interpreted "reduce fallback" "reduce .[] as $x (0; . + $x)"
      [ ints [ 1; 2 ] ];
    interpreted "foreach fallback" "[foreach .[] as $x (0; . + $x; .)]"
      [ ints [ 1; 2 ] ];
    interpreted "slice fallback" ".[0:2]" [ ints [ 1; 2; 3 ] ];
    interpreted "dynamic access fallback" ".k as $key | .[$key]"
      [ obj [ ("k", `String "x"); ("x", `Int 2) ] ];
    interpreted "constructor fallback" "{x: .}" [ `Int 1 ];
    interpreted "caught runtime error fallback" "try .x catch ." [ empty_obj ];
    interpreted "halt remains a result" "halt" [ `Null ];
    interpreted "user error fallback discards earlier yields"
      "1, error(\"stop\")" [ `Null ];
    interpreted
      ~expected:(Ok [ `List [ `Int64 1L; `Int64 2L ]; `List [ `Int 3 ] ])
      "fold only sees top-level collections" "[range(1; 3)], [3]" [ `Null ];
    interpreted ~expected:(Ok []) "fallback empty fold" "empty?" [ `Null ];
    interpreted
      ~expected:(Ok [ `Int 1; `String "stop"; `Int 2 ])
      "caught user error preserves yield order"
      "try (1, error(\"stop\")) catch (., 2)" [ `Null ];
    Alcotest.test_case "stream cut analysis" `Quick stream_cut_analysis;
    Alcotest.test_case "numeric constructor matrix" `Quick numeric_matrix;
    Alcotest.test_case "whole-tree structural fallback" `Quick
      unsupported_structure;
    Alcotest.test_case "numeric conversion timing" `Quick literal_timing;
    Alcotest.test_case "fallback environment reuse" `Quick environment_reuse;
    Alcotest.test_case "stream composition matrix" `Quick stream_compositions;
    Alcotest.test_case "long filtered stream" `Quick long_filtered_stream;
    Alcotest.test_case "fold late error preserves callbacks" `Quick
      fold_late_error;
    Alcotest.test_case "fold callback exceptions escape" `Quick
      fold_callback_exception;
    Alcotest.test_case "fold halt preserves callbacks" `Quick fold_halt;
    Alcotest.test_case "fold long output stream" `Quick fold_long_stream;
    Alcotest.test_case "Core output flags" `Quick core_output;
    Alcotest.test_case "Core run_iter errors and callbacks" `Quick
      core_iter_errors;
    Alcotest.test_case "loaded plan source matrix" `Quick loaded_plan_matrix;
    Alcotest.test_case "loaded plans validate discarded tails" `Quick
      loaded_plan_invalid_tail;
    Alcotest.test_case "loaded input reuse after callback exceptions" `Quick
      loaded_callback_reuse;
    Alcotest.test_case "Core source output and late errors" `Quick
      core_source_calls;
    Alcotest.test_case "Core source JSON error precedence" `Quick
      core_source_error_precedence;
    Alcotest.test_case "source streaming plan matrix" `Quick source_plan_matrix;
    Alcotest.test_case "source query errors drain input" `Quick
      source_error_drain;
    Alcotest.test_case "source invalid tails preserve valid prefixes" `Quick
      source_invalid_tail;
    Alcotest.test_case "source barriers validate first" `Quick
      source_validation_barriers;
    Alcotest.test_case "source callback exceptions and plan reuse" `Quick
      source_callback_reuse;
    Alcotest.test_case "Core run_input_iter streaming and debug policy" `Quick
      core_streaming;
  ]
