open Ast

type stream = {
  buf : Sedlexing.lexbuf;
  mutable token : Lexer.token;
  mutable start_pos : Lexing.position;
  mutable end_pos : Lexing.position;
}

let advance stream =
  let start, _ = Sedlexing.lexing_positions stream.buf in
  let token =
    match Lexer.tokenize stream.buf with
    | Ok token ->
        token
    | Error message ->
        let err_start, stop = Sedlexing.lexing_positions stream.buf in
        let error =
          Error.lexer_error ~message ~input:"" ~start_pos:err_start.pos_cnum
            ~end_pos:stop.pos_cnum
        in
        Error.raise error err_start stop
  in
  let _, stop = Sedlexing.lexing_positions stream.buf in
  stream.token <- token;
  stream.start_pos <- start;
  stream.end_pos <- stop

let peek stream = stream.token

let expect stream expected =
  let token = stream.token in
  if token = expected then
    advance stream
  else
    let message =
      Printf.sprintf "expected %s, got %s" (Lexer.humanize expected)
        (Lexer.humanize token)
    in
    let error =
      Error.parse_error ~message ~input:"" ~start_pos:stream.start_pos.pos_cnum
        ~end_pos:stream.end_pos.pos_cnum
    in
    Error.raise error stream.start_pos stream.end_pos

let error stream message =
  let message =
    Printf.sprintf "%s, got %s" message (Lexer.humanize stream.token)
  in
  let error =
    Error.parse_error ~message ~input:"" ~start_pos:stream.start_pos.pos_cnum
      ~end_pos:stream.end_pos.pos_cnum
  in
  Error.raise error stream.start_pos stream.end_pos

let optional_question stream expr =
  match (peek stream : Lexer.token) with
  | QUESTION_MARK ->
      advance stream;
      Optional expr
  | _ ->
      expr

let unwrap_or_raise stream = function
  | Ok ast ->
      ast
  | Error error ->
      Error.raise error stream.start_pos stream.end_pos

let expect_variable stream =
  match (peek stream : Lexer.token) with
  | VARIABLE name ->
      advance stream;
      name
  | _ ->
      error stream "expected variable after 'as'"

let rec parse_binding_pattern stream : Ast.binding_pattern =
  match (peek stream : Lexer.token) with
  | VARIABLE name ->
      advance stream;
      Pat_var name
  | OPEN_BRACKET ->
      advance stream;
      let pats = parse_array_pattern stream in
      expect stream Lexer.CLOSE_BRACKET;
      Pat_array pats
  | OPEN_BRACE ->
      advance stream;
      let fields = parse_object_pattern stream in
      expect stream CLOSE_BRACE;
      Pat_object fields
  | _ ->
      error stream "expected variable, '[', or '{' in binding pattern"

and parse_array_pattern stream =
  match (peek stream : Lexer.token) with
  | CLOSE_BRACKET ->
      []
  | _ ->
      let first = parse_binding_pattern stream in
      let rec loop acc =
        match (peek stream : Lexer.token) with
        | COMMA ->
            advance stream;
            let pat = parse_binding_pattern stream in
            loop (pat :: acc)
        | _ ->
            List.rev acc
      in
      loop [ first ]

and parse_object_pattern stream =
  let parse_field () =
    match (peek stream : Lexer.token) with
    | VARIABLE name ->
        advance stream;
        (name, name)
    | IDENTIFIER key | STRING key -> (
        advance stream;
        match (peek stream : Lexer.token) with
        | COLON ->
            advance stream;
            let var = expect_variable stream in
            (key, var)
        | _ ->
            error stream "expected ':' after key in object pattern"
      )
    | _ ->
        error stream "expected variable or key in object pattern"
  in
  let first = parse_field () in
  let rec loop acc =
    match (peek stream : Lexer.token) with
    | COMMA ->
        advance stream;
        let field = parse_field () in
        loop (field :: acc)
    | _ ->
        List.rev acc
  in
  loop [ first ]

let concat_parts = function
  | [] ->
      Literal (String "")
  | [ single ] ->
      single
  | first :: rest ->
      List.fold_left (fun acc part -> Operation (acc, Add, part)) first rest

let rec parse_program stream =
  advance stream;
  match (peek stream : Lexer.token) with
  | EOF ->
      Identity
  | _ ->
      let expr = parse_sequence_expr stream in
      expect stream EOF;
      expr

