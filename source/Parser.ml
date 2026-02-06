open Ast

type stream = {
  buf : Sedlexing.lexbuf;
  mutable token : Lexer.token;
  mutable start_pos : Lexing.position;
  mutable end_pos : Lexing.position;
}

let make_stream buf =
  let s =
    {
      buf;
      token = Lexer.EOF;
      start_pos = Lexing.dummy_pos;
      end_pos = Lexing.dummy_pos;
    }
  in
  s

let advance s =
  let start, _ = Sedlexing.lexing_positions s.buf in
  let tok =
    match Lexer.tokenize s.buf with
    | Ok t -> t
    | Error e ->
        let _, stop = Sedlexing.lexing_positions s.buf in
        let err =
          Query_error.lexer_error ~message:e ~input:"" ~start_pos:start.pos_cnum
            ~end_pos:stop.pos_cnum
        in
        raise (Query_error.Parse_error (err, start, stop))
  in
  let _, stop = Sedlexing.lexing_positions s.buf in
  s.token <- tok;
  s.start_pos <- start;
  s.end_pos <- stop

let peek s = s.token

let expect s expected =
  let tok = s.token in
  if tok = expected then advance s
  else
    let msg =
      Printf.sprintf "expected %s, got %s"
        (Lexer.show_token expected)
        (Lexer.show_token tok)
    in
    let err =
      Query_error.parse_error ~message:msg ~input:""
        ~start_pos:s.start_pos.pos_cnum ~end_pos:s.end_pos.pos_cnum
    in
    raise (Query_error.Parse_error (err, s.start_pos, s.end_pos))

let error s msg =
  let err =
    Query_error.parse_error ~message:msg ~input:""
      ~start_pos:s.start_pos.pos_cnum ~end_pos:s.end_pos.pos_cnum
  in
  raise (Query_error.Parse_error (err, s.start_pos, s.end_pos))

let optional_question s =
  match peek s with
  | Lexer.QUESTION_MARK ->
      advance s;
      true
  | _ -> false

let raise_fn_error s err =
  raise (Query_error.Parse_error (err, s.start_pos, s.end_pos))

let apply_fn_result s = function
  | Ok ast -> ast
  | Error err -> raise_fn_error s err

let wrap_optional opt expr = if opt then Optional expr else expr

let rec parse_program s =
  advance s;
  match peek s with
  | Lexer.EOF -> Identity
  | _ ->
      let e = parse_sequence_expr s in
      expect s Lexer.EOF;
      e

and parse_sequence_expr s = parse_fn_or_expr s

and parse_fn_or_expr s =
  match peek s with
  | Lexer.FN -> parse_fn_def s
  | Lexer.TRY -> parse_try s
  | _ -> parse_pipe_expr s

and parse_fn_def s =
  advance s;
  match peek s with
  | Lexer.IDENTIFIER name ->
      advance s;
      let params =
        match peek s with
        | Lexer.OPEN_PARENT ->
            advance s;
            let ps = parse_fn_params s in
            expect s Lexer.CLOSE_PARENT;
            ps
        | _ -> []
      in
      expect s Lexer.COLON;
      let body = parse_sequence_expr s in
      expect s Lexer.SEMICOLON;
      let rest = parse_sequence_expr s in
      Pipe (Fn (name, params, body), rest)
  | Lexer.FUNCTION name ->
      advance s;
      let params = parse_fn_params s in
      expect s Lexer.CLOSE_PARENT;
      expect s Lexer.COLON;
      let body = parse_sequence_expr s in
      expect s Lexer.SEMICOLON;
      let rest = parse_sequence_expr s in
      Pipe (Fn (name, params, body), rest)
  | _ -> error s "expected function name after 'fn'"

and parse_fn_params s =
  match peek s with
  | Lexer.CLOSE_PARENT -> []
  | _ ->
      let p = parse_fn_param s in
      let rec loop acc =
        match peek s with
        | Lexer.SEMICOLON -> (
            advance s;
            match peek s with
            | Lexer.CLOSE_PARENT -> List.rev acc
            | _ ->
                let p = parse_fn_param s in
                loop (p :: acc))
        | _ -> List.rev acc
      in
      loop [ p ]

