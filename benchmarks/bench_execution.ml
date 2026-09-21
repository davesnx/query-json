type workload = {
  name : string;
  query : string;
  payload : string;
  backend : Execution.backend;
  iterations : int;
  expected : Json.t list;
}

type 'a prepared = {
  workload : workload;
  reference : 'a;
  execution : unit -> 'a;
  interpreter : unit -> 'a;
}

type measurement = { ns : float; bytes : float }

let rows = 128

let array_payload =
  "["
  ^ String.concat ","
      (List.init rows (fun i ->
           Printf.sprintf {|{"id":%d,"score":%d,"active":%b}|} i (i mod 100)
             (i mod 2 = 0)
       )
      )
  ^ "]"

let deep_payload =
  {|{"root":{"groups":[{},
    {"members":[{"profile":{"stats":{"scores":[
      {"value":3},{"value":7},{"value":42}
    ]}}}]}]}}|}

let workloads =
  [
    {
      name = "deep_scalar_chain";
      query = ".root.groups[1].members[0].profile.stats.scores[2].value";
      payload = deep_payload;
      backend = Execution.Compiled;
      iterations = 100_000;
      expected = [ `Int 42 ];
    };
    {
      name = "scalar_predicate";
      query = ".price * .quantity + .fee > .limit and .active";
      payload = {|{"price":17,"quantity":4,"fee":3,"limit":60,"active":true}|};
      backend = Execution.Compiled;
      iterations = 50_000;
      expected = [ `Bool true ];
    };
    {
      name = "iterator_select_field";
      query = ".[] | select(.active and .score >= 50) | .id";
      payload = array_payload;
      backend = Execution.Compiled;
      iterations = 2_000;
      expected = List.init 25 (fun i -> `Int (50 + (2 * i)));
    };
    {
      name = "map_transform";
      query = "map(.score * 2 + .id)";
      payload = array_payload;
      backend = Execution.Compiled;
      iterations = 2_000;
      expected =
        [ `List (List.init rows (fun i -> `Int ((i mod 100 * 2) + i))) ];
    };
    {
      name = "fallback_length";
      query = ".root.groups | length";
      payload = deep_payload;
      backend = Execution.Interpreted;
      iterations = 100_000;
      expected = [ `Int64 2L ];
    };
  ]

let backend_name = function
  | Execution.Compiled ->
      "compiled"
  | Execution.Interpreted ->
      "fallback"

let rec describe_json : Json.t -> string = function
  | `Int n ->
      Printf.sprintf "Int(%d)" n
  | `Int64 n ->
      Printf.sprintf "Int64(%Ld)" n
  | `List values ->
      "[" ^ String.concat "; " (List.map describe_json values) ^ "]"
  | value ->
      Json.to_string value

let describe_result : Interpreter.execute_result -> string = function
  | Ok values ->
      "Ok " ^ describe_json (`List values)
  | Error message ->
      "Error " ^ message
  | Halt code ->
      Printf.sprintf "Halt %d" code

let check_result name expected actual =
  (* Structural equality preserves result order and numeric constructors. These
     fixtures use finite integers and booleans, so NaN equality is not needed. *)
  if actual <> expected then
    failwith
      (Printf.sprintf "%s: result mismatch\nexpected: %s\nactual:   %s" name
         (describe_result expected) (describe_result actual)
      )

let render results =
  results
  |> List.map (Json.to_string_pretty ~colorize:false ~summarize:false ~raw:false)
  |> String.concat "\n"

let one_shot_candidate query json =
  Core.run ~debug:false ~colorize:false ~verbose:false ~raw:false
    ~summarize:false query json

(* Keep this path aligned with Core.run before it started preparing plans. *)
let former_core_run ?(debug = false) ?(colorize = true) ?(verbose = false)
    ?(raw = false) ?(summarize = false) query json =
  match Core.parse ~debug ~colorize query with
  | Error error ->
      Error error
  | Ok expr -> (
      match Interpreter.execute ~colorize ~verbose expr json with
      | Ok results ->
          Ok
            (results
            |> List.map (Json.to_string_pretty ~colorize ~summarize ~raw)
            |> String.concat "\n"
            )
      | Error error ->
          Error error
      | Halt code ->
          exit code
    )

let one_shot_reference query json =
  former_core_run ~debug:false ~colorize:false ~verbose:false ~raw:false
    ~summarize:false query json

let check_string_result name expected actual =
  let describe = function
    | Ok output ->
        Printf.sprintf "Ok %S" output
    | Error error ->
        Printf.sprintf "Error %S" error
  in
  if actual <> expected then
    failwith
      (Printf.sprintf "%s: one-shot result mismatch\nexpected: %s\nactual:   %s"
         name (describe expected) (describe actual)
      )

let check_one_shot_errors () =
  List.iter
    (fun (name, query, json) ->
      let reference = one_shot_reference query json in
      ( match reference with
      | Error _ ->
          ()
      | Ok _ ->
          failwith (name ^ ": expected an error")
      );
      check_string_result name reference (one_shot_candidate query json)
    )
    [ ("parse error", "[", `Null); ("runtime error", ".missing", `Assoc []) ]

let prepare workload =
  let expr =
    match Core.parse ~debug:false ~colorize:false workload.query with
    | Ok expr ->
        expr
    | Error message ->
        failwith (workload.name ^ ": query parse error: " ^ message)
  in
  let json =
    match Json.parse_string workload.payload with
    | Ok json ->
        json
    | Error message ->
        failwith (workload.name ^ ": JSON parse error: " ^ message)
  in
  let plan = Execution.prepare expr in
  let actual_backend = Execution.backend plan in
  if actual_backend <> workload.backend then
    failwith
      (Printf.sprintf "%s: expected %s backend, got %s" workload.name
         (backend_name workload.backend)
         (backend_name actual_backend)
      );
  let execution () =
    Execution.execute ~colorize:false ~verbose:false plan json
  in
  let interpreter () =
    Interpreter.execute ~colorize:false ~verbose:false expr json
  in
  let reference = interpreter () in
  check_result
    (workload.name ^ " fixture")
    (Interpreter.Ok workload.expected) reference;
  check_result workload.name reference (execution ());
  let prepared = { workload; reference; execution; interpreter } in
  let execution () = one_shot_candidate workload.query json in
  let interpreter () = one_shot_reference workload.query json in
  let reference = interpreter () in
  check_string_result
    (workload.name ^ " fixture")
    (Ok (render workload.expected))
    reference;
  check_string_result workload.name reference (execution ());
  let one_shot =
    {
      workload = { workload with iterations = min 5_000 workload.iterations };
      reference;
      execution;
      interpreter;
    }
  in
  (prepared, one_shot)

let repeat sink iterations run =
  let run = Sys.opaque_identity run in
  for _ = 1 to iterations do
    sink := Sys.opaque_identity (run ())
  done

let measure ~check ~empty sink iterations run =
  sink := empty;
  Gc.full_major ();
  let before = Gc.allocated_bytes () in
  let start = Unix.gettimeofday () in
  repeat sink iterations run;
  let elapsed = Unix.gettimeofday () -. start in
  let allocated = Gc.allocated_bytes () -. before in
  check !sink;
  if elapsed <= 0.0 then
    failwith
      "Non-positive elapsed time. Increase --iterations or check the clock.";
  let count = Float.of_int iterations in
  { ns = elapsed *. 1e9 /. count; bytes = allocated /. count }

let median values =
  let sorted = Array.of_list values in
  Array.sort Float.compare sorted;
  let n = Array.length sorted in
  if n mod 2 = 0 then
    (sorted.((n / 2) - 1) +. sorted.(n / 2)) /. 2.0
  else
    sorted.(n / 2)

let summarize results =
  {
    ns = median (List.map (fun r -> r.ns) results);
    bytes = median (List.map (fun r -> r.bytes) results);
  }

let parse_args () =
  let iterations = ref None in
  let warmup = ref 1_000 in
  let samples = ref 5 in
  let positive flag set n =
    if n <= 0 then raise (Arg.Bad (flag ^ " requires a positive integer"));
    set n
  in
  Arg.parse
    [
      ( "--iterations",
        Arg.Int (positive "--iterations" (fun n -> iterations := Some n)),
        "N Override operations per sample (sink/input capped at 100; \
         first-result unaffected)"
      );
      ( "--warmup",
        Arg.Int (positive "--warmup" (fun n -> warmup := n)),
        "N Warmup operations per path (default 1000; sink/input capped at 10; \
         first-result at 3)"
      );
      ( "--samples",
        Arg.Int (positive "--samples" (fun n -> samples := n)),
        "N Paired samples per workload (default 5)"
      );
    ]
    (fun arg -> raise (Arg.Bad ("Unexpected argument: " ^ arg)))
    "bench_execution [--iterations N] [--warmup N] [--samples N]";
  (!iterations, !warmup, !samples)

let bench ~check ~empty ~iterations ~warmup ~samples prepared =
  let iterations =
    Option.value iterations ~default:prepared.workload.iterations
  in
  let sink = ref empty in
  repeat sink warmup prepared.execution;
  check prepared.workload.name prepared.reference !sink;
  repeat sink warmup prepared.interpreter;
  check prepared.workload.name prepared.reference !sink;
  let execution = ref [] in
  let interpreter = ref [] in
  let sample run results =
    results :=
      measure
        ~check:(check prepared.workload.name prepared.reference)
        ~empty sink iterations run
      :: !results
  in
  for i = 1 to samples do
    if i mod 2 = 1 then begin
      sample prepared.execution execution;
      sample prepared.interpreter interpreter
    end else begin
      sample prepared.interpreter interpreter;
      sample prepared.execution execution
    end
  done;
  let execution = summarize !execution in
  let interpreter = summarize !interpreter in
  Printf.printf
    "%-23s %-8s %8d %12.1f %12.1f %10.1f %10.1f %+9.1f%% %+9.1f%%\n%!"
    prepared.workload.name
    (backend_name prepared.workload.backend)
    iterations execution.ns interpreter.ns execution.bytes interpreter.bytes
    (((execution.ns /. interpreter.ns) -. 1.0) *. 100.0)
    (((execution.bytes /. interpreter.bytes) -. 1.0) *. 100.0)

let bench_sink ~iterations ~warmup ~samples =
  let rows = 16_384 in
  let iterations = min 100 (Option.value iterations ~default:100) in
  let warmup = min 10 warmup in
  let values = List.init rows (fun i -> `Int (i + 1)) in
  let input = `List values in
  let expr =
    match Core.parse ~debug:false ~colorize:false ".[]" with
    | Ok expr ->
        expr
    | Error message ->
        failwith message
  in
  let plan = Execution.prepare expr in
  if Execution.backend plan <> Execution.Compiled then
    failwith "large_stream_sink: expected compiled backend";
  let collect () =
    Execution.execute ~colorize:false ~verbose:false plan input
  in
  let fold () =
    Execution.fold ~colorize:false ~verbose:false ~init:0
      ~f:(fun sum -> function
        | `Int n ->
            sum + n
        | _ ->
            failwith "large_stream_sink: expected integer"
        )
      plan input
  in
  let check_list = check_result "large_stream_sink" (Interpreter.Ok values) in
  let check_fold = function
    | Execution.Completed sum when sum = rows * (rows + 1) / 2 ->
        ()
    | Execution.Completed sum ->
        failwith (Printf.sprintf "large_stream_sink: unexpected checksum %d" sum)
    | Execution.Failed message ->
        failwith ("large_stream_sink: " ^ message)
    | Execution.Halted code ->
        failwith (Printf.sprintf "large_stream_sink: unexpected halt %d" code)
  in
  check_list (collect ());
  check_fold (fold ());
  let list_sink = ref (Interpreter.Ok []) in
  let fold_sink = ref (Execution.Completed 0) in
  repeat list_sink warmup collect;
  check_list !list_sink;
  repeat fold_sink warmup fold;
  check_fold !fold_sink;
  let collected = ref [] in
  let folded = ref [] in
  let sample_list () =
    collected :=
      measure ~check:check_list ~empty:(Interpreter.Ok []) list_sink iterations
        collect
      :: !collected;
    list_sink := Interpreter.Ok []
  in
  let sample_fold () =
    folded :=
      measure ~check:check_fold ~empty:(Execution.Completed 0) fold_sink
        iterations fold
      :: !folded
  in
  list_sink := Interpreter.Ok [];
  for i = 1 to samples do
    if i mod 2 = 1 then begin
      sample_fold ();
      sample_list ()
    end else begin
      sample_list ();
      sample_fold ()
    end
  done;
  let folded = summarize !folded in
  let collected = summarize !collected in
  Printf.printf
    "\n\
     Prepared sink: F = Execution.fold checksum; L = Execution.execute list.\n\
     Query: .[]; %d integers; checksum %d; %d warmup operations per path.\n\
     Parsing, preparation, rendering, and result checks excluded.\n\n"
    rows
    (rows * (rows + 1) / 2)
    warmup;
  Printf.printf "%-23s %-8s %8s %12s %12s %10s %10s %10s %10s\n%!" "Workload"
    "Backend" "Ops/sample" "F ns/op" "L ns/op" "F B/op" "L B/op" "Time delta"
    "Alloc delta";
  Printf.printf
    "%-23s %-8s %8d %12.1f %12.1f %10.1f %10.1f %+9.1f%% %+9.1f%%\n%!"
    "large_stream_sink" "compiled" iterations folded.ns collected.ns
    folded.bytes collected.bytes
    (((folded.ns /. collected.ns) -. 1.0) *. 100.0)
    (((folded.bytes /. collected.bytes) -. 1.0) *. 100.0)

let bench_input ~iterations ~warmup ~samples =
  let groups = 64 in
  let width = 256 in
  let discarded =
    {|"discard":{"nested":[|}
    ^ String.concat ","
        (List.init groups (fun group ->
             "["
             ^ String.concat ","
                 (List.init width (fun i -> string_of_int ((group * width) + i)))
             ^ "]"
         )
        )
    ^ "]}"
  in
  let keep = {|"keep":{"value":42}|} in
  let early = "{" ^ keep ^ "," ^ discarded ^ "}" in
  let late = "{" ^ discarded ^ "," ^ keep ^ "}" in
  let iterations = min 100 (Option.value iterations ~default:100) in
  let warmup = min 10 warmup in
  let prepare_input (name, query, payload, backend, expected) =
    let workload = { name; query; payload; backend; iterations; expected } in
    let expr =
      match Core.parse ~debug:false ~colorize:false query with
      | Ok expr ->
          expr
      | Error message ->
          failwith (name ^ ": query parse error: " ^ message)
    in
    if Execution.backend (Execution.prepare expr) <> backend then
      failwith (name ^ ": unexpected backend");
    let execution () =
      Core.run_input ~debug:false ~colorize:false ~verbose:false ~raw:false
        ~summarize:false query (Core.String payload)
    in
    let interpreter () =
      match Json.parse_string payload with
      | Ok json ->
          one_shot_candidate query json
      | Error message ->
          Error message
    in
    let reference = interpreter () in
    check_string_result (name ^ " fixture") (Ok (render expected)) reference;
    check_string_result name reference (execution ());
    { workload; reference; execution; interpreter }
  in
  let prepared =
    List.map prepare_input
      [
        ( "input_early_keep",
          ".keep.value",
          early,
          Execution.Compiled,
          [ `Int 42 ]
        );
        ("input_late_keep", ".keep.value", late, Execution.Compiled, [ `Int 42 ]);
        ( "input_full_fallback",
          "length",
          early,
          Execution.Interpreted,
          [ `Int64 2L ]
        );
      ]
  in
  Printf.printf
    "\n\
     Input-inclusive: C = Core.run_input (String); R = Json.parse_string + \
     Core.run.\n\
     %d nested arrays of %d integers; %d payload bytes; %d warmup operations \
     per path.\n\
     Early/late query: .keep.value; full-input fallback control: length.\n\
     Includes query parsing, JSON parsing/validation, preparation, execution, \
     and rendering.\n\
     Payload generation and result checks excluded; every input byte is \
     validated.\n\
     Selection avoids discarded container materialization only after a matched \
     root key.\n\
     String input remains retained; B/op is allocation volume, not peak RSS.\n"
    groups width (String.length early) warmup;
  Printf.printf "\n%-23s %-8s %8s %12s %12s %10s %10s %10s %10s\n%!" "Workload"
    "Backend" "Ops/sample" "C ns/op" "R ns/op" "C B/op" "R B/op" "Time delta"
    "Alloc delta";
  List.iter
    (bench ~check:check_string_result ~empty:(Ok "") ~iterations:None ~warmup
       ~samples
    )
    prepared