and parse_sequence_expr stream = parse_fn_or_expr stream

and parse_fn_or_expr stream =
  match (peek stream : Lexer.token) with
  | FN ->
      parse_fn_def stream
  | TRY ->
      parse_try stream
  | _ ->
      parse_pipe_expr stream

and parse_fn_def stream =
  advance stream;
  let name, params =
    match (peek stream : Lexer.token) with
    | IDENTIFIER name ->
        advance stream;
        let params =
          match (peek stream : Lexer.token) with
          | OPEN_PARENT ->
              advance stream;
              let params = parse_fn_params stream in
              expect stream CLOSE_PARENT;
              params
          | _ ->
              []
        in
        (name, params)
    | FUNCTION name ->
        advance stream;
        let params = parse_fn_params stream in
        expect stream CLOSE_PARENT;
        (name, params)
    | _ ->
        error stream "expected function name after 'fn'"
  in
  expect stream COLON;
  let body = parse_sequence_expr stream in
  expect stream SEMICOLON;
  let rest =
    match (peek stream : Lexer.token) with
    | EOF | CLOSE_PARENT | CLOSE_BRACKET | CLOSE_BRACE ->
        Identity
    | _ ->
        parse_sequence_expr stream
  in
  Pipe (Fn (name, params, body), rest)

and parse_fn_params stream =
  match (peek stream : Lexer.token) with
  | CLOSE_PARENT ->
      []
  | _ ->
      let param = parse_fn_param stream in
      let rec loop acc =
        match (peek stream : Lexer.token) with
        | SEMICOLON -> (
            advance stream;
            match (peek stream : Lexer.token) with
            | CLOSE_PARENT ->
                List.rev acc
            | _ ->
                let param = parse_fn_param stream in
                loop (param :: acc)
          )
        | _ ->
            List.rev acc
      in
      loop [ param ]

and parse_fn_param stream =
  match (peek stream : Lexer.token) with
  | IDENTIFIER name ->
      advance stream;
      name
  | VARIABLE name ->
      advance stream;
      "$" ^ name
  | _ ->
      error stream "expected parameter name"

and parse_try stream =
  advance stream;
  let body = parse_sequence_expr stream in
  match (peek stream : Lexer.token) with
  | CATCH -> (
      advance stream;
      let handler = parse_item_expr stream in
      match (peek stream : Lexer.token) with
      | FINALLY ->
          advance stream;
          let cleanup = parse_item_expr stream in
          Try (body, Some handler, Some cleanup)
      | _ ->
          Try (body, Some handler, None)
    )
  | _ ->
      Try (body, None, None)

and parse_pipe_expr stream =
  let left = parse_comma_expr stream in
  parse_pipe_right stream left

and parse_pipe_right stream left =
  match (peek stream : Lexer.token) with
  | PIPE ->
      advance stream;
      let right = parse_fn_or_expr stream in
      parse_pipe_right stream (Pipe (left, right))
  | UPDATE_ASSIGN ->
      advance stream;
      let right = parse_item_expr stream in
      parse_pipe_right stream (Update (left, right))
  | ASSIGN ->
      advance stream;
      let right = parse_item_expr stream in
      parse_pipe_right stream (Assign (left, right))
  | PLUS_ASSIGN | MINUS_ASSIGN | MULT_ASSIGN | DIV_ASSIGN ->
      let op =
        match stream.token with
        | PLUS_ASSIGN ->
            Add
        | MINUS_ASSIGN ->
            Subtract
        | MULT_ASSIGN ->
            Multiply
        | _ ->
            Divide
      in
      advance stream;
      let right = parse_item_expr stream in
      parse_pipe_right stream (Update (left, Operation (Identity, op, right)))
  | ALT_ASSIGN ->
      advance stream;
      let right = parse_item_expr stream in
      parse_pipe_right stream (Update (left, Alternative (Identity, right)))
  | ALTERNATIVE ->
      advance stream;
      let right = parse_item_expr stream in
      parse_pipe_right stream (Alternative (left, right))
  | AS ->
      advance stream;
      let pat = parse_binding_pattern stream in
      expect stream PIPE;
      let body = parse_fn_or_expr stream in
      As (left, pat, body)
  | _ ->
      left

and parse_comma_expr stream =
  let left = parse_or_expr stream in
  parse_comma_right stream left

