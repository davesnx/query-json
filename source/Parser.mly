%{
  open Ast
%}

%token <string> STRING
%token <int> INT
%token <int64> INT64
%token <Z.t> BIG_INT
%token <float> FLOAT
%token <bool> BOOL
%token NULL
%token <string> IDENTIFIER
%token <string> VARIABLE
%token RANGE
%token FLATTEN
%token REDUCE
%token FOREACH
%token IF THEN ELSE ELIF END
%token DOT
%token PIPE
%token UPDATE_ASSIGN
%token PLUS_ASSIGN
%token MINUS_ASSIGN
%token MULT_ASSIGN
%token DIV_ASSIGN
%token ALT_ASSIGN
%token ASSIGN
%token ALTERNATIVE
%token SEMICOLON
%token COLON
%token ADD SUB MULT DIV MODULO
%token EQUAL NOT_EQUAL GREATER LOWER GREATER_EQUAL LOWER_EQUAL AND OR

%token <string> FUNCTION
%token OPEN_PARENT
%token CLOSE_PARENT
%token TRY
%token CATCH
%token FINALLY

(* String interpolation tokens *)
%token INTERP_START
%token <string> INTERP_TEXT
%token INTERP_EXPR_START
%token INTERP_END

(* Template literal tokens (backtick strings) *)
%token TEMPLATE_START
%token <string> TEMPLATE_TEXT
%token TEMPLATE_EXPR_START
%token TEMPLATE_END

%token QUESTION_MARK

%token OPEN_BRACKET
%token CLOSE_BRACKET

%token COMMA
%token OPEN_BRACE
%token CLOSE_BRACE
%token AS
%token FN
%token EOF

/* FN_PREC is a dummy precedence for function definitions - must be lower than PIPE and others so that operators are shifted into the 'rest' expression: fn f: body; rest | x
   should parse as: fn f: body; (rest | x) */
%nonassoc FN_PREC
/* according to https://github.com/stedolan/jq/issues/1326 */
%right PIPE UPDATE_ASSIGN PLUS_ASSIGN MINUS_ASSIGN MULT_ASSIGN DIV_ASSIGN ALT_ASSIGN ASSIGN ALTERNATIVE /* lowest precedence */
%left COMMA
%left OR
%left AND
%nonassoc NOT_EQUAL EQUAL LOWER GREATER LOWER_EQUAL GREATER_EQUAL
%left ADD SUB
%left MULT DIV MODULO /* highest precedence */

%start <expression> program

%%

fn_param:
  | p = IDENTIFIER { p }
  | p = VARIABLE { "$" ^ p }

fn_params:
  | { [] }
  | p = fn_param { [p] }
  | p = fn_param; SEMICOLON; rest = fn_params { p :: rest }

program:
  | e = sequence_expr; EOF;
    { e }
  | EOF;
    { Identity }

string_or_identifier:
  | key = IDENTIFIER { Literal (String key) }
  | key = STRING { Literal (String key) }

key_value (E):
  | key = string_or_identifier
    { key, None }
  | OPEN_PARENT; e1 = sequence_expr CLOSE_PARENT; COLON; e2 = E
    { e1, Some e2 }
  | key = string_or_identifier; COLON; e = E
    { key, Some e }

elif_term:
  | ELIF cond = item_expr THEN e = sequence_expr
    { cond, e }

// sequence_expr handles the lowest precedence operators: comma and pipe
// while item_expr handles the higher precedence operators
sequence_expr:
  | left = sequence_expr; COMMA; right = sequence_expr;
    { Comma (left, right) }

  | left = sequence_expr; PIPE; right = sequence_expr;
    { Pipe (left, right) }

  | left = sequence_expr; UPDATE_ASSIGN; right = item_expr;
    { Update (left, right) }

  | left = sequence_expr; ASSIGN; right = item_expr;
    { Assign (left, right) }

  | left = sequence_expr; PLUS_ASSIGN; right = item_expr;
    { Update (left, Operation (Identity, Add, right)) }

  | left = sequence_expr; MINUS_ASSIGN; right = item_expr;
    { Update (left, Operation (Identity, Subtract, right)) }

  | left = sequence_expr; MULT_ASSIGN; right = item_expr;
    { Update (left, Operation (Identity, Multiply, right)) }

  | left = sequence_expr; DIV_ASSIGN; right = item_expr;
    { Update (left, Operation (Identity, Divide, right)) }

  | left = sequence_expr; ALT_ASSIGN; right = item_expr;
    { Update (left, Alternative (Identity, right)) }

  | left = sequence_expr; ALTERNATIVE; right = item_expr;
    { Alternative (left, right) }

  | TRY; e = sequence_expr; CATCH; handler = item_expr; FINALLY; cleanup = item_expr
    { Try (e, Some handler, Some cleanup) }

  | TRY; e = sequence_expr; CATCH; handler = item_expr
    { Try (e, Some handler, None) }

  (* Nested function definitions within expressions *)
  | FN; name = IDENTIFIER; COLON; body = sequence_expr; SEMICOLON; rest = sequence_expr %prec FN_PREC
    { Pipe (Fn (name, [], body), rest) }
  | FN; name = IDENTIFIER; OPEN_PARENT; params = fn_params; CLOSE_PARENT; COLON; body = sequence_expr; SEMICOLON; rest = sequence_expr %prec FN_PREC
    { Pipe (Fn (name, params, body), rest) }
  | FN; name = FUNCTION; params = fn_params; CLOSE_PARENT; COLON; body = sequence_expr; SEMICOLON; rest = sequence_expr %prec FN_PREC
    { Pipe (Fn (name, params, body), rest) }

  | e = item_expr
    { e }