and parse_fn_param s =
  match peek s with
  | Lexer.IDENTIFIER name ->
      advance s;
      name
  | Lexer.VARIABLE name ->
      advance s;
      "$" ^ name
  | _ -> error s "expected parameter name"

and parse_try s =
  advance s;
  let body = parse_sequence_expr s in
  match peek s with
  | Lexer.CATCH -> (
      advance s;
      let handler = parse_item_expr s in
      match peek s with
      | Lexer.FINALLY ->
          advance s;
          let cleanup = parse_item_expr s in
          Try (body, Some handler, Some cleanup)
      | _ -> Try (body, Some handler, None))
  | _ -> body

and parse_pipe_expr s =
  let left = parse_comma_expr s in
  parse_pipe_right s left

and parse_pipe_right s left =
  match peek s with
  | Lexer.PIPE ->
      advance s;
      let right = parse_fn_or_expr s in
      parse_pipe_right s (Pipe (left, right))
  | Lexer.UPDATE_ASSIGN ->
      advance s;
      let right = parse_item_expr s in
      parse_pipe_right s (Update (left, right))
  | Lexer.ASSIGN ->
      advance s;
      let right = parse_item_expr s in
      parse_pipe_right s (Assign (left, right))
  | Lexer.PLUS_ASSIGN ->
      advance s;
      let right = parse_item_expr s in
      parse_pipe_right s (Update (left, Operation (Identity, Add, right)))
  | Lexer.MINUS_ASSIGN ->
      advance s;
      let right = parse_item_expr s in
      parse_pipe_right s (Update (left, Operation (Identity, Subtract, right)))
  | Lexer.MULT_ASSIGN ->
      advance s;
      let right = parse_item_expr s in
      parse_pipe_right s (Update (left, Operation (Identity, Multiply, right)))
  | Lexer.DIV_ASSIGN ->
      advance s;
      let right = parse_item_expr s in
      parse_pipe_right s (Update (left, Operation (Identity, Divide, right)))
  | Lexer.ALT_ASSIGN ->
      advance s;
      let right = parse_item_expr s in
      parse_pipe_right s (Update (left, Alternative (Identity, right)))
  | Lexer.ALTERNATIVE ->
      advance s;
      let right = parse_item_expr s in
      parse_pipe_right s (Alternative (left, right))
  | _ -> left

and parse_comma_expr s =
  let left = parse_or_expr s in
  parse_comma_right s left

and parse_comma_right s left =
  match peek s with
  | Lexer.COMMA ->
      advance s;
      let right = parse_or_expr s in
      parse_comma_right s (Comma (left, right))
  | _ -> left

and parse_or_expr s =
  let left = parse_and_expr s in
  parse_or_right s left

and parse_or_right s left =
  match peek s with
  | Lexer.OR ->
      advance s;
      let right = parse_and_expr s in
      parse_or_right s (Operation (left, Or, right))
  | _ -> left

and parse_and_expr s =
  let left = parse_comparison_expr s in
  parse_and_right s left

and parse_and_right s left =
  match peek s with
  | Lexer.AND ->
      advance s;
      let right = parse_comparison_expr s in
      parse_and_right s (Operation (left, And, right))
  | _ -> left

and parse_comparison_expr s =
  let left = parse_add_expr s in
  match peek s with
  | Lexer.EQUAL ->
      advance s;
      let right = parse_add_expr s in
      Operation (left, Equal, right)
  | Lexer.NOT_EQUAL ->
      advance s;
      let right = parse_add_expr s in
      Operation (left, Not_equal, right)
  | Lexer.GREATER ->
      advance s;
      let right = parse_add_expr s in
      Operation (left, Greater_than, right)
  | Lexer.LOWER ->
      advance s;
      let right = parse_add_expr s in
      Operation (left, Less_than, right)
  | Lexer.GREATER_EQUAL ->
      advance s;
      let right = parse_add_expr s in
      Operation (left, Greater_than_or_equal, right)
  | Lexer.LOWER_EQUAL ->
      advance s;
      let right = parse_add_expr s in
      Operation (left, Less_than_or_equal, right)
  | _ -> left