and parse_comma_right stream left =
  match (peek stream : Lexer.token) with
  | COMMA ->
      advance stream;
      let right = parse_or_expr stream in
      parse_comma_right stream (Comma (left, right))
  | _ ->
      left

and parse_or_expr stream =
  let left = parse_and_expr stream in
  parse_or_right stream left

and parse_or_right stream left =
  match (peek stream : Lexer.token) with
  | OR ->
      advance stream;
      let right = parse_and_expr stream in
      parse_or_right stream (Operation (left, Or, right))
  | _ ->
      left

and parse_and_expr stream =
  let left = parse_comparison_expr stream in
  parse_and_right stream left

and parse_and_right stream left =
  match (peek stream : Lexer.token) with
  | AND ->
      advance stream;
      let right = parse_comparison_expr stream in
      parse_and_right stream (Operation (left, And, right))
  | _ ->
      left

and parse_comparison_expr stream =
  let left = parse_add_expr stream in
  match (peek stream : Lexer.token) with
  | EQUAL | NOT_EQUAL | GREATER | LOWER | GREATER_EQUAL | LOWER_EQUAL ->
      let op =
        match stream.token with
        | EQUAL ->
            Equal
        | NOT_EQUAL ->
            Not_equal
        | GREATER ->
            Greater_than
        | LOWER ->
            Less_than
        | GREATER_EQUAL ->
            Greater_than_or_equal
        | _ ->
            Less_than_or_equal
      in
      advance stream;
      let right = parse_add_expr stream in
      Operation (left, op, right)
  | _ ->
      left

and parse_add_expr stream =
  let left = parse_mul_expr stream in
  parse_add_right stream left

and parse_add_right stream left =
  match (peek stream : Lexer.token) with
  | ADD | SUB ->
      let op = match stream.token with ADD -> Add | _ -> Subtract in
      advance stream;
      let right = parse_mul_expr stream in
      parse_add_right stream (Operation (left, op, right))
  | _ ->
      left

and parse_mul_expr stream =
  let left = parse_term stream in
  parse_mul_right stream left

and parse_mul_right stream left =
  match (peek stream : Lexer.token) with
  | MULT | DIV | MODULO ->
      let op =
        match stream.token with MULT -> Multiply | DIV -> Divide | _ -> Modulo
      in
      advance stream;
      let right = parse_term stream in
      parse_mul_right stream (Operation (left, op, right))
  | _ ->
      left

and parse_item_expr stream = parse_or_expr stream

and parse_term stream =
  let expr = parse_primary stream in
  parse_postfix stream expr

and parse_postfix stream expr =
  match (peek stream : Lexer.token) with
  | DOT -> (
      advance stream;
      match (peek stream : Lexer.token) with
      | STRING key | IDENTIFIER key ->
          advance stream;
          let access = optional_question stream (Key key) in
          parse_postfix stream (Pipe (expr, access))
      | _ ->
          error stream "expected property name after '.'"
    )
  | OPEN_BRACKET ->
      let result = parse_bracket_access stream expr in
      parse_postfix stream result
  | _ ->
      expr

and parse_bracket_access stream expr =
  advance stream;
  match (peek stream : Lexer.token) with
  | CLOSE_BRACKET ->
      advance stream;
      Pipe (expr, optional_question stream (Index []))
  | STRING key ->
      advance stream;
      expect stream CLOSE_BRACKET;
      Pipe (expr, optional_question stream (Key key))
  | VARIABLE var ->
      advance stream;
      expect stream CLOSE_BRACKET;
      Pipe (expr, Dynamic_access (Variable var))
  | COLON ->
      advance stream;
      let end_ = parse_index_number stream in
      expect stream CLOSE_BRACKET;
      Pipe (expr, Slice (None, Some end_))
  | _ -> (
      let first_num = parse_index_number stream in
      match (peek stream : Lexer.token) with
      | COLON -> (
          advance stream;
          match (peek stream : Lexer.token) with
          | CLOSE_BRACKET ->
              advance stream;
              Pipe (expr, Slice (Some first_num, None))
          | _ ->
              let end_ = parse_index_number stream in
              expect stream CLOSE_BRACKET;
              Pipe (expr, Slice (Some first_num, Some end_))
        )
      | COMMA ->
          let indices = parse_remaining_indices stream [ first_num ] in
          expect stream CLOSE_BRACKET;
          Pipe (expr, optional_question stream (Index indices))
      | CLOSE_BRACKET ->
          advance stream;
          Pipe (expr, optional_question stream (Index [ first_num ]))
      | _ ->
          error stream "expected ':', ',' or ']' in bracket expression"
    )

