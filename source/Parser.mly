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
%token RANGE ABS ADDFUN
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

/* %left OPEN_BRACKET */
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

str_or_id:
  | key = IDENTIFIER { Literal (String key) }
  | key = STRING { Literal (String key) }

key_val(E):
  | key = str_or_id
    { key, None }
  | OPEN_PARENT; e1 = E CLOSE_PARENT; COLON; e2 = E
    { e1, Some e2 }
  | key = str_or_id; COLON; e = E
    { key, Some e }

elif_term:
  | ELIF cond = item_expr THEN e = term
    { cond, e }

// sequence_expr handles the lowest precedence operators: comma and pipe
sequence_expr:
  | left = sequence_expr; COMMA; right = sequence_expr;
    { Comma (left, right) }

  | left = sequence_expr; PIPE; right = item_expr; // Pipe binds tighter than comma, but less than others
    { Pipe (left, right) }

  | e = item_expr
    { e }

%inline operator:
  | SUB {Sub}
  | ADD {Add}
  | MULT {Mult}
  | DIV {Div}
  | EQUAL {Eq}
  | NOT_EQUAL {Neq}
  | GREATER {Gt}
  | LOWER {St}
  | GREATER_EQUAL {Ge}
  | LOWER_EQUAL {Se}
  | AND {And}
  | OR {Or}

// item_expr handles operators with higher precedence than COMMA and PIPE
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
      let nl = List.map int_of_float nl in
      match nl with
      | [] -> assert false (* nonempty_list *)
      | x :: [] -> Range (x, None, None)
      | x :: y :: [] -> Range (x, Some y, None)
      | x :: y :: z :: [] -> Range (x, Some y, Some z)
      | _ -> failwith "too many arguments for function range"
    }
  | ABS
    { Fun (Abs) }
  | ADDFUN
    { Fun (Add) }
  | f = FUNCTION; CLOSE_PARENT;
    { failwith (f ^ "(), should contain a body") }
  | f = FUNCTION; cb = sequence_expr; CLOSE_PARENT;
    { match f with
      | "filter" -> Map (Select cb) (* for backward compatibility *)
      | "map" -> Map cb
      | "flat_map" -> FlatMap cb
      | "select" -> Select cb
      | "sort_by" -> SortBy cb
      | "min_by" -> MinBy cb
      | "max_by" -> MaxBy cb
      | "group_by" -> GroupBy cb
      | "unique_by" -> UniqueBy cb
      | "find" -> Find cb
      | "some" -> Some_ cb
      | "path" -> Path cb
      | "any" -> AnyWithCondition cb
      | "all" -> AllWithCondition cb
      | "walk" -> Walk cb
      | "transpose" -> Transpose cb
      | "has" -> Has cb
      | "in" -> In cb
      | "starts_with" -> StartsWith cb
      | "ends_with" -> EndsWith cb
      | "split" -> Split cb
      | "join" -> Join cb
      | "contains" -> Contains cb
      | "startswith" -> failwith @@ Console.Errors.renamed f "starts_with"
      | "endswith" -> failwith @@ Console.Errors.renamed f "ends_with"
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
      | "to_string" -> ToString
      | "to_num" -> ToNumber
      | "type" -> Type
      | "sort" -> Sort
      | "uniq" -> Unique
      | "reverse" -> Reverse
      | "floor" -> Floor
      | "sqrt" -> Sqrt
      | "min" -> Min
      | "max" -> Max
      | "unique" -> Unique
      | "explode" -> Explode
      | "implode" -> Implode
      | "any" -> Any
      | "all" -> All
      | "recurse" -> Recurse
      | "recurse_down" -> RecurseDown
      | "to_entries" -> ToEntries
      | "from_entries" -> FromEntries
      | "with_entries" -> WithEntries
      | "nan" -> Nan
      | "is_nan" -> IsNan
      | "not" -> Not
      (* TODO: remove failwiths once we have implemented the functions *)
      | "if" -> failwith @@ Console.Errors.not_implemented f
      | "then" -> failwith @@ Console.Errors.not_implemented f
      | "else" -> failwith @@ Console.Errors.not_implemented f
      | "break" -> failwith @@ Console.Errors.not_implemented f
      (* TODO: remove failwiths once we have implemented the functions *)
      | "isnan" -> failwith @@ Console.Errors.renamed f "is_nan"
      | "reduce" -> failwith @@ Console.Errors.renamed f "reduce()"
      | "tonumber" -> failwith @@ Console.Errors.renamed f "to_number"
      | "isinfinite" -> failwith @@ Console.Errors.renamed f "is_infinite"
      | "isfinite" -> failwith @@ Console.Errors.renamed f "is_finite"
      | "isnormal" -> failwith @@ Console.Errors.renamed f "is_normal"
      | "tostring" -> failwith @@ Console.Errors.renamed f "to_string"
      | _ -> failwith @@ Console.Errors.missing f
    }
  | OPEN_BRACKET; CLOSE_BRACKET;
    { List [] }

  // List elements are item_expr, not sequence_expr, separated by COMMA
  | e = delimited(OPEN_BRACKET, separated_nonempty_list(COMMA, item_expr), CLOSE_BRACKET);
    { List e }
  
  | OPEN_BRACE; CLOSE_BRACE;
    { Object [] }

  | e = delimited(OPEN_BRACE, separated_nonempty_list(COMMA, key_val(term)), CLOSE_BRACE);
    { Object e }

  // Parentheses allow a full sequence_expr inside, reducing to an item_expr
  | OPEN_PARENT; e = sequence_expr; CLOSE_PARENT;
    { e }
  | e = term; OPEN_BRACKET; i = number; CLOSE_BRACKET
    { Pipe (e, Index (int_of_float i)) }

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
    { Key (k, opt) }

  | e = term; DOT; k = STRING; opt = boption(QUESTION_MARK)
    { Pipe (e, Key (k, opt)) }

  | DOT; k = IDENTIFIER; opt = boption(QUESTION_MARK)
    { Key (k, opt) }

  | e = term; DOT; k = IDENTIFIER; opt = boption(QUESTION_MARK)
    { Pipe (e, Key (k, opt)) }

  | IF; cond = item_expr; THEN e1 = term; elifs = list(elif_term) ELSE; e2 = term; END
    {
      let rec fold_elif elifs else_branch =
        match elifs with
        | [] -> else_branch
        | (cond, branch) :: rest -> IfThenElse(cond, branch, fold_elif rest else_branch)
      in
      IfThenElse(cond, e1, fold_elif elifs e2)
    }