and parse_add_expr s =
  let left = parse_mul_expr s in
  parse_add_right s left

and parse_add_right s left =
  match peek s with
  | Lexer.ADD ->
      advance s;
      let right = parse_mul_expr s in
      parse_add_right s (Operation (left, Add, right))
  | Lexer.SUB ->
      advance s;
      let right = parse_mul_expr s in
      parse_add_right s (Operation (left, Subtract, right))
  | _ -> left

and parse_mul_expr s =
  let left = parse_term s in
  parse_mul_right s left

and parse_mul_right s left =
  match peek s with
  | Lexer.MULT ->
      advance s;
      let right = parse_term s in
      parse_mul_right s (Operation (left, Multiply, right))
  | Lexer.DIV ->
      advance s;
      let right = parse_term s in
      parse_mul_right s (Operation (left, Divide, right))
  | Lexer.MODULO ->
      advance s;
      let right = parse_term s in
      parse_mul_right s (Operation (left, Modulo, right))
  | _ -> left

and parse_item_expr s = parse_or_expr s

and parse_term s =
  let e = parse_primary s in
  parse_postfix s e

and parse_postfix s e =
  match peek s with
  | Lexer.DOT -> (
      advance s;
      match peek s with
      | Lexer.STRING k ->
          advance s;
          let opt = optional_question s in
          let access = if opt then Optional (Key k) else Key k in
          parse_postfix s (Pipe (e, access))
      | Lexer.IDENTIFIER k ->
          advance s;
          let opt = optional_question s in
          let access = if opt then Optional (Key k) else Key k in
          parse_postfix s (Pipe (e, access))
      | _ -> parse_postfix s (Pipe (e, Identity)))
  | Lexer.OPEN_BRACKET ->
      let result = parse_bracket_access s e in
      parse_postfix s result
  | _ -> e

and parse_bracket_access s e =
  advance s;
  match peek s with
  | Lexer.CLOSE_BRACKET ->
      advance s;
      let opt = optional_question s in
      let idx = Index [] in
      if opt then Pipe (e, Optional idx) else Pipe (e, idx)
  | Lexer.STRING key ->
      advance s;
      expect s Lexer.CLOSE_BRACKET;
      let opt = optional_question s in
      if opt then Pipe (e, Optional (Key key)) else Pipe (e, Key key)
  | Lexer.VARIABLE var ->
      advance s;
      expect s Lexer.CLOSE_BRACKET;
      Pipe (e, Dynamic_access (Variable var))
  | Lexer.COLON ->
      advance s;
      let end_ = parse_index_number s in
      expect s Lexer.CLOSE_BRACKET;
      Pipe (e, Slice (None, Some end_))
  | _ -> (
      let first_num = parse_index_number s in
      match peek s with
      | Lexer.COLON -> (
          advance s;
          match peek s with
          | Lexer.CLOSE_BRACKET ->
              advance s;
              Pipe (e, Slice (Some first_num, None))
          | _ ->
              let end_ = parse_index_number s in
              expect s Lexer.CLOSE_BRACKET;
              Pipe (e, Slice (Some first_num, Some end_)))
      | Lexer.COMMA ->
          let indices = parse_remaining_indices s [ first_num ] in
          expect s Lexer.CLOSE_BRACKET;
          let opt = optional_question s in
          let idx_expr = Index indices in
          if opt then Pipe (e, Optional idx_expr) else Pipe (e, idx_expr)
      | Lexer.CLOSE_BRACKET ->
          advance s;
          let opt = optional_question s in
          let idx_expr = Index [ first_num ] in
          if opt then Pipe (e, Optional idx_expr) else Pipe (e, idx_expr)
      | _ -> error s "expected ':', ',' or ']' in bracket expression")

and parse_remaining_indices s acc =
  match peek s with
  | Lexer.COMMA ->
      advance s;
      let n = parse_index_number s in
      parse_remaining_indices s (acc @ [ n ])
  | _ -> acc

