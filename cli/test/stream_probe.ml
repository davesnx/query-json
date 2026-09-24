let now () =
  Runtime_events.Timestamp.get_current ()
  |> Runtime_events.Timestamp.to_int64 |> Int64.to_float
  |> fun ns -> ns /. 1e9

let deadline () = now () +. 30.0

let remaining until =
  let seconds = until -. now () in
  if seconds <= 0.0 then failwith "thirty-second deadline expired";
  seconds

let rec ready until reads writes =
  let seconds = remaining until in
  match Unix.select reads writes [] seconds with
  | [], [], [] ->
      ready until reads writes
  | _ ->
      ()
  | exception Unix.Unix_error (Unix.EINTR, _, _) ->
      ready until reads writes

let write_all until fd text =
  let rec loop offset =
    if offset < String.length text then begin
      ready until [] [ fd ];
      match
        Unix.write_substring fd text offset (String.length text - offset)
      with
      | 0 ->
          failwith "zero-byte pipe write"
      | count ->
          loop (offset + count)
      | exception
          Unix.Unix_error ((Unix.EINTR | Unix.EAGAIN | Unix.EWOULDBLOCK), _, _)
        ->
          loop offset
    end
  in
  loop 0

let rec read until fd bytes =
  ready until [ fd ] [];
  match Unix.read fd bytes 0 (Bytes.length bytes) with
  | count ->
      count
  | exception
      Unix.Unix_error ((Unix.EINTR | Unix.EAGAIN | Unix.EWOULDBLOCK), _, _) ->
      read until fd bytes

let rec pause until =
  let seconds = min 0.01 (remaining until) in
  match Unix.select [] [] [] seconds with
  | _ ->
      ()
  | exception Unix.Unix_error (Unix.EINTR, _, _) ->
      pause until

let rec poll until pid =
  ignore (remaining until);
  match Unix.waitpid [ Unix.WNOHANG ] pid with
  | 0, _ ->
      None
  | _, status ->
      Some status
  | exception Unix.Unix_error (Unix.EINTR, _, _) ->
      poll until pid

let rec reap until pid =
  match poll until pid with
  | Some status ->
      status
  | None ->
      pause until;
      reap until pid

let terminate until pid =
  match poll until pid with
  | Some status ->
      status
  | None ->
      ( try Unix.kill pid Sys.sigkill
        with Unix.Unix_error (Unix.ESRCH, _, _) -> ()
      );
      reap until pid

let probe binary name raw query prefix tail expected_prefix expected =
  let descriptors = ref [] in
  let child = ref None in
  let output = Buffer.create 32 in
  let pipe () =
    let r, w = Unix.pipe ~cloexec:true () in
    descriptors := r :: w :: !descriptors;
    (r, w)
  in
  let close fd =
    if List.mem fd !descriptors then begin
      descriptors := List.filter (( <> ) fd) !descriptors;
      Unix.close fd
    end
  in
  let cleanup () =
    List.iter
      (fun fd -> try close fd with Unix.Unix_error _ -> ())
      !descriptors;
    match !child with
    | None ->
        ()
    | Some pid -> (
        let until = deadline () in
        try
          ignore (terminate until pid);
          child := None
        with exn ->
          Printf.eprintf "%s cleanup: %s\n%!" name (Printexc.to_string exn)
      )
  in
  try
    Fun.protect ~finally:cleanup (fun () ->
        let input_read, input_write = pipe () in
        let output_read, output_write = pipe () in
        let arguments =
          if raw then
            [| binary; "--no-color"; "--stream-output"; "-r"; query |]
          else
            [| binary; "--no-color"; "--stream-output"; query |]
        in
        let pid =
          Unix.create_process binary arguments input_read output_write
            Unix.stderr
        in
        child := Some pid;
        close input_read;
        close output_write;
        let until = deadline () in
        write_all until input_write prefix;
        let bytes = Bytes.create 64 in
        let rec before_eof () =
          let count = read until output_read bytes in
          if count = 0 then failwith "stdout closed before the input tail";
          Buffer.add_subbytes output bytes 0 count;
          let actual = Buffer.contents output in
          if not (String.starts_with ~prefix:actual expected_prefix) then
            failwith (Printf.sprintf "unexpected prefix %S" actual);
          if actual <> expected_prefix then before_eof ()
        in
        before_eof ();
        ( match poll until pid with
        | Some _ ->
            child := None;
            failwith "CLI exited before the input tail"
        | None ->
            ()
        );
        let first = Buffer.contents output in
        let until = deadline () in
        write_all until input_write tail;
        close input_write;
        let rec to_eof () =
          let count = read until output_read bytes in
          if count <> 0 then begin
            Buffer.add_subbytes output bytes 0 count;
            if not (String.starts_with ~prefix:(Buffer.contents output) expected)
            then
              failwith "unexpected final output";
            to_eof ()
          end
        in
        to_eof ();
        let actual = Buffer.contents output in
        if actual <> expected then failwith "incomplete final output";
        let status = reap until pid in
        child := None;
        ( match status with
        | Unix.WEXITED 0 ->
            ()
        | Unix.WEXITED code ->
            failwith (Printf.sprintf "CLI exited %d" code)
        | Unix.WSIGNALED signal ->
            failwith (Printf.sprintf "CLI signal %d" signal)
        | Unix.WSTOPPED signal ->
            failwith (Printf.sprintf "CLI stopped %d" signal)
        );
        Printf.printf "%s: before EOF %S; final %S; exit 0\n%!" name first
          actual
    )
  with exn ->
    failwith
      (Printf.sprintf "%s: %s; stdout %S" name (Printexc.to_string exn)
         (Buffer.contents output)
      )

let () =
  if Array.length Sys.argv <> 2 then
    failwith "usage: stream_probe QUERY_JSON_PATH";
  if not Sys.win32 then Sys.set_signal Sys.sigpipe Sys.Signal_ignore;
  let binary = Sys.argv.(1) in
  probe binary "root" false ".[] | (., . + 10)" "[1," "2]" "1\n11\n"
    "1\n11\n2\n12\n";
  probe binary "member" false ".rows[] | (., . + 10)" {|{"rows":[1,|}
    {|2],"tail":0}|} "1\n11\n" "1\n11\n2\n12\n";
  probe binary "raw" true {|.[] | ""|} "[1," "2]" "\n" "\n\n"