and parse_remaining_indices stream acc =
  match (peek stream : Lexer.token) with
  | COMMA ->
      advance stream;
      let number = parse_index_number stream in
      parse_remaining_indices stream (number :: acc)
  | _ ->
      List.rev acc

and parse_index_number stream =
  match (peek stream : Lexer.token) with
  | SUB -> (
      advance stream;
      match (peek stream : Lexer.token) with
      | INT number ->
          advance stream;
          -number
      | INT64 number ->
          advance stream;
          Int64.to_int (Int64.neg number)
      | BIG_INT number ->
          advance stream;
          Z.to_int (Z.neg number)
      | FLOAT number ->
          advance stream;
          int_of_float (-.number)
      | _ ->
          error stream "expected number after '-'"
    )
  | INT number ->
      advance stream;
      number
  | INT64 number ->
      advance stream;
      Int64.to_int number
  | BIG_INT number ->
      advance stream;
      Z.to_int number
  | FLOAT number ->
      advance stream;
      int_of_float number
  | _ ->
      error stream "expected index number"

and parse_number_literal stream =
  match (peek stream : Lexer.token) with
  | SUB -> (
      advance stream;
      match (peek stream : Lexer.token) with
      | INT number ->
          advance stream;
          Int (-number)
      | INT64 number ->
          advance stream;
          Int64 (Int64.neg number)
      | BIG_INT number ->
          advance stream;
          Big_int (Z.neg number)
      | FLOAT number ->
          advance stream;
          Float (-.number)
      | _ ->
          error stream "expected number after '-'"
    )
  | INT number ->
      advance stream;
      Int number
  | INT64 number ->
      advance stream;
      Int64 number
  | BIG_INT number ->
      advance stream;
      Big_int number
  | FLOAT number ->
      advance stream;
      Float number
  | _ ->
      error stream "expected number"

and parse_primary stream =
  match (peek stream : Lexer.token) with
  | DOT ->
      parse_dot stream
  | STRING text ->
      advance stream;
      Literal (String text)
  | INT _ | INT64 _ | BIG_INT _ | FLOAT _ | SUB ->
      Literal (parse_number_literal stream)
  | BOOL value ->
      advance stream;
      Literal (Bool value)
  | NULL ->
      advance stream;
      Literal Null
  | VARIABLE var ->
      advance stream;
      Variable var
  | INTERP initial_text ->
      parse_interpolated_string stream initial_text
  | TEMPLATE initial_text ->
      parse_template_literal stream initial_text
  | RANGE ->
      parse_range stream
  | FLATTEN ->
      parse_flatten stream
  | REDUCE ->
      parse_reduce stream
  | FOREACH ->
      parse_foreach stream
  | IF ->
      parse_if stream
  | FUNCTION name ->
      parse_function_call stream name
  | IDENTIFIER name ->
      parse_identifier stream name
  | OPEN_BRACKET ->
      parse_array_construction stream
  | OPEN_BRACE ->
      parse_object_construction stream
  | OPEN_PARENT ->
      parse_paren stream
  | _ ->
      error stream "unexpected token"

and parse_dot stream =
  advance stream;
  match (peek stream : Lexer.token) with
  | STRING key | IDENTIFIER key ->
      advance stream;
      optional_question stream (Key key)
  | OPEN_BRACKET ->
      parse_bracket_access stream Identity
  | _ ->
      Identity

and parse_range stream =
  advance stream;
  expect stream OPEN_PARENT;
  let from = parse_sequence_expr stream in
  match (peek stream : Lexer.token) with
  | CLOSE_PARENT ->
      advance stream;
      Range (from, None, None)
  | SEMICOLON -> (
      advance stream;
      let upto = parse_sequence_expr stream in
      match (peek stream : Lexer.token) with
      | CLOSE_PARENT ->
          advance stream;
          Range (from, Some upto, None)
      | SEMICOLON ->
          advance stream;
          let step = parse_sequence_expr stream in
          expect stream CLOSE_PARENT;
          Range (from, Some upto, Some step)
      | _ ->
          error stream "expected ')' or ';' in range"
    )
  | _ ->
      error stream "expected ')' or ';' in range"