%inline operator:
  | SUB {Subtract}
  | ADD {Add}
  | MULT {Multiply}
  | DIV {Divide}
  | MODULO {Modulo}
  | EQUAL {Equal}
  | NOT_EQUAL {Not_equal}
  | GREATER {Greater_than}
  | LOWER {Less_than}
  | GREATER_EQUAL {Greater_than_or_equal}
  | LOWER_EQUAL {Less_than_or_equal}
  | AND {And}
  | OR {Or}

item_expr:
  | left = item_expr; op = operator; right = item_expr;
    { Operation (left, op, right) }

  | e = term
    { e }

(* number_literal returns an Ast.literal for use in expressions *)
number_literal:
  | n = INT;
    { Int n }
  | SUB; n = INT;
    { Int (-n) }
  | n = INT64;
    { Int64 n }
  | SUB; n = INT64;
    { Int64 (Int64.neg n) }
  | n = BIG_INT;
    { Big_int n }
  | SUB; n = BIG_INT;
    { Big_int (Z.neg n) }
  | n = FLOAT;
    { Float n }
  | SUB; n = FLOAT;
    { Float (-.n) }

(* index_number returns an int for array indexing *)
index_number:
  | n = INT;
    { n }
  | SUB; n = INT;
    { -n }
  | n = INT64;
    { Int64.to_int n }
  | SUB; n = INT64;
    { Int64.to_int (Int64.neg n) }
  | n = BIG_INT;
    { Z.to_int n }
  | SUB; n = BIG_INT;
    { Z.to_int (Z.neg n) }
  | n = FLOAT;
    { int_of_float n }
  | SUB; n = FLOAT;
    { int_of_float (-.n) }

interp_after_expr:
  | INTERP_END
    { [] }
  | s = INTERP_TEXT; INTERP_END
    { [Literal (String s)] }
  | s = INTERP_TEXT; INTERP_EXPR_START; e = sequence_expr; rest = interp_after_expr
    { Literal (String s) :: Pipe (e, Fn0 To_string) :: rest }
  | INTERP_EXPR_START; e = sequence_expr; rest = interp_after_expr
    { Pipe (e, Fn0 To_string) :: rest }

interp_body:
  | INTERP_END
    { [] }
  | s = INTERP_TEXT; INTERP_END
    { [Literal (String s)] }
  | s = INTERP_TEXT; INTERP_EXPR_START; e = sequence_expr; rest = interp_after_expr
    { Literal (String s) :: Pipe (e, Fn0 To_string) :: rest }
  | INTERP_EXPR_START; e = sequence_expr; rest = interp_after_expr
    { Pipe (e, Fn0 To_string) :: rest }

interpolated_string:
  | INTERP_START; parts = interp_body
    {
      match parts with
      | [] -> Literal (String "")
      | [single] -> single
      | first :: rest ->
          List.fold_left (fun acc part -> Operation (acc, Add, part)) first rest
    }

template_after_expr:
  | TEMPLATE_END
    { [] }
  | s = TEMPLATE_TEXT; TEMPLATE_END
    { [Literal (String s)] }
  | s = TEMPLATE_TEXT; TEMPLATE_EXPR_START; e = sequence_expr; rest = template_after_expr
    { Literal (String s) :: Pipe (e, Fn0 To_string) :: rest }
  | TEMPLATE_EXPR_START; e = sequence_expr; rest = template_after_expr
    { Pipe (e, Fn0 To_string) :: rest }

template_body:
  | TEMPLATE_END
    { [] }
  | s = TEMPLATE_TEXT; TEMPLATE_END
    { [Literal (String s)] }
  | s = TEMPLATE_TEXT; TEMPLATE_EXPR_START; e = sequence_expr; rest = template_after_expr
    { Literal (String s) :: Pipe (e, Fn0 To_string) :: rest }
  | TEMPLATE_EXPR_START; e = sequence_expr; rest = template_after_expr
    { Pipe (e, Fn0 To_string) :: rest }

