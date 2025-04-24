module Location = struct
  type t = { loc_start : Lexing.position; loc_end : Lexing.position }

  let none = { loc_start = Lexing.dummy_pos; loc_end = Lexing.dummy_pos }
end

let last_position = ref Location.none

exception Lexer_error of string

let provider ~debug buf : Tokenizer.token * Lexing.position * Lexing.position =
  let start, stop = Sedlexing.lexing_positions buf in
  let token =
    match Tokenizer.tokenize buf with
    | Ok t -> t
    | Error e -> raise (Lexer_error e)
  in
  (last_position :=
     let open Location in
     { loc_start = start; loc_end = stop });
  if debug then print_endline (Tokenizer.show_token token);
  (token, start, stop)

let menhir = MenhirLib.Convert.Simplified.traditional2revised Parser.program

let parse ?(debug = false) input : (Ast.expression, string) result =
  let buf = Sedlexing.Utf8.from_string input in
  let next_token () = provider ~debug buf in
  match menhir next_token with
  | ast ->
      if debug then print_endline (Ast.show_expression ast);
      Ok ast
  | exception Lexer_error _ ->
      (* TODO: Do we want to show the lexing error differently than the parser error? *)
      let Location.{ loc_start; loc_end; _ } = !last_position in
      Error (Console.Errors.make ~input ~start:loc_start ~end_:loc_end)
  | exception _exn ->
      let Location.{ loc_start; loc_end; _ } = !last_position in
      Error (Console.Errors.make ~input ~start:loc_start ~end_:loc_end)

let run query json =
  let result =
    parse query |> Result.map Compiler.compile |> fun x ->
    Result.bind x (fun runtime ->
        match Json.parse_string json with
        | Ok input -> runtime input
        | Error err -> Error err)
  in
  match result with
  | Ok res ->
      Ok
        (res
        |> List.map (Json.to_string ~colorize:false ~summarize:false)
        |> String.concat "\n")
  | Error e -> Error e
