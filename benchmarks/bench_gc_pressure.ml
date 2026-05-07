type config = { file : string; iterations : int }

type sample = { stat : Gc.stat; rss_kb : int option }

type run_result = { keep_alive : unit -> int; observed : int }

type scenario = {
  name : string;
  description : string;
  run : payload:string -> iterations:int -> run_result;
}

type measurement = {
  scenario : scenario;
  work_s : float;
  full_major_ms : float;
  compact_ms : float;
  before : sample;
  after_work : sample;
  after_major : sample;
  after_compact : sample;
  observed : int;
}

let default_file = "benchmarks/big.json"
let default_iterations = 8
let word_size = Sys.word_size / 8
let blackhole = ref 0

let usage () =
  Printf.eprintf
    "Usage: dune exec benchmarks/bench_gc_pressure.exe -- [--file PATH] \
     [--iterations N]\n\n\
     Measures GC pressure from realistic query-json parse, query, and \
     rendering workloads.\n\n\
     Examples:\n\
    \  dune exec benchmarks/bench_gc_pressure.exe\n\
    \  dune exec benchmarks/bench_gc_pressure.exe -- --file \
     benchmarks/huge.json --iterations 3\n"

let parse_positive_int flag value =
  match int_of_string_opt value with
  | Some n when n > 0 ->
      n
  | _ ->
      Printf.eprintf "%s expects a positive integer, got %S\n" flag value;
      exit 2

let parse_args () =
  let rec loop cfg i =
    if i >= Array.length Sys.argv then
      cfg
    else
      match Sys.argv.(i) with
      | "--file" ->
          if i + 1 >= Array.length Sys.argv then begin
            usage ();
            exit 2
          end;
          loop { cfg with file = Sys.argv.(i + 1) } (i + 2)
      | "--iterations" | "--iters" ->
          if i + 1 >= Array.length Sys.argv then begin
            usage ();
            exit 2
          end;
          loop
            {
              cfg with
              iterations = parse_positive_int Sys.argv.(i) Sys.argv.(i + 1);
            }
            (i + 2)
      | "--help" | "-h" ->
          usage ();
          exit 0
      | arg ->
          Printf.eprintf "Unknown argument: %s\n" arg;
          usage ();
          exit 2
  in
  loop { file = default_file; iterations = default_iterations } 1

let starts_with s prefix =
  let prefix_len = String.length prefix in
  String.length s >= prefix_len && String.sub s 0 prefix_len = prefix

let parse_first_int s =
  let len = String.length s in
  let rec skip i =
    if i >= len then
      None
    else
      match s.[i] with '0' .. '9' -> Some i | _ -> skip (i + 1)
  in
  let rec take acc i =
    if i >= len then
      acc
    else
      match s.[i] with
      | '0' .. '9' as c ->
          take ((acc * 10) + Char.code c - Char.code '0') (i + 1)
      | _ ->
          acc
  in
  match skip 0 with None -> None | Some i -> Some (take 0 i)

let current_rss_kb () =
  try
    let ic = open_in "/proc/self/status" in
    let rec loop () =
      match input_line ic with
      | line ->
          if starts_with line "VmRSS:" then begin
            let rss = parse_first_int line in
            close_in_noerr ic;
            rss
          end else
            loop ()
      | exception End_of_file ->
          close_in_noerr ic;
          None
    in
    loop ()
  with _ -> None

let sample () = { stat = Gc.quick_stat (); rss_kb = current_rss_kb () }

let read_file path =
  let ic = open_in_bin path in
  try
    let len = in_channel_length ic in
    let contents = really_input_string ic len in
    close_in ic;
    contents
  with exn ->
    close_in_noerr ic;
    raise exn

let file_size path = (Unix.stat path).Unix.st_size

let parse_payload payload =
  match Json.parse_string payload with
  | Ok json ->
      json
  | Error err ->
      failwith ("JSON parse error: " ^ err)

let compile_query query =
  match Core.parse ~debug:false ~colorize:false query with
  | Ok expr ->
      expr
  | Error err ->
      failwith ("Query parse error for " ^ query ^ ": " ^ err)