and parse_flatten stream =
  advance stream;
  match (peek stream : Lexer.token) with
  | OPEN_PARENT -> (
      advance stream;
      match (peek stream : Lexer.token) with
      | CLOSE_PARENT ->
          advance stream;
          Fn0 Flatten
      | _ ->
          let expr = parse_sequence_expr stream in
          expect stream CLOSE_PARENT;
          Fn1 (With_expr (Flatten_n, expr))
    )
  | _ ->
      Fn0 Flatten

and parse_reduce stream =
  advance stream;
  let expr = parse_comma_expr stream in
  expect stream AS;
  let pat = parse_binding_pattern stream in
  expect stream OPEN_PARENT;
  let init = parse_sequence_expr stream in
  expect stream SEMICOLON;
  let update = parse_sequence_expr stream in
  expect stream CLOSE_PARENT;
  Reduce (expr, pat, init, update)

and parse_foreach stream =
  advance stream;
  let expr = parse_comma_expr stream in
  expect stream AS;
  let pat = parse_binding_pattern stream in
  expect stream OPEN_PARENT;
  let init = parse_sequence_expr stream in
  expect stream SEMICOLON;
  let update = parse_sequence_expr stream in
  match (peek stream : Lexer.token) with
  | SEMICOLON ->
      advance stream;
      let extract = parse_sequence_expr stream in
      expect stream CLOSE_PARENT;
      Foreach (expr, pat, init, update, extract)
  | CLOSE_PARENT ->
      advance stream;
      Foreach (expr, pat, init, update, Identity)
  | _ ->
      error stream "expected ';' or ')' in foreach"

and parse_if stream =
  advance stream;
  let condition = parse_item_expr stream in
  expect stream THEN;
  let then_branch = parse_sequence_expr stream in
  let elifs = parse_elifs stream in
  expect stream ELSE;
  let else_branch = parse_sequence_expr stream in
  expect stream END;
  let rec fold_elif elifs else_branch =
    match elifs with
    | [] ->
        else_branch
    | (condition, branch) :: rest ->
        If_then_else (condition, branch, fold_elif rest else_branch)
  in
  If_then_else (condition, then_branch, fold_elif elifs else_branch)

and parse_elifs stream =
  match (peek stream : Lexer.token) with
  | ELIF ->
      advance stream;
      let condition = parse_item_expr stream in
      expect stream THEN;
      let branch = parse_sequence_expr stream in
      (condition, branch) :: parse_elifs stream
  | _ ->
      []

and parse_call_rest stream fn_start name arg1 =
  match (peek stream : Lexer.token) with
  | SEMICOLON -> (
      advance stream;
      let arg2 = parse_sequence_expr stream in
      match (peek stream : Lexer.token) with
      | SEMICOLON -> (
          advance stream;
          let arg3 = parse_sequence_expr stream in
          expect stream CLOSE_PARENT;
          match name with
          | "fma" ->
              Fma (arg1, arg2, arg3)
          | _ ->
              Apply (name, [ arg1; arg2; arg3 ])
        )
      | CLOSE_PARENT ->
          advance stream;
          unwrap_or_raise
            { stream with start_pos = fn_start }
            (Language.map_binary_fn name arg1 arg2)
      | _ ->
          error stream "expected ';' or ')' in function call"
    )
  | CLOSE_PARENT ->
      advance stream;
      unwrap_or_raise
        { stream with start_pos = fn_start }
        (Language.map_unary_fn name arg1)
  | _ ->
      error stream "expected ';' or ')' in function call"

and parse_function_call stream name =
  let fn_start = stream.start_pos in
  advance stream;
  let ast =
    match (peek stream : Lexer.token) with
    | CLOSE_PARENT ->
        advance stream;
        let raise_error error = Error.raise error fn_start stream.end_pos in
        if Language.can_default_to_identity name then
          match Language.map_unary_fn name Identity with
          | Ok ast ->
              ast
          | Error error ->
              raise_error error
        else
          raise_error (Language.error_for_missing_arg name)
    | _ ->
        let arg1 = parse_sequence_expr stream in
        parse_call_rest stream fn_start name arg1
  in
  optional_question stream ast