and parse_index_number s =
  match peek s with
  | Lexer.SUB -> (
      advance s;
      match peek s with
      | Lexer.INT n ->
          advance s;
          -n
      | Lexer.INT64 n ->
          advance s;
          Int64.to_int (Int64.neg n)
      | Lexer.BIG_INT n ->
          advance s;
          Z.to_int (Z.neg n)
      | Lexer.FLOAT n ->
          advance s;
          int_of_float (-.n)
      | _ -> error s "expected number after '-'")
  | Lexer.INT n ->
      advance s;
      n
  | Lexer.INT64 n ->
      advance s;
      Int64.to_int n
  | Lexer.BIG_INT n ->
      advance s;
      Z.to_int n
  | Lexer.FLOAT n ->
      advance s;
      int_of_float n
  | _ -> error s "expected index number"

and parse_number_literal s =
  match peek s with
  | Lexer.SUB -> (
      advance s;
      match peek s with
      | Lexer.INT n ->
          advance s;
          Int (-n)
      | Lexer.INT64 n ->
          advance s;
          Int64 (Int64.neg n)
      | Lexer.BIG_INT n ->
          advance s;
          Big_int (Z.neg n)
      | Lexer.FLOAT n ->
          advance s;
          Float (-.n)
      | _ -> error s "expected number after '-'")
  | Lexer.INT n ->
      advance s;
      Int n
  | Lexer.INT64 n ->
      advance s;
      Int64 n
  | Lexer.BIG_INT n ->
      advance s;
      Big_int n
  | Lexer.FLOAT n ->
      advance s;
      Float n
  | _ -> error s "expected number"

and parse_primary s =
  match peek s with
  | Lexer.DOT -> parse_dot s
  | Lexer.STRING str ->
      advance s;
      Literal (String str)
  | Lexer.INT _ | Lexer.INT64 _ | Lexer.BIG_INT _ | Lexer.FLOAT _ ->
      let lit = parse_number_literal s in
      Literal lit
  | Lexer.SUB ->
      let lit = parse_number_literal s in
      Literal lit
  | Lexer.BOOL b ->
      advance s;
      Literal (Bool b)
  | Lexer.NULL ->
      advance s;
      Literal Null
  | Lexer.VARIABLE var ->
      advance s;
      Variable var
  | Lexer.INTERP_START -> parse_interpolated_string s
  | Lexer.TEMPLATE_START -> parse_template_literal s
  | Lexer.RANGE -> parse_range s
  | Lexer.FLATTEN -> parse_flatten s
  | Lexer.REDUCE -> parse_reduce s
  | Lexer.FOREACH -> parse_foreach s
  | Lexer.IF -> parse_if s
  | Lexer.FUNCTION name -> parse_function_call s name
  | Lexer.IDENTIFIER name -> parse_identifier s name
  | Lexer.OPEN_BRACKET -> parse_array_construction s
  | Lexer.OPEN_BRACE -> parse_object_construction s
  | Lexer.OPEN_PARENT -> parse_paren s
  | _ ->
      error s
        (Printf.sprintf "unexpected token: %s" (Lexer.show_token (peek s)))

and parse_dot s =
  advance s;
  match peek s with
  | Lexer.STRING k ->
      advance s;
      let opt = optional_question s in
      if opt then Optional (Key k) else Key k
  | Lexer.IDENTIFIER k ->
      advance s;
      let opt = optional_question s in
      if opt then Optional (Key k) else Key k
  | Lexer.OPEN_BRACKET -> parse_bracket_access s Identity
  | _ -> Identity

and parse_range s =
  advance s;
  expect s Lexer.OPEN_PARENT;
  let from = parse_sequence_expr s in
  match peek s with
  | Lexer.CLOSE_PARENT ->
      advance s;
      Range (from, None, None)
  | Lexer.SEMICOLON -> (
      advance s;
      let upto = parse_sequence_expr s in
      match peek s with
      | Lexer.CLOSE_PARENT ->
          advance s;
          Range (from, Some upto, None)
      | Lexer.SEMICOLON ->
          advance s;
          let step = parse_sequence_expr s in
          expect s Lexer.CLOSE_PARENT;
          Range (from, Some upto, Some step)
      | _ -> error s "expected ')' or ';' in range")
  | _ -> error s "expected ')' or ';' in range"

