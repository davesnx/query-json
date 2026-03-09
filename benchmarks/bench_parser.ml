let queries =
  [
    ("identity", ".");
    ("field_access", ".foo.bar.baz");
    ("array_index", ".[0]");
    ("pipe_chain", ".foo | .bar | .baz | .qux");
    ("map_simple", "map(.x + 1)");
    ("arithmetic", "1 + 2 * 3 - 4 / 5 % 6");
    ("comparison", ". > 5 and . < 10 or . == 0");
    ("array_construct", "[.[] | {name: .name, city: .address.city}]");
    ("object_construct", "{a: .x, b: .y, c: (.z | to_string)}");
    ( "if_then_else",
      "if . > 0 then \"positive\" elif . < 0 then \"negative\" else \"zero\" \
       end"
    );
    ("reduce", "reduce .[] as $x (0; . + $x)");
    ("foreach", "[foreach .[] as $x (0; . + $x; .)]");
    ("fn_def", "fn double: . * 2; fn add1: . + 1; map(double | add1)");
    ("try_catch", "try .foo catch \"not found\"");
    ("string_interp", "\"Hello, \\(.name)! Age: \\(.age)\"");
    ( "complex_real_world",
      "group_by(.category) | [.[]] | map({category: .[0].category, count: \
       length, total: (map(.val) | add)})"
    );
    ( "nested_functions",
      "fn fact: if . <= 1 then 1 else . * ((. - 1) | fact) end; 10 | fact"
    );
    ( "filter_chain",
      ".[] | select(.active == true and .age >= 18) | {name: .name, email: \
       .email}"
    );
    ("update_assign", ".foo |= . + 1 | .bar += 2 | .baz -= 3");
    ("optional_access", ".foo?.bar?[]? | select(. > 0)");
    ("range_expressions", "[range(0; 10; 2)] | map(. * .)");
    ( "walk_transform",
      "walk(if type == \"object\" then with_entries(.key |= to_uppercase) else \
       . end)"
    );
  ]

let warmup_iterations = 1_000
let iterations = 100_000
let word_size = Sys.word_size / 8

type result = {
  elapsed : float;
  minor_words : float;
  promoted_words : float;
  minor_collections : int;
}

let bench query =
  for _ = 1 to warmup_iterations do
    let buf = Sedlexing.Utf8.from_string query in
    ignore (Parser.program buf)
  done;
  Gc.compact ();
  let before = Gc.quick_stat () in
  let start = Unix.gettimeofday () in
  for _ = 1 to iterations do
    let buf = Sedlexing.Utf8.from_string query in
    ignore (Parser.program buf)
  done;
  let elapsed = Unix.gettimeofday () -. start in
  let after = Gc.quick_stat () in
  {
    elapsed;
    minor_words = after.minor_words -. before.minor_words;
    promoted_words = after.promoted_words -. before.promoted_words;
    minor_collections = after.minor_collections - before.minor_collections;
  }

let () =
  let n = Float.of_int iterations in
  let total_queries = List.length queries in
  Printf.printf "Parser Benchmark (%d iterations, %d warmup)\n\n" iterations
    warmup_iterations;
  Printf.printf "%-22s %8s %8s %8s %6s\n" "Query" "ns/op" "B/op" "prom/op" "GCs";
  Printf.printf "%s\n" (String.make 56 '-');
  let total_time = ref 0.0 in
  let total_minor_w = ref 0.0 in
  let total_promoted = ref 0.0 in
  let total_gcs = ref 0 in
  List.iter
    (fun (name, query) ->
      let r = bench query in
      let ns = r.elapsed /. n *. 1e9 in
      let bytes = r.minor_words /. n *. Float.of_int word_size in
      let promoted = r.promoted_words /. n *. Float.of_int word_size in
      Printf.printf "%-22s %8.0f %8.0f %8.0f %6d\n" name ns bytes promoted
        r.minor_collections;
      total_time := !total_time +. r.elapsed;
      total_minor_w := !total_minor_w +. r.minor_words;
      total_promoted := !total_promoted +. r.promoted_words;
      total_gcs := !total_gcs + r.minor_collections
    )
    queries;
  let total_parses = Float.of_int total_queries *. n in
  Printf.printf "%s\n" (String.make 56 '-');
  Printf.printf "%-22s %8.0f %8.0f %8.0f %6d\n" "AVERAGE"
    (!total_time /. total_parses *. 1e9)
    (!total_minor_w /. total_parses *. Float.of_int word_size)
    (!total_promoted /. total_parses *. Float.of_int word_size)
    !total_gcs;
  Printf.printf "\n%.2fM parses in %.3fs\n" (total_parses /. 1e6) !total_time