and parse_identifier stream name =
  let fn_start = stream.start_pos in
  advance stream;
  match (peek stream : Lexer.token) with
  | QUESTION_MARK -> (
      advance stream;
      match (peek stream : Lexer.token) with
      | OPEN_PARENT ->
          advance stream;
          let arg1 = parse_sequence_expr stream in
          Optional (parse_call_rest stream fn_start name arg1)
      | _ ->
          let new_stream = { stream with start_pos = fn_start } in
          Optional (unwrap_or_raise new_stream (Language.map_nullary_fn name))
    )
  | _ ->
      let new_stream = { stream with start_pos = fn_start } in
      let ast = unwrap_or_raise new_stream (Language.map_nullary_fn name) in
      optional_question stream ast

and parse_array_construction stream =
  advance stream;
  match (peek stream : Lexer.token) with
  | CLOSE_BRACKET ->
      advance stream;
      List None
  | _ ->
      let expr = parse_sequence_expr stream in
      expect stream CLOSE_BRACKET;
      List (Some expr)

and parse_object_construction stream =
  advance stream;
  match (peek stream : Lexer.token) with
  | CLOSE_BRACE ->
      advance stream;
      Object []
  | _ ->
      let pairs = parse_key_value_list stream in
      expect stream CLOSE_BRACE;
      Object pairs

and parse_key_value_list stream =
  let pair = parse_key_value stream in
  let rec loop acc =
    match (peek stream : Lexer.token) with
    | COMMA ->
        advance stream;
        let pair = parse_key_value stream in
        loop (pair :: acc)
    | _ ->
        List.rev acc
  in
  loop [ pair ]

and parse_key_value stream =
  match (peek stream : Lexer.token) with
  | OPEN_PARENT ->
      advance stream;
      let key_expr = parse_sequence_expr stream in
      expect stream CLOSE_PARENT;
      expect stream COLON;
      let value = parse_term stream in
      (key_expr, Some value)
  | IDENTIFIER key | STRING key -> (
      advance stream;
      match (peek stream : Lexer.token) with
      | COLON ->
          advance stream;
          let value = parse_term stream in
          (Literal (String key), Some value)
      | _ ->
          (Literal (String key), None)
    )
  | _ ->
      error stream "expected key in object construction"

and parse_paren stream =
  advance stream;
  let expr = parse_sequence_expr stream in
  match (peek stream : Lexer.token) with
  | AS ->
      advance stream;
      let pat = parse_binding_pattern stream in
      expect stream PIPE;
      let body = parse_sequence_expr stream in
      expect stream CLOSE_PARENT;
      As (expr, pat, body)
  | CLOSE_PARENT ->
      advance stream;
      optional_question stream expr
  | _ ->
      error stream "expected ')' or 'as'"

and parse_interpolated_string stream initial_text =
  advance stream;
  let rec loop acc =
    let expr = parse_sequence_expr stream in
    if stream.token <> CLOSE_PARENT then
      error stream "expected ')' to close string interpolation";
    let acc = Pipe (expr, Fn0 To_string) :: acc in
    match Lexer.tokenize_string stream.buf with
    | Ok (End text) ->
        advance stream;
        let acc =
          if text = "" then
            acc
          else
            Literal (String text) :: acc
        in
        concat_parts (List.rev acc)
    | Ok (Interp text) ->
        advance stream;
        let acc =
          if text = "" then
            acc
          else
            Literal (String text) :: acc
        in
        loop acc
    | Error message ->
        error stream message
  in
  let acc =
    if initial_text = "" then
      []
    else
      [ Literal (String initial_text) ]
  in
  loop acc

and parse_template_literal stream initial_text =
  advance stream;
  let rec loop acc =
    let expr = parse_sequence_expr stream in
    if stream.token <> CLOSE_BRACE then
      error stream "expected '}' to close template expression";
    let acc = Pipe (expr, Fn0 To_string) :: acc in
    match Lexer.tokenize_template stream.buf with
    | Ok (End text) ->
        advance stream;
        let acc =
          if text = "" then
            acc
          else
            Literal (String text) :: acc
        in
        concat_parts (List.rev acc)
    | Ok (Interp text) ->
        advance stream;
        let acc =
          if text = "" then
            acc
          else
            Literal (String text) :: acc
        in
        loop acc
    | Error message ->
        error stream message
  in
  let acc =
    if initial_text = "" then
      []
    else
      [ Literal (String initial_text) ]
  in
  loop acc

let program buf =
  parse_program
    {
      buf;
      token = EOF;
      start_pos = Lexing.dummy_pos;
      end_pos = Lexing.dummy_pos;
    }