and parse_flatten s =
  advance s;
  match peek s with
  | Lexer.OPEN_PARENT -> (
      advance s;
      match peek s with
      | Lexer.CLOSE_PARENT ->
          advance s;
          Fn0 Flatten
      | _ ->
          let e = parse_sequence_expr s in
          expect s Lexer.CLOSE_PARENT;
          Fn1 (With_expr (Flatten_n, e)))
  | _ -> Fn0 Flatten

and parse_reduce s =
  advance s;
  let expr = parse_sequence_expr s in
  expect s Lexer.AS;
  let var =
    match peek s with
    | Lexer.VARIABLE v ->
        advance s;
        v
    | _ -> error s "expected variable after 'as'"
  in
  expect s Lexer.OPEN_PARENT;
  let init = parse_sequence_expr s in
  expect s Lexer.SEMICOLON;
  let update = parse_sequence_expr s in
  expect s Lexer.CLOSE_PARENT;
  Reduce (expr, var, init, update)

and parse_foreach s =
  advance s;
  let expr = parse_sequence_expr s in
  expect s Lexer.AS;
  let var =
    match peek s with
    | Lexer.VARIABLE v ->
        advance s;
        v
    | _ -> error s "expected variable after 'as'"
  in
  expect s Lexer.OPEN_PARENT;
  let init = parse_sequence_expr s in
  expect s Lexer.SEMICOLON;
  let update = parse_sequence_expr s in
  match peek s with
  | Lexer.SEMICOLON ->
      advance s;
      let extract = parse_sequence_expr s in
      expect s Lexer.CLOSE_PARENT;
      Foreach (expr, var, init, update, extract)
  | Lexer.CLOSE_PARENT ->
      advance s;
      Foreach (expr, var, init, update, Identity)
  | _ -> error s "expected ';' or ')' in foreach"

and parse_if s =
  advance s;
  let cond = parse_item_expr s in
  expect s Lexer.THEN;
  let then_branch = parse_sequence_expr s in
  let elifs = parse_elifs s in
  expect s Lexer.ELSE;
  let else_branch = parse_sequence_expr s in
  expect s Lexer.END;
  let rec fold_elif elifs else_b =
    match elifs with
    | [] -> else_b
    | (c, b) :: rest -> If_then_else (c, b, fold_elif rest else_b)
  in
  If_then_else (cond, then_branch, fold_elif elifs else_branch)

and parse_elifs s =
  match peek s with
  | Lexer.ELIF ->
      advance s;
      let cond = parse_item_expr s in
      expect s Lexer.THEN;
      let branch = parse_sequence_expr s in
      (cond, branch) :: parse_elifs s
  | _ -> []

and parse_function_call s name =
  let fn_start = s.start_pos in
  advance s;
  match peek s with
  | Lexer.CLOSE_PARENT ->
      advance s;
      let opt = optional_question s in
      let raise_err err =
        raise (Query_error.Parse_error (err, fn_start, s.end_pos))
      in
      let ast =
        if Language.can_default_to_identity name then
          match Language.map_unary_fn name Identity with
          | Ok a -> a
          | Error err -> raise_err err
        else raise_err (Language.error_for_missing_arg name)
      in
      wrap_optional opt ast
  | _ -> (
      let arg1 = parse_sequence_expr s in
      match peek s with
      | Lexer.SEMICOLON -> (
          advance s;
          let arg2 = parse_sequence_expr s in
          match peek s with
          | Lexer.SEMICOLON ->
              advance s;
              let arg3 = parse_sequence_expr s in
              expect s Lexer.CLOSE_PARENT;
              let opt = optional_question s in
              let ast =
                match name with
                | "fma" -> Fma (arg1, arg2, arg3)
                | _ -> Apply (name, [ arg1; arg2; arg3 ])
              in
              wrap_optional opt ast
          | Lexer.CLOSE_PARENT ->
              advance s;
              let opt = optional_question s in
              let s_proxy = { s with start_pos = fn_start } in
              let ast =
                apply_fn_result s_proxy (Language.map_binary_fn name arg1 arg2)
              in
              wrap_optional opt ast
          | _ -> error s "expected ';' or ')' in function call")
      | Lexer.CLOSE_PARENT ->
          advance s;
          let opt = optional_question s in
          let s_proxy = { s with start_pos = fn_start } in
          let ast = apply_fn_result s_proxy (Language.map_unary_fn name arg1) in
          wrap_optional opt ast
      | _ -> error s "expected ';' or ')' in function call")