let root_score (json : Json.t) =
  match json with
  | `List items ->
      List.length items
  | `Assoc fields ->
      List.length fields
  | `String s ->
      String.length s
  | `Null ->
      0
  | `Bool _ | `Int _ | `Int64 _ | `Big_int _ | `Decimal _ | `Float _ ->
      1

let run_query expr json =
  match Interpreter.execute ~colorize:false ~verbose:false expr json with
  | Interpreter.Ok results ->
      List.fold_left (fun acc result -> acc + root_score result) 0 results
  | Interpreter.Error err ->
      failwith ("Query execution error: " ^ err)
  | Interpreter.Halt code ->
      failwith (Printf.sprintf "Query halted with exit code %d" code)

let parse_drop =
  {
    name = "parse_drop";
    description = "Repeatedly parse JSON and drop each tree";
    run =
      (fun ~payload ~iterations ->
        let observed = ref 0 in
        for _ = 1 to iterations do
          let json = parse_payload payload in
          observed := !observed + root_score json
        done;
        { keep_alive = (fun () -> String.length payload); observed = !observed }
      );
  }

let parse_render_drop =
  {
    name = "parse_render_drop";
    description = "Parse JSON, pretty-print it, then drop both values";
    run =
      (fun ~payload ~iterations ->
        let observed = ref 0 in
        for _ = 1 to iterations do
          let json = parse_payload payload in
          let rendered =
            Json.to_string_pretty ~colorize:false ~summarize:false ~raw:false
              json
          in
          observed := !observed + String.length rendered
        done;
        { keep_alive = (fun () -> String.length payload); observed = !observed }
      );
  }

let retained_filter_query =
  {
    name = "retained_filter_query";
    description = "Keep the parsed JSON live while running filter/map queries";
    run =
      (fun ~payload ~iterations ->
        let json = parse_payload payload in
        let expr =
          compile_query {|filter(.base."Attack" > 100) | map(.name.english)|}
        in
        let observed = ref (root_score json) in
        for _ = 1 to iterations do
          observed := !observed + run_query expr json
        done;
        { keep_alive = (fun () -> root_score json); observed = !observed }
      );
  }

let retained_group_by =
  {
    name = "retained_group_by";
    description = "Keep the parsed JSON live while repeatedly grouping results";
    run =
      (fun ~payload ~iterations ->
        let json = parse_payload payload in
        let expr = compile_query {|group_by(.type[0])|} in
        let observed = ref (root_score json) in
        for _ = 1 to iterations do
          observed := !observed + run_query expr json
        done;
        { keep_alive = (fun () -> root_score json); observed = !observed }
      );
  }

let retained_render =
  {
    name = "retained_render";
    description =
      "Keep the parsed JSON live while repeatedly pretty-printing it";
    run =
      (fun ~payload ~iterations ->
        let json = parse_payload payload in
        let observed = ref (root_score json) in
        for _ = 1 to iterations do
          let rendered =
            Json.to_string_pretty ~colorize:false ~summarize:false ~raw:false
              json
          in
          observed := !observed + String.length rendered
        done;
        { keep_alive = (fun () -> root_score json); observed = !observed }
      );
  }

let retained_some_parses =
  {
    name = "retained_some_parses";
    description =
      "Parse repeatedly, retaining a few trees to fragment live data";
    run =
      (fun ~payload ~iterations ->
        let retained = ref [] in
        let retained_count = ref 0 in
        let max_retained =
          if String.length payload > 10 * 1024 * 1024 then
            1
          else
            3
        in
        let observed = ref 0 in
        for i = 1 to iterations do
          let json = parse_payload payload in
          observed := !observed + root_score json;
          if i mod 3 = 0 && !retained_count < max_retained then begin
            retained := json :: !retained;
            incr retained_count
          end
        done;
        {
          keep_alive =
            (fun () ->
              List.fold_left (fun acc json -> acc + root_score json) 0 !retained
            );
          observed = !observed;
        }
      );
  }

let scenarios =
  [
    parse_drop;
    parse_render_drop;
    retained_filter_query;
    retained_group_by;
    retained_render;
    retained_some_parses;
  ]

let cleanup_heap () =
  Gc.full_major ();
  Gc.compact ();
  Gc.full_major ()

let timed f =
  let start = Unix.gettimeofday () in
  let result = f () in
  (result, Unix.gettimeofday () -. start)

