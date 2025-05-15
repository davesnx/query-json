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
%token RANGE
%token IF THEN ELSE ELIF END
%token DOT
%token RECURSE
%token PIPE
%token SEMICOLON
%token COLON
%token ADD SUB MULT DIV
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
%token EOF

/* according to https://github.com/stedolan/jq/issues/1326 */
%right PIPE /* lowest precedence */
%nonassoc COMMA
%left OR
%left AND
%nonassoc NOT_EQUAL EQUAL LOWER GREATER LOWER_EQUAL GREATER_EQUAL
%left ADD SUB
%left MULT DIV /* highest precedence */

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
  | ELIF cond = item_expr THEN e = term
    { cond, e }

// sequence_expr handles the lowest precedence operators: comma and pipe
// while item_expr handles the higher precedence operators
sequence_expr:
  | left = sequence_expr; COMMA; right = sequence_expr;
    { Comma (left, right) }

  | left = sequence_expr; PIPE; right = item_expr;
    { Pipe (left, right) }

  | e = item_expr
    { e }

%inline operator:
  | SUB {Subtract}
  | ADD {Add}
  | MULT {Multiply}
  | DIV {Divide}
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
  | RANGE; OPEN_PARENT; nl = separated_nonempty_list(SEMICOLON, number); CLOSE_PARENT;
    {
      match (List.map Int.of_float nl) with
      | [] -> assert false (* nonempty_list *)
      | x :: [] -> Range (x, None, None)
      | x :: y :: [] -> Range (x, Some y, None)
      | x :: y :: z :: [] -> Range (x, Some y, Some z)
      | _ -> failwith "too many arguments for function range"
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
      | "transpose" -> Transpose cb
      | "has" -> Has cb
      | "in" -> In cb
      | "startswith" (* for backward compatibility *)
      | "starts_with" -> Starts_with cb
      | "endswith" (* for backward compatibility *)
      | "ends_with" -> Ends_with cb
      | "split" -> Split cb
      | "join" -> Join cb
      | "contains" -> Contains cb
      | _ -> failwith @@ Console.Errors.missing f
    }
  | f = IDENTIFIER;
    { match f with
      | "empty" -> Empty
      | "keys" -> Keys
      | "flatten" -> Flatten
      | "head" -> Head
      | "tail" -> Tail
      | "length" -> Length
      | "tostring" (* for backward compatibility *)
      | "to_string" -> To_string
      | "tonumber" (* for backward compatibility *)
      | "to_num" -> To_number
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
      | "with_entries" -> With_entries
      | "nan" -> Nan
      | "isnan" (* for backward compatibility *)
      | "is_nan" -> Is_nan
      | "not" -> Not
      | "abs" -> Fun (Absolute)
      | "add" -> Fun (Add)
      | _ -> failwith @@ Console.Errors.missing f
    }
  | OPEN_BRACKET; CLOSE_BRACKET;
    { List [] }

  // List elements are item_expr, not sequence_expr, separated by COMMA
  | e = delimited(OPEN_BRACKET, separated_nonempty_list(COMMA, item_expr), CLOSE_BRACKET);
    { List e }

  | OPEN_BRACE; CLOSE_BRACE;
    { Object [] }

  | e = delimited(OPEN_BRACE, separated_nonempty_list(COMMA, key_value (term)), CLOSE_BRACE);
    { Object e }

  // Parentheses allow a full sequence_expr inside, reducing to an item_expr
  | OPEN_PARENT; e = sequence_expr; CLOSE_PARENT;
    { e }

  | e = term; OPEN_BRACKET; i = number; CLOSE_BRACKET
    { Pipe (e, Index (int_of_float i)) }

  /* Iterator: .[] */
  | e = term; OPEN_BRACKET; CLOSE_BRACKET
    { Pipe (e, Iterator) }

  /* Optiona iterator: .[]? */
  | e = term; OPEN_BRACKET; CLOSE_BRACKET; QUESTION_MARK
    { Pipe (e, Optional (Iterator)) }

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

  | IF; cond = item_expr; THEN e1 = term; elifs = list(elif_term) ELSE; e2 = term; END
    {
      let rec fold_elif elifs else_branch =
        match elifs with
        | [] -> else_branch
        | (cond, branch) :: rest -> If_then_else(cond, branch, fold_elif rest else_branch)
      in
      If_then_else(cond, e1, fold_elif elifs e2)
    }