and parse_identifier s name =
  let fn_start = s.start_pos in
  advance s;
  match peek s with
  | Lexer.QUESTION_MARK -> (
      advance s;
      match peek s with
      | Lexer.OPEN_PARENT -> (
          advance s;
          let arg1 = parse_sequence_expr s in
          match peek s with
          | Lexer.SEMICOLON -> (
              advance s;
              let arg2 = parse_sequence_expr s in
              match peek s with
              | Lexer.SEMICOLON ->
                  advance s;
                  let arg3 = parse_sequence_expr s in
                  expect s Lexer.CLOSE_PARENT;
                  let ast =
                    match name with
                    | "fma" -> Fma (arg1, arg2, arg3)
                    | _ -> Apply (name, [ arg1; arg2; arg3 ])
                  in
                  Optional ast
              | Lexer.CLOSE_PARENT ->
                  advance s;
                  let s_proxy = { s with start_pos = fn_start } in
                  let ast =
                    apply_fn_result s_proxy
                      (Language.map_binary_fn name arg1 arg2)
                  in
                  Optional ast
              | _ -> error s "expected ';' or ')' in optional function call")
          | Lexer.CLOSE_PARENT ->
              advance s;
              let s_proxy = { s with start_pos = fn_start } in
              let ast =
                apply_fn_result s_proxy (Language.map_unary_fn name arg1)
              in
              Optional ast
          | _ -> error s "expected ';' or ')' in optional function call")
      | _ ->
          let s_proxy = { s with start_pos = fn_start } in
          let ast = apply_fn_result s_proxy (Language.map_nullary_fn name) in
          Optional ast)
  | _ ->
      let s_proxy = { s with start_pos = fn_start } in
      let ast = apply_fn_result s_proxy (Language.map_nullary_fn name) in
      let opt = optional_question s in
      wrap_optional opt ast

and parse_array_construction s =
  advance s;
  match peek s with
  | Lexer.CLOSE_BRACKET ->
      advance s;
      List None
  | _ ->
      let e = parse_sequence_expr s in
      expect s Lexer.CLOSE_BRACKET;
      List (Some e)

and parse_object_construction s =
  advance s;
  match peek s with
  | Lexer.CLOSE_BRACE ->
      advance s;
      Object []
  | _ ->
      let pairs = parse_key_value_list s in
      expect s Lexer.CLOSE_BRACE;
      Object pairs

and parse_key_value_list s =
  let pair = parse_key_value s in
  let rec loop acc =
    match peek s with
    | Lexer.COMMA ->
        advance s;
        let pair = parse_key_value s in
        loop (pair :: acc)
    | _ -> List.rev acc
  in
  loop [ pair ]

and parse_key_value s =
  match peek s with
  | Lexer.OPEN_PARENT ->
      advance s;
      let key_expr = parse_sequence_expr s in
      expect s Lexer.CLOSE_PARENT;
      expect s Lexer.COLON;
      let value = parse_term s in
      (key_expr, Some value)
  | Lexer.IDENTIFIER key -> (
      advance s;
      match peek s with
      | Lexer.COLON ->
          advance s;
          let value = parse_term s in
          (Literal (String key), Some value)
      | _ -> (Literal (String key), None))
  | Lexer.STRING key -> (
      advance s;
      match peek s with
      | Lexer.COLON ->
          advance s;
          let value = parse_term s in
          (Literal (String key), Some value)
      | _ -> (Literal (String key), None))
  | _ -> error s "expected key in object construction"

and parse_paren s =
  advance s;
  let e = parse_sequence_expr s in
  match peek s with
  | Lexer.AS ->
      advance s;
      let var =
        match peek s with
        | Lexer.VARIABLE v ->
            advance s;
            v
        | _ -> error s "expected variable after 'as'"
      in
      expect s Lexer.PIPE;
      let body = parse_sequence_expr s in
      expect s Lexer.CLOSE_PARENT;
      As (e, var, body)
  | Lexer.CLOSE_PARENT ->
      advance s;
      let opt = optional_question s in
      wrap_optional opt e
  | _ -> error s "expected ')' or 'as'"

