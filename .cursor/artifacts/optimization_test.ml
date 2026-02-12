(* Test potential optimizations *)

let gc_minor_words () =
  (Gc.stat ()).minor_words

let measure_alloc name iterations f =
  Gc.full_major ();
  let before = gc_minor_words () in
  for _ = 1 to iterations do
    ignore (f ())
  done;
  let after = gc_minor_words () in
  let words = (after -. before) /. float_of_int iterations in
  Printf.printf "%s: %.1f words/iter\n" name words;
  words

(* Test 1: Buffer reuse *)
let test_buffer_reuse () =
  Printf.printf "\n=== Buffer Reuse Test ===\n";
  let json_str = "[1,2,3,4,5,6,7,8,9,10]" in
  let iterations = 10000 in

  (* Without buffer reuse *)
  let w1 = measure_alloc "Fresh buffer each time" iterations (fun () ->
    Json.from_string json_str
  ) in

  (* With buffer reuse *)
  let buf = Buffer.create 256 in
  let w2 = measure_alloc "Reusing buffer" iterations (fun () ->
    Json.from_string ~buf json_str
  ) in

  Printf.printf "Savings: %.1f words/iter (%.1f%%)\n"
    (w1 -. w2)
    ((w1 -. w2) /. w1 *. 100.0)

(* Test 2: Local ref potential (simulated) *)
let test_local_ref_potential () =
  Printf.printf "\n=== Local Ref Potential ===\n";
  let iterations = 100000 in

  (* Current pattern: heap-allocated ref *)
  let w1 = measure_alloc "Global ref" iterations (fun () ->
    let acc = ref [] in
    for i = 1 to 10 do
      acc := i :: !acc
    done;
    List.rev !acc
  ) in

  (* With local_ ref *)
  let w2 = measure_alloc "Local ref" iterations (fun () ->
    let local_ acc = ref [] in
    for i = 1 to 10 do
      acc := i :: !acc
    done;
    List.rev !acc
  ) in

  Printf.printf "Savings: %.1f words/iter (%.1f%%)\n"
    (w1 -. w2)
    (if w1 > 0.0 then (w1 -. w2) /. w1 *. 100.0 else 0.0)

(* Test 3: Float parsing optimization potential *)
let test_float_parsing () =
  Printf.printf "\n=== Float Parsing ===\n";
  let iterations = 100000 in

  (* Current: allocates string via Lexing.lexeme then float_of_string *)
  let w1 = measure_alloc "Current (via string)" iterations (fun () ->
    let s = "3.14159265358979" in
    float_of_string s
  ) in

  (* Optimal: parse directly from bytes (simulated) *)
  let w2 = measure_alloc "Direct parse (simulated)" iterations (fun () ->
    3.14159265358979
  ) in

  Printf.printf "Potential savings: %.1f words/iter\n" (w1 -. w2)

(* Test 4: List.rev vs direct construction *)
let test_list_construction () =
  Printf.printf "\n=== List Construction ===\n";
  let iterations = 100000 in

  (* Current: build reversed then List.rev *)
  let _w1 = measure_alloc "Build + List.rev" iterations (fun () ->
    let local_ acc = ref [] in
    for i = 1 to 10 do
      acc := i :: !acc
    done;
    List.rev !acc
  ) in

  (* Array-based alternative (for comparison) *)
  let _w2 = measure_alloc "Array-based" iterations (fun () ->
    let arr = Array.make 10 0 in
    for i = 0 to 9 do
      arr.(i) <- i + 1
    done;
    Array.to_list arr
  ) in

  Printf.printf "Note: Array approach may be faster but still allocates on to_list\n"

(* Test 5: Measure actual parsing bottleneck *)
let test_parsing_bottleneck () =
  Printf.printf "\n=== Parsing Bottleneck Analysis ===\n";
  let iterations = 10000 in

  (* Pure integers - no string allocation for number parsing *)
  let _ = measure_alloc "Array of 10 ints" iterations (fun () ->
    Json.from_string "[1,2,3,4,5,6,7,8,9,10]"
  ) in

  (* Floats - allocates string for each number *)
  let _ = measure_alloc "Array of 10 floats" iterations (fun () ->
    Json.from_string "[1.1,2.2,3.3,4.4,5.5,6.6,7.7,8.8,9.9,10.0]"
  ) in

  (* Strings - allocates for each string *)
  let _ = measure_alloc "Array of 10 short strings" iterations (fun () ->
    Json.from_string "[\"a\",\"b\",\"c\",\"d\",\"e\",\"f\",\"g\",\"h\",\"i\",\"j\"]"
  ) in

  ()

let () =
  Printf.printf "=== Jotason Optimization Analysis ===\n";
  Printf.printf "OCaml version: %s\n" Sys.ocaml_version;

  test_buffer_reuse ();
  test_local_ref_potential ();
  test_float_parsing ();
  test_list_construction ();
  test_parsing_bottleneck ();

  Printf.printf "\n=== Recommendations ===\n";
  Printf.printf "1. Always pass ~buf for repeated parsing (already supported)\n";
  Printf.printf "2. Use local_ refs in array/object parsing (OxCaml)\n";
  Printf.printf "3. Consider direct float parsing from lexbuf buffer\n";
  Printf.printf "4. The AST itself must be heap-allocated (fundamental)\n"

