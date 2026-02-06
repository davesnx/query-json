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
    ("if_then_else", "if . > 0 then \"positive\" elif . < 0 then \"negative\" else \"zero\" end");
    ("reduce", "reduce .[] as $x (0; . + $x)");
    ("foreach", "[foreach .[] as $x (0; . + $x; .)]");
    ("fn_def", "fn double: . * 2; fn add1: . + 1; map(double | add1)");
    ("try_catch", "try .foo catch \"not found\"");
    ("string_interp", "\"Hello, \\(.name)! Age: \\(.age)\"");
    ("complex_real_world",
     "group_by(.category) | [.[]] | map({category: .[0].category, count: length, total: (map(.val) | add)})");
    ("nested_functions",
     "fn fact: if . <= 1 then 1 else . * ((. - 1) | fact) end; 10 | fact");
    ("filter_chain",
     ".[] | select(.active == true and .age >= 18) | {name: .name, email: .email}");
    ("update_assign", ".foo |= . + 1 | .bar += 2 | .baz -= 3");
    ("optional_access", ".foo?.bar?[]? | select(. > 0)");
    ("range_expressions", "[range(0; 10; 2)] | map(. * .)");
    ("walk_transform",
     "walk(if type == \"object\" then with_entries(.key |= to_uppercase) else . end)");
  ]

let iterations = 100_000

let time_parse query =
  let start = Unix.gettimeofday () in
  for _ = 1 to iterations do
    let buf = Sedlexing.Utf8.from_string query in
    ignore (Parser.program buf)
  done;
  let stop = Unix.gettimeofday () in
  stop -. start

let () =
  Printf.printf "Parser Benchmark (%d iterations per query)\n" iterations;
  Printf.printf "%-25s %10s %12s\n" "Query" "Total (s)" "Per-parse (ns)";
  Printf.printf "%s\n" (String.make 50 '-');
  let total_time = ref 0.0 in
  let total_parses = ref 0 in
  List.iter (fun (name, query) ->
    let elapsed = time_parse query in
    let ns_per = elapsed /. Float.of_int iterations *. 1_000_000_000.0 in
    Printf.printf "%-25s %10.3f %12.0f\n" name elapsed ns_per;
    total_time := !total_time +. elapsed;
    total_parses := !total_parses + iterations
  ) queries;
  Printf.printf "%s\n" (String.make 50 '-');
  let avg_ns = !total_time /. Float.of_int !total_parses *. 1_000_000_000.0 in
  Printf.printf "%-25s %10.3f %12.0f\n" "TOTAL" !total_time avg_ns;
  Printf.printf "\nTotal parses: %d\n" !total_parses;
  Printf.printf "Total time: %.3f s\n" !total_time