and parse_interpolated_string s =
  advance s;
  let parts = parse_interp_body s in
  match parts with
  | [] -> Literal (String "")
  | [ single ] -> single
  | first :: rest ->
      List.fold_left (fun acc part -> Operation (acc, Add, part)) first rest

and parse_interp_body s =
  match peek s with
  | Lexer.INTERP_END ->
      advance s;
      []
  | Lexer.INTERP_TEXT text -> (
      advance s;
      match peek s with
      | Lexer.INTERP_END ->
          advance s;
          [ Literal (String text) ]
      | Lexer.INTERP_EXPR_START ->
          advance s;
          let e = parse_sequence_expr s in
          let rest = parse_interp_after_expr s in
          Literal (String text) :: Pipe (e, Fn0 To_string) :: rest
      | _ -> error s "expected interpolation expression or end of string")
  | Lexer.INTERP_EXPR_START ->
      advance s;
      let e = parse_sequence_expr s in
      let rest = parse_interp_after_expr s in
      Pipe (e, Fn0 To_string) :: rest
  | _ -> error s "expected string interpolation content"

and parse_interp_after_expr s =
  match peek s with
  | Lexer.INTERP_END ->
      advance s;
      []
  | Lexer.INTERP_TEXT text -> (
      advance s;
      match peek s with
      | Lexer.INTERP_END ->
          advance s;
          [ Literal (String text) ]
      | Lexer.INTERP_EXPR_START ->
          advance s;
          let e = parse_sequence_expr s in
          let rest = parse_interp_after_expr s in
          Literal (String text) :: Pipe (e, Fn0 To_string) :: rest
      | _ -> error s "expected interpolation expression or end of string")
  | Lexer.INTERP_EXPR_START ->
      advance s;
      let e = parse_sequence_expr s in
      let rest = parse_interp_after_expr s in
      Pipe (e, Fn0 To_string) :: rest
  | _ -> error s "expected string interpolation content"

and parse_template_literal s =
  advance s;
  let parts = parse_template_body s in
  match parts with
  | [] -> Literal (String "")
  | [ single ] -> single
  | first :: rest ->
      List.fold_left (fun acc part -> Operation (acc, Add, part)) first rest

and parse_template_body s =
  match peek s with
  | Lexer.TEMPLATE_END ->
      advance s;
      []
  | Lexer.TEMPLATE_TEXT text -> (
      advance s;
      match peek s with
      | Lexer.TEMPLATE_END ->
          advance s;
          [ Literal (String text) ]
      | Lexer.TEMPLATE_EXPR_START ->
          advance s;
          let e = parse_sequence_expr s in
          let rest = parse_template_after_expr s in
          Literal (String text) :: Pipe (e, Fn0 To_string) :: rest
      | _ -> error s "expected template expression or end of template")
  | Lexer.TEMPLATE_EXPR_START ->
      advance s;
      let e = parse_sequence_expr s in
      let rest = parse_template_after_expr s in
      Pipe (e, Fn0 To_string) :: rest
  | _ -> error s "expected template literal content"

and parse_template_after_expr s =
  match peek s with
  | Lexer.TEMPLATE_END ->
      advance s;
      []
  | Lexer.TEMPLATE_TEXT text -> (
      advance s;
      match peek s with
      | Lexer.TEMPLATE_END ->
          advance s;
          [ Literal (String text) ]
      | Lexer.TEMPLATE_EXPR_START ->
          advance s;
          let e = parse_sequence_expr s in
          let rest = parse_template_after_expr s in
          Literal (String text) :: Pipe (e, Fn0 To_string) :: rest
      | _ -> error s "expected template expression or end of template")
  | Lexer.TEMPLATE_EXPR_START ->
      advance s;
      let e = parse_sequence_expr s in
      let rest = parse_template_after_expr s in
      Pipe (e, Fn0 To_string) :: rest
  | _ -> error s "expected template literal content"

let program buf = parse_program (make_stream buf)
