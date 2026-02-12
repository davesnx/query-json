(* Test OxCaml features availability *)

(* Test 1: local_ mode for stack allocation *)
let test_local () =
  let local_ x = 42 in
  x + 1

(* Test 2: local_ ref *)
let test_local_ref () =
  let local_ r = ref 0 in
  r := 10;
  !r

(* Test 3: exclave_ for escaping local values *)
let test_exclave () : int =
  let local_ x = 42 in
  exclave_ x

(* Test 4: Local refs are useful for accumulators *)
let test_local_list_build () =
  let local_ acc = ref [] in
  for i = 1 to 5 do
    acc := i :: !acc
  done;
  List.rev !acc

let () =
  Printf.printf "OxCaml feature test:\n";
  Printf.printf "  local_ int: %d\n" (test_local ());
  Printf.printf "  local_ ref: %d\n" (test_local_ref ());
  Printf.printf "  exclave_: %d\n" (test_exclave ());
  Printf.printf "  local_ list build: %s\n"
    (String.concat "," (List.map string_of_int (test_local_list_build ())));
  Printf.printf "All OxCaml features working!\n"