let bench_first_result ~warmup ~samples =
  let name = "event_member_first" in
  let query = ".rows[] | .id" in
  let payload =
    {|{"rows":|}
    ^ In_channel.with_open_bin "benchmarks/big.json" In_channel.input_all
    ^ {|,"tail":0}|}
  in
  let input = Core.String payload in
  let expr =
    match Core.parse ~debug:false ~colorize:false query with
    | Ok expr ->
        expr
    | Error message ->
        failwith (name ^ ": " ^ message)
  in
  let plan = Execution.prepare expr in
  if Execution.backend plan <> Execution.Compiled then
    failwith (name ^ ": expected compiled backend");
  ( match Execution.For_test.stream_cut plan with
  | Some (Execution.For_test.Member_items ("rows", _)) ->
      ()
  | _ ->
      failwith (name ^ ": expected Member_items rows cut")
  );
  let check_status = function
    | Ok () ->
        ()
    | Error message ->
        failwith (name ^ ": " ^ message)
  in
  let collect input_delivery =
    let outputs = ref [] in
    Core.run_input_iter ~input_delivery ~debug:false ~colorize:false
      ~verbose:false ~raw:false ~summarize:false
      ~emit:(fun value -> outputs := value :: !outputs)
      query input
    |> check_status;
    Array.of_list (List.rev !outputs)
  in
  let expected = collect Core.After_validation in
  if collect Core.When_ready <> expected then
    failwith (name ^ ": delivery policies produced different outputs");
  if Array.length expected = 0 || expected.(0) <> "1" then
    failwith (name ^ ": expected first rendered output 1");
  let measure_first input_delivery =
    let index = ref 0 in
    let first = ref None in
    let before = ref 0.0 in
    let start = ref 0.0 in
    let emit value =
      ( match !first with
      | None ->
          let ns = (Unix.gettimeofday () -. !start) *. 1e9 in
          let bytes = Gc.allocated_bytes () -. !before in
          first := Some { ns; bytes }
      | Some _ ->
          ()
      );
      if !index >= Array.length expected || value <> expected.(!index) then
        failwith (Printf.sprintf "%s: output mismatch at index %d" name !index);
      incr index
    in
    Gc.full_major ();
    before := Gc.allocated_bytes ();
    start := Unix.gettimeofday ();
    Core.run_input_iter ~input_delivery ~debug:false ~colorize:false
      ~verbose:false ~raw:false ~summarize:false ~emit query input
    |> check_status;
    if !index <> Array.length expected then
      failwith (name ^ ": incomplete output");
    match !first with
    | Some measurement when measurement.ns > 0.0 ->
        measurement
    | _ ->
        failwith (name ^ ": missing first result or non-positive elapsed time")
  in
  let warmup = min 3 warmup in
  for _ = 1 to warmup do
    ignore (measure_first Core.When_ready);
    ignore (measure_first Core.After_validation)
  done;
  let ready = ref [] in
  let validated = ref [] in
  let sample policy results = results := measure_first policy :: !results in
  for i = 1 to samples do
    if i mod 2 = 1 then begin
      sample Core.When_ready ready;
      sample Core.After_validation validated
    end else begin
      sample Core.After_validation validated;
      sample Core.When_ready ready
    end
  done;
  let ready = summarize !ready in
  let validated = summarize !validated in
  Printf.printf
    "\n\
     First rendered result: W = When_ready; A = After_validation.\n\
     Fixture: benchmarks/big.json wrapped as {\"rows\":<array>,\"tail\":0}; \
     query: %s.\n\
     Compiled Member_items rows cut; %d input bytes; %d outputs; first output 1.\n\
     One fresh Core.run_input_iter over Core.String per policy per paired \
     sample.\n\
     %d warmup calls per policy; alternating sample order; --iterations does \
     not apply.\n\
     Includes query parse/prepare, JSON parsing to first complete child, \
     residual execution, rendering.\n\
     A also validates the complete document before its first output.\n\
     Excludes fixture load/generation, process startup, stdout; source string \
     stays retained.\n\
     First callback records time/allocation before result checking; each call \
     continues to EOF and checks every output.\n\
     B is allocation volume, not peak RSS. No performance threshold.\n\n"
    query (String.length payload) (Array.length expected) warmup;
  Printf.printf "%-23s %12s %12s %12s %12s %10s %10s %7s\n%!" "Workload"
    "W first ns" "A first ns" "W first B" "A first B" "Time delta" "Alloc delta"
    "Samples";
  Printf.printf "%-23s %12.1f %12.1f %12.1f %12.1f %+9.1f%% %+9.1f%% %7d\n%!"
    name ready.ns validated.ns ready.bytes validated.bytes
    (((ready.ns /. validated.ns) -. 1.0) *. 100.0)
    (((ready.bytes /. validated.bytes) -. 1.0) *. 100.0)
    samples

