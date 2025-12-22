/* https://jqlang.org/manual */
/* https://github.com/jqlang/jq/wiki/jq-Language-Description */
/* https://arxiv.org/pdf/2302.10576 */

%{
  open Ast
%}

%token <string> STRING
%token <float> NUMBER
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
%token RECURSE
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

(* String interpolation tokens *)
%token INTERP_START
%token <string> INTERP_TEXT
%token INTERP_EXPR_START
%token INTERP_END

%token QUESTION_MARK

%token OPEN_BRACKET
%token CLOSE_BRACKET

%token COMMA
%token OPEN_BRACE
%token CLOSE_BRACE
%token AS
%token DEF
%token EOF

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

def_param:
  | p = IDENTIFIER { p }
  | p = VARIABLE { "$" ^ p }

def_params:
  | { [] }
  | p = def_param { [p] }
  | p = def_param; SEMICOLON; rest = def_params { p :: rest }

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

  | TRY; e = sequence_expr; CATCH; handler = item_expr
    { Try (e, Some handler) }

  (* Nested function definitions within expressions *)
  | DEF; name = IDENTIFIER; COLON; body = sequence_expr; SEMICOLON; rest = sequence_expr
    { Pipe (Def (name, [], body), rest) }
  | DEF; name = IDENTIFIER; OPEN_PARENT; params = def_params; CLOSE_PARENT; COLON; body = sequence_expr; SEMICOLON; rest = sequence_expr
    { Pipe (Def (name, params, body), rest) }
  | DEF; name = FUNCTION; params = def_params; CLOSE_PARENT; COLON; body = sequence_expr; SEMICOLON; rest = sequence_expr
    { Pipe (Def (name, params, body), rest) }

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

number:
  | n = NUMBER;
    { n }
  | SUB; n = NUMBER;
    { -.n }

interp_after_expr:
  | INTERP_END
    { [] }
  | s = INTERP_TEXT; INTERP_END
    { [Literal (String s)] }
  | s = INTERP_TEXT; INTERP_EXPR_START; e = sequence_expr; rest = interp_after_expr
    { Literal (String s) :: Pipe (e, To_string) :: rest }
  | INTERP_EXPR_START; e = sequence_expr; rest = interp_after_expr
    { Pipe (e, To_string) :: rest }

interp_body:
  | INTERP_END
    { [] }
  | s = INTERP_TEXT; INTERP_END
    { [Literal (String s)] }
  | s = INTERP_TEXT; INTERP_EXPR_START; e = sequence_expr; rest = interp_after_expr
    { Literal (String s) :: Pipe (e, To_string) :: rest }
  | INTERP_EXPR_START; e = sequence_expr; rest = interp_after_expr
    { Pipe (e, To_string) :: rest }