template_literal:
  | TEMPLATE_START; parts = template_body
    {
      match parts with
      | [] -> Literal (String "")
      | [single] -> single
      | first :: rest ->
          List.fold_left (fun acc part -> Operation (acc, Add, part)) first rest
    }

term:
  | DOT;
    { Identity }
  | s = STRING;
    { Literal (String s) }
  | interp = interpolated_string
    { interp }
  | template = template_literal
    { template }
  | n = number_literal;
    { Literal n }
  | b = BOOL;
    { Literal (Bool b) }
  | NULL
    { Literal(Null) }
  | var = VARIABLE;
    { Variable var }
  | RANGE; OPEN_PARENT; from = sequence_expr; CLOSE_PARENT;
    { Range (from, None, None) }
  | RANGE; OPEN_PARENT; from = sequence_expr; SEMICOLON; upto = sequence_expr; CLOSE_PARENT;
    { Range (from, Some upto, None) }
  | RANGE; OPEN_PARENT; from = sequence_expr; SEMICOLON; upto = sequence_expr; SEMICOLON; step = sequence_expr; CLOSE_PARENT;
    { Range (from, Some upto, Some step) }
  | f = FUNCTION; arg1 = sequence_expr; SEMICOLON; arg2 = sequence_expr; SEMICOLON; arg3 = sequence_expr; CLOSE_PARENT; opt = boption(QUESTION_MARK)
    { let ast = match f with
        | "fma" -> Fma (arg1, arg2, arg3)
        | _ -> Apply (f, [arg1; arg2; arg3])
      in
      match opt with
      | true -> Optional ast
      | false -> ast
    }
  | FLATTEN;
    { Fn0 Flatten }
  | FLATTEN; OPEN_PARENT; CLOSE_PARENT;
    { Fn0 Flatten }
  | FLATTEN; OPEN_PARENT; e = sequence_expr; CLOSE_PARENT;
    { Fn1 (With_expr (Flatten_n, e)) }
  | f = FUNCTION; arg1 = sequence_expr; SEMICOLON; arg2 = sequence_expr; CLOSE_PARENT; opt = boption(QUESTION_MARK)
    { let ast = match Language.map_binary_fn f arg1 arg2 with
        | Ok ast -> ast
        | Error err -> Parse_errors.raise_rich_error err $startpos(arg1) $endpos(arg2)
      in
      match opt with
      | true -> Optional ast
      | false -> ast
    }
  | f = FUNCTION; CLOSE_PARENT; opt = boption(QUESTION_MARK)
    { (* Check if this 1-arity function can default to identity *)
      let ast =
        if Language.can_default_to_identity f then
          match Language.map_unary_fn f Identity with
          | Ok ast -> ast
          | Error err -> Parse_errors.raise_rich_error err $startpos(f) $endpos(f)
        else
          Parse_errors.raise_rich_error (Language.error_for_missing_arg f) $startpos(f) $endpos(f)
      in
      match opt with
      | true -> Optional ast
      | false -> ast
    }
  | f = FUNCTION; arg = sequence_expr; CLOSE_PARENT; opt = boption(QUESTION_MARK)
    { let ast = match Language.map_unary_fn f arg with
        | Ok ast -> ast
        | Error err -> Parse_errors.raise_rich_error err $startpos(arg) $endpos(arg)
      in
      match opt with
      | true -> Optional ast
      | false -> ast
    }
  | REDUCE; expr = sequence_expr; AS; var = VARIABLE; OPEN_PARENT; init = sequence_expr; SEMICOLON; update = sequence_expr; CLOSE_PARENT;
    { Reduce (expr, var, init, update) }
  | FOREACH; expr = sequence_expr; AS; var = VARIABLE; OPEN_PARENT; init = sequence_expr; SEMICOLON; update = sequence_expr; SEMICOLON; extract = sequence_expr; CLOSE_PARENT;
    { Foreach (expr, var, init, update, extract) }
  | FOREACH; expr = sequence_expr; AS; var = VARIABLE; OPEN_PARENT; init = sequence_expr; SEMICOLON; update = sequence_expr; CLOSE_PARENT;
    { Foreach (expr, var, init, update, Identity) }
  | OPEN_PARENT; expr = sequence_expr; AS; var = VARIABLE; PIPE; body = sequence_expr; CLOSE_PARENT
    { As (expr, var, body) }
  | f = IDENTIFIER; opt = boption(QUESTION_MARK)
    { let ast = match Language.map_nullary_fn f with
        | Ok ast -> ast
        | Error err -> Parse_errors.raise_rich_error err $startpos(f) $endpos(f)
      in
      match opt with
      | true -> Optional ast
      | false -> ast
    }
  (* Optional function call: first?(expr) is equivalent to first(expr)? *)
  | f = IDENTIFIER; QUESTION_MARK; OPEN_PARENT; arg = sequence_expr; CLOSE_PARENT
    { let ast = match Language.map_unary_fn f arg with
        | Ok ast -> ast
        | Error err -> Parse_errors.raise_rich_error err $startpos(arg) $endpos(arg)
      in
      Optional ast
    }
  (* Optional function call with two args: nth?(n; expr) *)
  | f = IDENTIFIER; QUESTION_MARK; OPEN_PARENT; arg1 = sequence_expr; SEMICOLON; arg2 = sequence_expr; CLOSE_PARENT
    { let ast = match Language.map_binary_fn f arg1 arg2 with
        | Ok ast -> ast
        | Error err -> Parse_errors.raise_rich_error err $startpos(arg1) $endpos(arg2)
      in
      Optional ast
    }
  (* Optional function call with three args: fn?(a; b; c) *)
  | f = IDENTIFIER; QUESTION_MARK; OPEN_PARENT; arg1 = sequence_expr; SEMICOLON; arg2 = sequence_expr; SEMICOLON; arg3 = sequence_expr; CLOSE_PARENT
    { let ast = match f with
        | "fma" -> Fma (arg1, arg2, arg3)
        | _ -> Apply (f, [arg1; arg2; arg3])
      in
      Optional ast
    }
  | OPEN_BRACKET; e = option(sequence_expr); CLOSE_BRACKET;
    { List e }

  | OPEN_BRACE; CLOSE_BRACE;
    { Object [] }

  | e = delimited(OPEN_BRACE, separated_nonempty_list(COMMA, key_value (term)), CLOSE_BRACE);
    { Object e }

  | OPEN_PARENT; e = sequence_expr; CLOSE_PARENT; opt = boption(QUESTION_MARK)
    { match opt with
      | true -> Optional e
      | false -> e
    }

  /* Index: .[0] or .[0,1,2], optionally with ? for optional access */
  | e = term; OPEN_BRACKET; indices = separated_nonempty_list(COMMA, index_number); CLOSE_BRACKET; opt = boption(QUESTION_MARK)
    { let idx_expr = Index indices in
      match opt with
      | true -> Pipe (e, Optional idx_expr)
      | false -> Pipe (e, idx_expr) }

  /* String key access: .["foo"] */
  | e = term; OPEN_BRACKET; key = STRING; CLOSE_BRACKET
    { Pipe (e, Key key) }

  /* Optional string key access: .["foo"]? */
  | e = term; OPEN_BRACKET; key = STRING; CLOSE_BRACKET; QUESTION_MARK
    { Pipe (e, Optional (Key key)) }

  /* Dynamic access with variable: .[$var] */
  | e = term; OPEN_BRACKET; var = VARIABLE; CLOSE_BRACKET
    { Pipe (e, Dynamic_access (Variable var)) }

  /* Empty brackets: .[] */
  | e = term; OPEN_BRACKET; CLOSE_BRACKET
    { Pipe (e, Index []) }

  /* Optional iterator: .[]? */
  | e = term; OPEN_BRACKET; CLOSE_BRACKET; QUESTION_MARK
    { Pipe (e, Optional (Index [])) }

  /* Full slice with both indices: .[1:5] */
  | e = term; OPEN_BRACKET; start = index_number; COLON; end_ = index_number; CLOSE_BRACKET
    { Pipe (e, Slice (Some start, Some end_)) }

  /* Start-only slice: .[3:] */
  | e = term; OPEN_BRACKET; start = index_number; COLON; CLOSE_BRACKET
    { Pipe (e, Slice (Some start, None)) }

  /* End-only slice: .[:3] */
  | e = term; OPEN_BRACKET; COLON; end_ = index_number; CLOSE_BRACKET
    { Pipe (e, Slice (None, Some end_)) }

  | DOT; k = STRING; opt = boption(QUESTION_MARK)
  | DOT; k = IDENTIFIER; opt = boption(QUESTION_MARK)
    { match opt with
      | true -> Optional (Key k)
      | false -> Key k
    }

  | e = term; DOT; k = STRING; opt = boption(QUESTION_MARK)
  | e = term; DOT; k = IDENTIFIER; opt = boption(QUESTION_MARK)
    { match opt with
      | true -> Pipe (e, Optional (Key k))
      | false -> Pipe (e, Key k)
    }

  | IF; cond = item_expr; THEN e1 = sequence_expr; elifs = list(elif_term) ELSE; e2 = sequence_expr; END
    {
      let rec fold_elif elifs else_branch =
        match elifs with
        | [] -> else_branch
        | (cond, branch) :: rest -> If_then_else(cond, branch, fold_elif rest else_branch)
      in
      If_then_else(cond, e1, fold_elif elifs e2)
    }
