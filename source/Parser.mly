/* https://jqlang.org/manual */
/* https://github.com/jqlang/jq/wiki/jq-Language-Description */
/* https://arxiv.org/pdf/2302.10576 */

%{
  open Ast

  let missing f =
    Formatting.single_quotes f
    ^ " looks like a function and maybe is not implemented or missing in the \
       parser. Either way, could you open an issue \
       'https://github.com/davesnx/query-json/issues/new'"
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
%token IF THEN ELSE ELIF END
%token DOT
%token RECURSE
%token PIPE
%token UPDATE_ASSIGN
%token ALTERNATIVE
%token SEMICOLON
%token COLON
%token ADD SUB MULT DIV MODULO
%token EQUAL NOT_EQUAL GREATER LOWER GREATER_EQUAL LOWER_EQUAL AND OR

%token <string> FUNCTION
%token OPEN_PARENT
%token CLOSE_PARENT

%token QUESTION_MARK

%token OPEN_BRACKET
%token CLOSE_BRACKET

%token COMMA
%token OPEN_BRACE
%token CLOSE_BRACE
%token AS
%token EOF

/* according to https://github.com/stedolan/jq/issues/1326 */
%right PIPE UPDATE_ASSIGN ALTERNATIVE /* lowest precedence */
%left COMMA
%left OR
%left AND
%nonassoc NOT_EQUAL EQUAL LOWER GREATER LOWER_EQUAL GREATER_EQUAL
%left ADD SUB
%left MULT DIV MODULO /* highest precedence */

%start <expression> program

%%

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
  | OPEN_PARENT; e1 = E CLOSE_PARENT; COLON; e2 = E
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

  | left = sequence_expr; PIPE; right = item_expr;
    { Pipe (left, right) }

  | left = sequence_expr; UPDATE_ASSIGN; right = item_expr;
    { Update (left, right) }

  | left = sequence_expr; ALTERNATIVE; right = item_expr;
    { Alternative (left, right) }

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

term:
  | DOT;
    { Identity }
  | RECURSE;
    { Recurse }
  | s = STRING;
    { Literal (String s) }
  | n = number;
    { Literal (Number n) }
  | b = BOOL;
    { Literal (Bool b) }
  | NULL
    { Literal(Null) }
  | var = VARIABLE;
    { Variable var }
  | RANGE; OPEN_PARENT; nl = separated_nonempty_list(SEMICOLON, number); CLOSE_PARENT;
    {
      match (List.map Int.of_float nl) with
      | [] -> assert false (* nonempty_list *)
      | x :: [] -> Range (x, None, None)
      | x :: y :: [] -> Range (x, Some y, None)
      | x :: y :: z :: [] -> Range (x, Some y, Some z)
      | _ -> failwith "too many arguments for function range"
    }
  | FLATTEN;
    { Flatten (Some 1) }
  | FLATTEN; OPEN_PARENT; CLOSE_PARENT;
    { Flatten (Some 1) }
  | FLATTEN; OPEN_PARENT; n = number; CLOSE_PARENT;
    { Flatten (Some (int_of_float n)) }
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
      | "setpath" -> Setpath (cond, update)
      | _ -> failwith @@ missing f
    }
  | f = FUNCTION; CLOSE_PARENT;
    { failwith (f ^ "(), should contain a body") }
  | f = FUNCTION; cb = sequence_expr; CLOSE_PARENT;
    { match f with
      | "filter" -> Map (Select cb) (* for backward compatibility *)
      | "map" -> Map cb
      | "flat_map" -> Flat_map cb
      | "select" -> Select cb
      | "sort_by" -> Sort_by cb
      | "min_by" -> Min_by cb
      | "max_by" -> Max_by cb
      | "group_by" -> Group_by cb
      | "unique_by" -> Unique_by cb
      | "find" -> Find cb
      | "some" -> Some_ cb
      | "path" -> Path cb
      | "any" -> Any_with_condition cb
      | "all" -> All_with_condition cb
      | "walk" -> Walk cb
      | "has" -> Has cb
      | "in" -> In cb
      | "with_entries" -> With_entries cb
      | "startwith" -> Startwith cb (* for backward compatibility *)
      | "startswith" -> Startwith cb (* for backward compatibility *)
      | "starts_with" -> Starts_with cb
      | "endwith" -> Endwith cb (* for backward compatibility *)
      | "endswith" -> Endwith cb (* for backward compatibility *)
      | "ends_with" -> Ends_with cb
      | "index" -> Index_of cb
      | "rindex" -> Rindex_of cb
      | "split" -> Split cb
      | "join" -> Join cb
      | "contains" -> Contains cb
      | "test" -> (
          match cb with
          | Literal (String pattern) -> Test pattern
          | _ -> failwith "test() requires a string literal pattern")
      | "match" -> (
          match cb with
          | Literal (String pattern) -> Match pattern
          | _ -> failwith "match() requires a string literal pattern")
      | "scan" -> (
          match cb with
          | Literal (String pattern) -> Scan pattern
          | _ -> failwith "scan() requires a string literal pattern")
      | "capture" -> (
          match cb with
          | Literal (String pattern) -> Capture pattern
          | _ -> failwith "capture() requires a string literal pattern")
      | "isempty" -> Isempty cb
      | "del" -> Del cb
      | "getpath" -> Getpath cb
      | "paths" -> Paths_filter cb
      | "try" -> Try (cb, None)
      | "error" -> Error_msg (Some cb)
      | "halt_error" -> (
          match cb with
          | Literal (Number n) -> Halt_error (Some (int_of_float n))
          | _ -> failwith "halt_error requires number literal")
      | _ -> failwith @@ missing f
    }
  | REDUCE; expr = sequence_expr; AS; var = VARIABLE; OPEN_PARENT; init = sequence_expr; SEMICOLON; update = sequence_expr; CLOSE_PARENT;
    { Reduce (expr, var, init, update) }
  | f = IDENTIFIER;
    { match f with
      | "empty" -> Empty
      | "keys" -> Keys
      | "head" -> Head
      | "tail" -> Tail
      | "length" -> Length
      | "tostring" -> Tostring (* for backward compatibility *)
      | "to_string" -> To_string
      | "tonumber" -> Tonumber (* for backward compatibility *)
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
      | "transpose" -> Transpose Identity
      | "nan" -> Nan
      | "isnan" (* for backward compatibility *)
      | "is_nan" -> Is_nan
      | "not" -> Not
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
      | _ -> failwith @@ missing f
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