let () =
  let iterations, warmup, samples = parse_args () in
  let prepared, one_shot = List.split (List.map prepare workloads) in
  check_one_shot_errors ();
  let gc = Gc.get () in
  Printf.printf
    "Execution benchmark: OCaml %s, %d-bit, %s\n\
     GC: minor_heap_size=%d words, space_overhead=%d, allocation_policy=%d\n\
     %d workloads verified in both modes before timing; array fixtures contain \
     %d rows.\n\
     One-shot parse/runtime error checks passed (not timed).\n\
     %d paired samples, %d warmup operations per path in the first two tables; \
     medians below.\n\
     Clock: Unix.gettimeofday.\n\
     Deltas = (candidate / reference - 1) * 100; positive means slower / more \
     allocation.\n\n"
    Sys.ocaml_version Sys.word_size Sys.os_type gc.minor_heap_size
    gc.space_overhead gc.allocation_policy (List.length prepared) rows samples
    warmup;
  List.iter
    (fun p -> Printf.printf "%s: %s\n" p.workload.name p.workload.query)
    prepared;
  Printf.printf
    "\n\
     Prepared execution: E = prepared Execution; I = Interpreter.\n\
     Query/JSON parsing, preparation, rendering, startup, and stdout excluded.\n";
  Printf.printf "\n%-23s %-8s %8s %12s %12s %10s %10s %10s %10s\n%!" "Workload"
    "Backend" "Ops/sample" "E ns/op" "I ns/op" "E B/op" "I B/op" "Time delta"
    "Alloc delta";
  List.iter
    (bench ~check:check_result ~empty:(Interpreter.Ok []) ~iterations ~warmup
       ~samples
    )
    prepared;
  Printf.printf
    "\n\
     One-shot library: C = Core.run; R = former parse/interpret/render path.\n\
     Includes query parsing, per-call preparation (C only), execution, and \
     rendering.\n\
     Already parsed JSON; JSON parsing, startup, and stdout excluded.\n\
     Options: debug=false, colorize=false, verbose=false, raw=false, \
     summarize=false.\n";
  Printf.printf "\n%-23s %-8s %8s %12s %12s %10s %10s %10s %10s\n%!" "Workload"
    "Backend" "Ops/sample" "C ns/op" "R ns/op" "C B/op" "R B/op" "Time delta"
    "Alloc delta";
  List.iter
    (bench ~check:check_string_result ~empty:(Ok "") ~iterations ~warmup
       ~samples
    )
    one_shot;
  bench_sink ~iterations ~warmup ~samples;
  bench_input ~iterations ~warmup ~samples;
  bench_first_result ~warmup ~samples;
  Printf.printf
    "\nAll result checks passed, including warmup and sample endpoints.\n"