let measure payload iterations scenario =
  cleanup_heap ();
  let before = sample () in
  let run_result, work_s =
    timed (fun () -> scenario.run ~payload ~iterations)
  in
  let after_work = sample () in
  let (), full_major_s = timed Gc.full_major in
  let after_major = sample () in
  let (), compact_s = timed Gc.compact in
  let after_compact = sample () in
  blackhole := !blackhole + run_result.observed + run_result.keep_alive ();
  {
    scenario;
    work_s;
    full_major_ms = full_major_s *. 1_000.;
    compact_ms = compact_s *. 1_000.;
    before;
    after_work;
    after_major;
    after_compact;
    observed = run_result.observed;
  }

let mib_of_words words = words *. Float.of_int word_size /. 1024. /. 1024.
let mib_of_int_words words = mib_of_words (Float.of_int words)
let mib_of_kb = function None -> nan | Some kb -> Float.of_int kb /. 1024.

let delta_words field before after = field after.stat -. field before.stat
let delta_int field before after = field after.stat - field before.stat

let print_header cfg payload_bytes =
  Printf.printf "# query-json GC pressure benchmark\n\n";
  Printf.printf "- OCaml version: `%s`\n" Sys.ocaml_version;
  Printf.printf "- Word size: `%d bytes`\n" word_size;
  Printf.printf "- File: `%s`\n" cfg.file;
  Printf.printf "- File size: `%d bytes`\n" (file_size cfg.file);
  Printf.printf "- Payload bytes retained by harness: `%d`\n" payload_bytes;
  Printf.printf "- Iterations per scenario: `%d`\n\n" cfg.iterations;
  Printf.printf
    "| Scenario | Work s | Full major ms | Compact ms | Alloc MiB | Promoted \
     MiB | Major GCs | Heap work MiB | Heap major MiB | Heap compact MiB | \
     Free major MiB | Free compact MiB | Fragments major | Fragments compact | \
     RSS work MiB | RSS compact MiB | Observed |\n";
  Printf.printf
    "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n"

let print_measurement m =
  let alloc_mib =
    delta_words (fun stat -> stat.Gc.minor_words) m.before m.after_work
    |> mib_of_words
  in
  let promoted_mib =
    delta_words (fun stat -> stat.Gc.promoted_words) m.before m.after_work
    |> mib_of_words
  in
  let major_gcs =
    delta_int (fun stat -> stat.Gc.major_collections) m.before m.after_work
  in
  Printf.printf
    "| `%s` | %.3f | %.3f | %.3f | %.1f | %.1f | %d | %.1f | %.1f | %.1f | \
     %.1f | %.1f | %d | %d | %.1f | %.1f | %d |\n"
    m.scenario.name m.work_s m.full_major_ms m.compact_ms alloc_mib promoted_mib
    major_gcs
    (mib_of_int_words m.after_work.stat.Gc.heap_words)
    (mib_of_int_words m.after_major.stat.Gc.heap_words)
    (mib_of_int_words m.after_compact.stat.Gc.heap_words)
    (mib_of_int_words m.after_major.stat.Gc.free_words)
    (mib_of_int_words m.after_compact.stat.Gc.free_words)
    m.after_major.stat.Gc.fragments m.after_compact.stat.Gc.fragments
    (mib_of_kb m.after_work.rss_kb)
    (mib_of_kb m.after_compact.rss_kb)
    m.observed

let print_descriptions () =
  Printf.printf "\n## Scenarios\n\n";
  List.iter
    (fun scenario ->
      Printf.printf "- `%s`: %s\n" scenario.name scenario.description
    )
    scenarios

let () =
  let cfg = parse_args () in
  if not (Sys.file_exists cfg.file) then begin
    Printf.eprintf "Benchmark file does not exist: %s\n" cfg.file;
    exit 2
  end;
  let payload = read_file cfg.file in
  print_header cfg (String.length payload);
  List.iter
    (fun scenario ->
      let measurement = measure payload cfg.iterations scenario in
      print_measurement measurement;
      flush stdout
    )
    scenarios;
  print_descriptions ();
  Printf.printf "\nBlackhole: `%d`\n" !blackhole