interpolated_string:
  | INTERP_START; parts = interp_body
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
  | RECURSE;
    { Recurse }
  | s = STRING;
    { Literal (String s) }
  | interp = interpolated_string
    { interp }
  | n = number;
    { Literal (Number n) }
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
  | f = FUNCTION; arg1 = sequence_expr; SEMICOLON; arg2 = sequence_expr; SEMICOLON; arg3 = sequence_expr; CLOSE_PARENT;
    { match f with
      | "fma" -> Fma (arg1, arg2, arg3)
      | _ -> Apply (f, [arg1; arg2; arg3])
    }
  | FLATTEN;
    { Flatten None }
  | FLATTEN; OPEN_PARENT; CLOSE_PARENT;
    { Flatten None }
  | FLATTEN; OPEN_PARENT; e = sequence_expr; CLOSE_PARENT;
    { Flatten (Some e) }
  | f = FUNCTION; cond = sequence_expr; SEMICOLON; update = sequence_expr; CLOSE_PARENT;
    { match f with
      | "while" -> While (cond, update)
      | "until" -> Until (cond, update)
      | "recurse" -> Recurse_with (cond, update)
      | "try" -> Try (cond, Some update)
      | "limit" -> (
          match cond with
          | Literal (Number n) -> Limit (int_of_float n, update)
          | _ -> failwith "limit first argument must be a number literal")
      | "skip" -> (
          match cond with
          | Literal (Number n) -> Skip (int_of_float n, update)
          | _ -> failwith "skip first argument must be a number literal")
      | "sub" -> (
          match cond with
          | Literal (String pattern) -> (
              match update with
              | Literal (String replacement) -> Sub (pattern, replacement)
              | _ -> failwith "sub() second argument must be string literal")
          | _ -> failwith "sub() first argument must be string literal")
      | "gsub" -> (
          match cond with
          | Literal (String pattern) -> (
              match update with
              | Literal (String replacement) -> Gsub (pattern, replacement)
              | _ -> failwith "gsub() second argument must be string literal")
          | _ -> failwith "gsub() first argument must be string literal")
      | "any" -> Any_with_generator (cond, update)
      | "all" -> All_with_generator (cond, update)
      | "setpath" -> Setpath (cond, update)
      | "nth" -> Nth (cond, update)
      | "atan2" -> Atan2 (cond, update)
      | "atan" -> Atan2 (cond, update)
      | "copysign" -> Copysign (cond, update)
      | "ldexp" -> Ldexp (cond, update)
      | "fdim" -> Fdim (cond, update)
      | "remainder" -> Remainder (cond, update)
      | "drem" -> Remainder (cond, update)
      | "scalbn" -> Scalbn (cond, update)
      | "scalbln" -> Scalbn (cond, update)
      | "pow" -> Pow2 (cond, update)
      | "strftime" -> failwith "strftime not implemented"
      | "strptime" -> failwith "strptime not implemented"
      | "splits" -> failwith "splits not implemented (use split)"
      | "sql" -> failwith "sql not implemented"
      | "dateadd" | "datesub" -> failwith "date arithmetic not implemented"
      | "modulemeta" -> failwith "modulemeta not implemented"
      | _ -> Apply (f, [cond; update])
    }
  | f = FUNCTION; CLOSE_PARENT;
    { failwith (f ^ "(), should contain a body") }
  | f = FUNCTION; seq = sequence_expr; CLOSE_PARENT;
    { match f with
      | "filter" -> Map (Select seq)
      | "map" -> Map seq
      | "map_values" -> Map_values seq
      | "flat_map" -> Flat_map seq
      | "select" -> Select seq
      | "sort_by" -> Sort_by seq
      | "min_by" -> Min_by seq
      | "max_by" -> Max_by seq
      | "group_by" -> Group_by seq
      | "unique_by" -> Unique_by seq
      | "find" -> Find seq
      | "some" -> Some_ seq
      | "path" -> Path seq
      | "any" -> Any_with_condition seq
      | "all" -> All_with_condition seq
      | "walk" -> Walk seq
      | "has" -> Has seq
      | "in" -> In seq
      | "with_entries" -> With_entries seq
      | "startwith" -> Startwith seq
      | "startswith" -> Startwith seq
      | "starts_with" -> Starts_with seq
      | "endwith" -> Endwith seq
      | "endswith" -> Endwith seq
      | "ends_with" -> Ends_with seq
      | "index" -> Index_of seq
      | "rindex" -> Rindex_of seq
      | "indices" -> Indices seq
      | "inside" -> Inside seq
      | "ltrimstr" -> Ltrimstr seq
      | "rtrimstr" -> Rtrimstr seq
      | "split" -> Split seq
      | "join" -> Join seq
      | "contains" -> Contains seq
      | "bsearch" -> Bsearch seq
      | "first" -> First (Some seq)
      | "last" -> Last (Some seq)
      | "recurse" -> Recurse_expr seq
      | "delpaths" -> Delpaths seq
      | "combinations" -> Combinations_n seq
      | "repeat" -> Repeat seq
      | "add" -> Add_expr seq
      | "test" -> (
          match seq with
          | Literal (String pattern) -> Test pattern
          | _ -> failwith "test() requires a string literal pattern")
      | "match" -> (
          match seq with
          | Literal (String pattern) -> Match pattern
          | _ -> failwith "match() requires a string literal pattern")
      | "scan" -> (
          match seq with
          | Literal (String pattern) -> Scan pattern
          | _ -> failwith "scan() requires a string literal pattern")
      | "capture" -> (
          match seq with
          | Literal (String pattern) -> Capture pattern
          | _ -> failwith "capture() requires a string literal pattern")
      | "isempty" -> Isempty seq
      | "del" -> Del seq
      | "pick" -> Pick seq
      | "getpath" -> Getpath seq
      | "paths" -> Paths_filter seq
      | "try" -> Try (seq, None)
      | "error" -> Error_msg (Some seq)
      | "halt_error" -> (
          match seq with
          | Literal (Number n) -> Halt_error (Some (int_of_float n))
          | _ -> failwith "halt_error requires number literal")
      | "debug" -> failwith "debug not implemented"
      | "format" -> failwith "format not implemented (use @base64, @uri, etc. if available)"
      | "strftime" -> failwith "strftime not implemented"
      | "strptime" -> failwith "strptime not implemented"
      | "todateiso8601" | "fromdateiso8601" -> failwith "ISO date functions not implemented"
      | "localtime" | "gmtime" -> failwith "time zone functions not implemented"
      | "mktime" -> failwith "mktime not implemented"
      | "tojsonstream" | "fromjsonstream" | "truncate_stream" -> failwith "JSON stream functions not implemented"
      | "splits" -> failwith "splits not implemented (use split)"
      | "isvalid" -> Try (Pipe (seq, Literal (Bool true)), Some (Literal (Bool false)))
      | "tojson" | "fromjson" -> failwith "tojson/fromjson not implemented (use tostring/input is already JSON)"
      | "ascii" -> failwith "ascii not implemented"
      | "modulemeta" -> failwith "modulemeta not implemented"
      | "input" | "inputs" -> failwith "input/inputs not implemented (query-json reads all input upfront)"
      | "env" -> failwith "env() with arg not implemented (use $ENV.name or env object)"
      | "builtins" -> failwith "builtins not implemented"
      | "limit" -> failwith "limit first argument must be a number literal"
      | "until" | "while" -> failwith (f ^ " requires two arguments: condition and update")
      | _ -> Apply (f, [seq])
    }
  | REDUCE; expr = sequence_expr; AS; var = VARIABLE; OPEN_PARENT; init = sequence_expr; SEMICOLON; update = sequence_expr; CLOSE_PARENT;
    { Reduce (expr, var, init, update) }
  | FOREACH; expr = sequence_expr; AS; var = VARIABLE; OPEN_PARENT; init = sequence_expr; SEMICOLON; update = sequence_expr; SEMICOLON; extract = sequence_expr; CLOSE_PARENT;
    { Foreach (expr, var, init, update, extract) }
  | FOREACH; expr = sequence_expr; AS; var = VARIABLE; OPEN_PARENT; init = sequence_expr; SEMICOLON; update = sequence_expr; CLOSE_PARENT;
    { Foreach (expr, var, init, update, Identity) }
  | OPEN_PARENT; expr = sequence_expr; AS; var = VARIABLE; PIPE; body = sequence_expr; CLOSE_PARENT
    { As (expr, var, body) }
  | f = IDENTIFIER;
    { match f with
      | "empty" -> Empty
      | "keys" -> Keys
      | "head" -> Head
      | "tail" -> Tail
      | "length" -> Length
      | "utf8bytelength" -> Utf8bytelength
      | "tostring" -> Tostring
      | "to_string" -> To_string
      | "tonumber" -> Tonumber
      | "to_number" -> To_number
      | "type" -> Type
      | "sort" -> Sort
      | "uniq"
      | "unique" -> Unique
      | "reverse" -> Reverse
      | "floor" -> Floor
      | "sqrt" -> Sqrt
      | "min" -> Min
      | "max" -> Max
      | "explode" -> Explode
      | "implode" -> Implode
      | "any" -> Any
      | "all" -> All
      | "recurse" -> Recurse
      | "recurse_down" -> Recurse_down
      | "to_entries" -> To_entries
      | "from_entries" -> From_entries
      | "env" -> Env
      | "combinations" -> Combinations
      | "transpose" -> Transpose Identity
      | "nan" -> Nan
      | "isnan"
      | "is_nan" -> Is_nan
      | "not" -> Not
      | "ascii_upcase" -> Ascii_upcase
      | "ascii_downcase" -> Ascii_downcase
      | "trim" -> Trim
      | "ltrim" -> Ltrim
      | "rtrim" -> Rtrim
      | "first" -> First None
      | "last" -> Last None
      | "abs" -> Fun (Absolute)
      | "add" -> Fun (Add)
      | "break" -> Break
      | "paths" -> Paths
      | "error" -> Error_msg None
      | "halt" -> Halt
      | "halt_error" -> Halt_error None
      | "sin" -> Fun Sin
      | "cos" -> Fun Cos
      | "tan" -> Fun Tan
      | "asin" -> Fun Asin
      | "acos" -> Fun Acos
      | "atan" -> Fun Atan
      | "log" -> Fun Log
      | "log10" -> Fun Log10
      | "exp" -> Fun Exp
      | "pow" -> Fun Pow
      | "ceil" -> Fun Ceil
      | "round" -> Fun Round
      | "infinite" -> Fun Infinite
      | "now" -> Fun Now
      | "sinh" -> Fun Sinh
      | "cosh" -> Fun Cosh
      | "tanh" -> Fun Tanh
      | "asinh" -> Fun Asinh
      | "acosh" -> Fun Acosh
      | "atanh" -> Fun Atanh
      | "isinfinite" -> Fun Isinfinite
      | "isnormal" -> Fun Isnormal
      | "trunc" -> Fun Trunc
      | "fabs" -> Fun Fabs
      | "cbrt" -> Fun Cbrt
      | "expm1" -> Fun Expm1
      | "exp2" -> Fun Exp2
      | "log1p" -> Fun Log1p
      | "log2" -> Fun Log2
      | "nearbyint" -> Fun Nearbyint
      | "rint" -> Fun Nearbyint
      | "logb" -> Fun Logb
      (* Type selectors - equivalent to select(type == "...") *)
      | "numbers" -> Select (Operation (Type, Equal, Literal (String "number")))
      | "strings" -> Select (Operation (Type, Equal, Literal (String "string")))
      | "objects" -> Select (Operation (Type, Equal, Literal (String "object")))
      | "arrays" -> Select (Operation (Type, Equal, Literal (String "array")))
      | "booleans" -> Select (Operation (Type, Equal, Literal (String "boolean")))
      | "nulls" -> Select (Operation (Type, Equal, Literal (String "null")))
      | "iterables" -> Select (Operation (
          Operation (Type, Equal, Literal (String "array")),
          Or,
          Operation (Type, Equal, Literal (String "object"))))
      | "values" -> Select (Operation (Identity, Not_equal, Literal Null))
      | "scalars" -> Select (Operation (
          Operation (Type, Not_equal, Literal (String "array")),
          And,
          Operation (Type, Not_equal, Literal (String "object"))))
      | "input" | "inputs" -> failwith "input/inputs not implemented (query-json reads all input upfront)"
      | "debug" -> Debug
      | "stderr" -> Stderr
      | "localtime" -> Localtime
      | "gmtime" -> Gmtime
      | "mktime" -> Mktime
      | "strftime" | "strptime" -> failwith "time formatting not implemented"
      | "isvalid" -> Try (Pipe (Identity, Literal (Bool true)), Some (Literal (Bool false)))
      | "leaf_paths" -> Leaf_paths
      | "builtins" -> Builtins
      | "modulemeta" -> failwith "modulemeta not implemented"
      | "keys_unsorted" -> Keys_unsorted
      | "formats" -> Formats
      | "tojsonstream" | "fromjsonstream" | "truncate_stream" -> failwith "JSON stream functions not implemented"
      | "tojson" | "fromjson" -> failwith "tojson/fromjson not implemented (use tostring/input is already JSON)"
      | "input_filename" | "input_line_number" -> failwith "input metadata not implemented"
      | "fma" -> failwith "fma requires three arguments: fma(x; y; z)"
      | "atan2" | "copysign" | "ldexp" | "fdim" | "remainder" | "drem" | "scalbn" | "scalbln" -> failwith (f ^ " requires two arguments")
      | "frexp" | "modf" -> failwith (f ^ " not implemented (returns multiple values)")
      | "significand" | "lgamma" | "tgamma" | "j0" | "j1" | "y0" | "y1" -> failwith "special math functions not implemented"
      | "exp10" -> failwith "exp10 not implemented"
      | "getpath" -> failwith "getpath requires an argument"
      | "setpath" | "delpaths" -> failwith (f ^ " requires arguments")
      | _ -> Apply (f, [])
    }
  | OPEN_BRACKET; e = option(sequence_expr); CLOSE_BRACKET;
    { List e }

  | OPEN_BRACE; CLOSE_BRACE;
    { Object [] }

  | e = delimited(OPEN_BRACE, separated_nonempty_list(COMMA, key_value (term)), CLOSE_BRACE);
    { Object e }

  // Parentheses allow a full sequence_expr inside, reducing to an item_expr
  | OPEN_PARENT; e = sequence_expr; CLOSE_PARENT;
    { e }

  /* Index: .[0] or .[0,1,2] */
  | e = term; OPEN_BRACKET; indices = separated_nonempty_list(COMMA, number); CLOSE_BRACKET
    { Pipe (e, Index (List.map int_of_float indices)) }

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
  | e = term; OPEN_BRACKET; start = number; COLON; end_ = number; CLOSE_BRACKET
    { Pipe (e, Slice (Some (int_of_float start), Some (int_of_float end_))) }

  /* Start-only slice: .[3:] */
  | e = term; OPEN_BRACKET; start = number; COLON; CLOSE_BRACKET
    { Pipe (e, Slice (Some (int_of_float start), None)) }

  /* End-only slice: .[:3] */
  | e = term; OPEN_BRACKET; COLON; end_ = number; CLOSE_BRACKET
    { Pipe (e, Slice (None, Some (int_of_float end_))) }

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
