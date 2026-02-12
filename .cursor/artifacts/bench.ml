(* Benchmark for Jotason parsing and serialization *)

let gc_stats () =
  let open Gc in
  let stat = Gc.stat () in
  (stat.minor_words, stat.major_words, stat.promoted_words, stat.minor_collections, stat.major_collections)

let print_gc_diff name (mw1, maj1, pw1, mc1, majc1) (mw2, maj2, pw2, mc2, majc2) =
  Printf.printf "  %s:\n" name;
  Printf.printf "    minor_words: %.0f\n" (mw2 -. mw1);
  Printf.printf "    major_words: %.0f\n" (maj2 -. maj1);
  Printf.printf "    promoted_words: %.0f\n" (pw2 -. pw1);
  Printf.printf "    minor_collections: %d\n" (mc2 - mc1);
  Printf.printf "    major_collections: %d\n" (majc2 - majc1)

(* Generate test JSON data *)
let generate_array_json n =
  let items = List.init n (fun i -> `Int i) in
  `List items

let generate_object_json n =
  let pairs = List.init n (fun i -> (Printf.sprintf "key%d" i, `Int i)) in
  `Assoc pairs

let generate_nested_json depth width =
  let rec go d =
    if d = 0 then `Int 42
    else `Assoc (List.init width (fun i -> (Printf.sprintf "k%d" i, go (d - 1))))
  in
  go depth

let generate_string_json n =
  let s = String.make n 'x' in
  `String s

let generate_mixed_json n =
  `Assoc [
    ("array", generate_array_json n);
    ("object", generate_object_json n);
    ("nested", generate_nested_json 4 5);
    ("string", generate_string_json 1000);
    ("bool", `Bool true);
    ("null", `Null);
    ("float", `Float 3.14159);
  ]

(* Benchmark a function *)
let bench name iterations f =
  Gc.full_major ();
  let gc_before = gc_stats () in
  let t0 = Unix.gettimeofday () in
  for _ = 1 to iterations do
    ignore (f ())
  done;
  let t1 = Unix.gettimeofday () in
  let gc_after = gc_stats () in
  let elapsed = t1 -. t0 in
  Printf.printf "\n%s (%d iterations):\n" name iterations;
  Printf.printf "  time: %.3f ms (%.3f µs/iter)\n"
    (elapsed *. 1000.0)
    (elapsed *. 1000000.0 /. float_of_int iterations);
  print_gc_diff "GC" gc_before gc_after;
  elapsed

let bench_parsing json_str iterations =
  bench "Parsing" iterations (fun () -> Json.from_string json_str)

let bench_serialization json iterations =
  bench "Serialization" iterations (fun () -> Json.to_string json)

let bench_roundtrip json_str iterations =
  bench "Roundtrip" iterations (fun () ->
    let parsed = Json.from_string json_str in
    Json.to_string parsed
  )

let run_benchmark name json iterations =
  Printf.printf "\n========== %s ==========\n" name;
  let json_str = Json.to_string json in
  Printf.printf "JSON size: %d bytes\n" (String.length json_str);

  let _ = bench_parsing json_str iterations in
  let _ = bench_serialization json iterations in
  let _ = bench_roundtrip json_str iterations in
  ()

let () =
  Printf.printf "Jotason Allocation Benchmark\n";
  Printf.printf "OCaml version: %s\n" Sys.ocaml_version;
  Printf.printf "==============================\n";

  (* Small JSON *)
  run_benchmark "Small Array (100 elements)" (generate_array_json 100) 10000;

  (* Medium JSON *)
  run_benchmark "Medium Array (1000 elements)" (generate_array_json 1000) 1000;

  (* Large JSON *)
  run_benchmark "Large Array (10000 elements)" (generate_array_json 10000) 100;

  (* Object *)
  run_benchmark "Object (100 keys)" (generate_object_json 100) 10000;

  (* Nested *)
  run_benchmark "Nested (depth=5, width=5)" (generate_nested_json 5 5) 1000;

  (* Mixed *)
  run_benchmark "Mixed (n=100)" (generate_mixed_json 100) 1000;

  (* String-heavy *)
  run_benchmark "Large String (10KB)" (generate_string_json 10000) 10000;

  Printf.printf "\n\n========== Allocation Analysis ==========\n";
  Printf.printf "Analyzing allocation patterns...\n\n";

  (* Single operation analysis *)
  Gc.full_major ();
  let json = generate_array_json 1000 in
  let json_str = Json.to_string json in

  Gc.full_major ();
  let (mw1, _, _, _, _) = gc_stats () in
  let _ = Json.from_string json_str in
  let (mw2, _, _, _, _) = gc_stats () in

  let words_per_parse = mw2 -. mw1 in
  let bytes_per_parse = words_per_parse *. 8.0 in

  Printf.printf "Single parse of 1000-element array:\n";
  Printf.printf "  Words allocated: %.0f\n" words_per_parse;
  Printf.printf "  Bytes allocated: %.0f (%.1f KB)\n" bytes_per_parse (bytes_per_parse /. 1024.0);
  Printf.printf "  JSON size: %d bytes\n" (String.length json_str);
  Printf.printf "  Allocation ratio: %.2fx JSON size\n" (bytes_per_parse /. float_of_int (String.length json_str));

  Gc.full_major ();
  let (mw1, _, _, _, _) = gc_stats () in
  let _ = Json.to_string json in
  let (mw2, _, _, _, _) = gc_stats () in

  let words_per_write = mw2 -. mw1 in
  let bytes_per_write = words_per_write *. 8.0 in

  Printf.printf "\nSingle serialize of 1000-element array:\n";
  Printf.printf "  Words allocated: %.0f\n" words_per_write;
  Printf.printf "  Bytes allocated: %.0f (%.1f KB)\n" bytes_per_write (bytes_per_write /. 1024.0);
  Printf.printf "  Allocation ratio: %.2fx JSON size\n" (bytes_per_write /. float_of_int (String.length json_str));

  Printf.printf "\n"

