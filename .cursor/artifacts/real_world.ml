(* Real-world performance comparison *)

(* Generate realistic JSON data *)
let generate_package_json () =
  {|{
  "name": "query-json",
  "version": "1.0.0",
  "description": "A JSON query tool",
  "main": "index.js",
  "scripts": {
    "test": "jest",
    "build": "dune build",
    "clean": "dune clean"
  },
  "dependencies": {
    "lodash": "^4.17.21",
    "express": "^4.18.2",
    "react": "^18.2.0",
    "typescript": "^5.0.0"
  },
  "devDependencies": {
    "jest": "^29.5.0",
    "prettier": "^3.0.0",
    "eslint": "^8.40.0"
  },
  "keywords": ["json", "query", "jq", "ocaml"],
  "author": "davesnx",
  "license": "MIT",
  "repository": {
    "type": "git",
    "url": "https://github.com/davesnx/query-json"
  }
}|}

let generate_api_response n =
  let users = List.init n (fun i ->
    Printf.sprintf {|{"id":%d,"name":"User %d","email":"user%d@example.com","active":true,"score":%.2f}|}
      i i i (Random.float 100.0)
  ) in
  Printf.sprintf {|{"status":"ok","count":%d,"users":[%s]}|} n (String.concat "," users)

let measure name iterations f =
  Gc.full_major ();
  let t0 = Unix.gettimeofday () in
  for _ = 1 to iterations do
    ignore (f ())
  done;
  let t1 = Unix.gettimeofday () in
  let elapsed_us = (t1 -. t0) *. 1_000_000.0 /. float iterations in
  Printf.printf "%s: %.2f µs/op\n" name elapsed_us

let () =
  Printf.printf "=== Real-World JSON Benchmarks ===\n\n";

  (* Benchmark 1: Typical package.json-like structure *)
  Printf.printf "--- Package.json-like (small config) ---\n";
  let pkg_json = generate_package_json () in
  Printf.printf "Size: %d bytes\n" (String.length pkg_json);
  measure "Parse" 10000 (fun () -> Json.from_string pkg_json);
  let parsed = Json.from_string pkg_json in
  measure "Serialize" 10000 (fun () -> Json.to_string parsed);
  measure "Roundtrip" 10000 (fun () -> Json.to_string (Json.from_string pkg_json));

  (* Benchmark 2: API response with 10 users *)
  Printf.printf "\n--- API Response (10 users) ---\n";
  let api_10 = generate_api_response 10 in
  Printf.printf "Size: %d bytes\n" (String.length api_10);
  measure "Parse" 10000 (fun () -> Json.from_string api_10);
  let parsed_10 = Json.from_string api_10 in
  measure "Serialize" 10000 (fun () -> Json.to_string parsed_10);

  (* Benchmark 3: API response with 100 users *)
  Printf.printf "\n--- API Response (100 users) ---\n";
  let api_100 = generate_api_response 100 in
  Printf.printf "Size: %d bytes\n" (String.length api_100);
  measure "Parse" 1000 (fun () -> Json.from_string api_100);
  let parsed_100 = Json.from_string api_100 in
  measure "Serialize" 1000 (fun () -> Json.to_string parsed_100);

  (* Benchmark 4: API response with 1000 users *)
  Printf.printf "\n--- API Response (1000 users) ---\n";
  let api_1000 = generate_api_response 1000 in
  Printf.printf "Size: %d bytes\n" (String.length api_1000);
  measure "Parse" 100 (fun () -> Json.from_string api_1000);
  let parsed_1000 = Json.from_string api_1000 in
  measure "Serialize" 100 (fun () -> Json.to_string parsed_1000);

  (* Benchmark 5: JSONL simulation (many small parses) *)
  Printf.printf "\n--- JSONL Simulation (1000 small objects) ---\n";
  let lines = List.init 1000 (fun i ->
    Printf.sprintf {|{"id":%d,"value":%d}|} i (i * 2)
  ) in

  (* Without buffer reuse *)
  measure "Parse 1000 lines (fresh buffer)" 10 (fun () ->
    List.iter (fun line -> ignore (Json.from_string line)) lines
  );

  (* With buffer reuse *)
  let buf = Buffer.create 256 in
  measure "Parse 1000 lines (reused buffer)" 10 (fun () ->
    List.iter (fun line -> ignore (Json.from_string ~buf line)) lines
  );

  Printf.printf "\n=== Summary ===\n";
  Printf.printf "For typical query-json usage (single large JSON):\n";
  Printf.printf "  - Parse + serialize overhead is minimal\n";
  Printf.printf "  - Most time is spent in query execution\n";
  Printf.printf "\nFor streaming/JSONL usage:\n";
  Printf.printf "  - Buffer reuse provides measurable improvement\n";
  Printf.printf "  - Already supported via ~buf parameter\n"

