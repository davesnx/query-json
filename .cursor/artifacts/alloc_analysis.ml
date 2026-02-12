(* Detailed allocation analysis for specific parsing operations *)

let measure_alloc name f =
  Gc.full_major ();
  let stat1 = Gc.stat () in
  let result = f () in
  let stat2 = Gc.stat () in
  let minor = stat2.minor_words -. stat1.minor_words in
  let major = stat2.major_words -. stat1.major_words in
  Printf.printf "%s: minor=%.0f major=%.0f words\n" name minor major;
  result

let () =
  Printf.printf "=== Allocation Source Analysis ===\n\n";

  (* Test 1: Integer parsing - should be cheap (no string allocation) *)
  Printf.printf "--- Integer parsing ---\n";
  let _ = measure_alloc "Parse single int" (fun () -> Json.from_string "42") in
  let _ = measure_alloc "Parse 100 ints" (fun () ->
    Json.from_string "[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100]"
  ) in

  (* Test 2: Float parsing - allocates string via Lexing.lexeme *)
  Printf.printf "\n--- Float parsing ---\n";
  let _ = measure_alloc "Parse single float" (fun () -> Json.from_string "3.14159") in
  let _ = measure_alloc "Parse 10 floats" (fun () ->
    Json.from_string "[1.1,2.2,3.3,4.4,5.5,6.6,7.7,8.8,9.9,10.10]"
  ) in

  (* Test 3: String parsing - allocates via Buffer.contents *)
  Printf.printf "\n--- String parsing ---\n";
  let _ = measure_alloc "Parse empty string" (fun () -> Json.from_string "\"\"") in
  let _ = measure_alloc "Parse short string" (fun () -> Json.from_string "\"hello\"") in
  let _ = measure_alloc "Parse 100-char string" (fun () ->
    Json.from_string "\"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\""
  ) in
  let _ = measure_alloc "Parse 1000-char string" (fun () ->
    Json.from_string ("\"" ^ String.make 1000 'x' ^ "\"")
  ) in

  (* Test 4: Array construction - allocates list cells *)
  Printf.printf "\n--- Array construction overhead ---\n";
  let _ = measure_alloc "Empty array" (fun () -> Json.from_string "[]") in
  let _ = measure_alloc "Single element array" (fun () -> Json.from_string "[1]") in
  let _ = measure_alloc "5 element array" (fun () -> Json.from_string "[1,2,3,4,5]") in
  let _ = measure_alloc "10 element array" (fun () -> Json.from_string "[1,2,3,4,5,6,7,8,9,10]") in

  (* Test 5: Object construction - allocates tuples and list cells *)
  Printf.printf "\n--- Object construction overhead ---\n";
  let _ = measure_alloc "Empty object" (fun () -> Json.from_string "{}") in
  let _ = measure_alloc "Single key object" (fun () -> Json.from_string "{\"a\":1}") in
  let _ = measure_alloc "5 key object" (fun () -> Json.from_string "{\"a\":1,\"b\":2,\"c\":3,\"d\":4,\"e\":5}") in

  (* Test 6: Serialization allocations *)
  Printf.printf "\n--- Serialization ---\n";
  let json_int = `Int 42 in
  let json_float = `Float 3.14159 in
  let json_string = `String "hello world" in
  let json_array = `List [`Int 1; `Int 2; `Int 3; `Int 4; `Int 5] in
  let json_object = `Assoc [("a", `Int 1); ("b", `Int 2)] in

  let _ = measure_alloc "Serialize int" (fun () -> Json.to_string json_int) in
  let _ = measure_alloc "Serialize float" (fun () -> Json.to_string json_float) in
  let _ = measure_alloc "Serialize string" (fun () -> Json.to_string json_string) in
  let _ = measure_alloc "Serialize 5-elem array" (fun () -> Json.to_string json_array) in
  let _ = measure_alloc "Serialize 2-key object" (fun () -> Json.to_string json_object) in

  (* Test 7: Lexer state allocation *)
  Printf.printf "\n--- Per-parse fixed costs ---\n";
  (* The lexer state includes a buffer that gets allocated each time *)
  for _ = 1 to 3 do
    let _ = measure_alloc "Parse 'null'" (fun () -> Json.from_string "null") in
    ()
  done;

  Printf.printf "\n=== Summary ===\n";
  Printf.printf "Key allocation sources:\n";
  Printf.printf "1. Lexer state buffer (per-parse overhead)\n";
  Printf.printf "2. Lexing.lexeme for floats (string allocation)\n";
  Printf.printf "3. Buffer.contents for strings\n";
  Printf.printf "4. List cells for arrays/objects\n";
  Printf.printf "5. Tuples for object key-value pairs\n";
  Printf.printf "6. List.rev copies for final results\n"

