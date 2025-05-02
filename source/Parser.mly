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
%token DOT
%token RECURSE
%token PIPE
%token SEMICOLON
%token ADD SUB MULT DIV
%token EQUAL NOT_EQUAL GREATER LOWER GREATER_EQUAL LOWER_EQUAL AND OR

%token <string> FUNCTION
%token OPEN_PARENT
%token CLOSE_PARENT

%token QUESTION_MARK

%token OPEN_BRACKET
%token CLOSE_BRACKET

%token COMMA
%token COLON
/* %token OPEN_BRACE
%token CLOSE_BRACE */
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

// sequence_expr handles the lowest precedence operators: comma and pipe
sequence_expr:
  | left = sequence_expr; COMMA; right = sequence_expr;
    { Comma (left, right) }

  | left = sequence_expr; PIPE; right = item_expr; // Pipe binds tighter than comma, but less than others
    { Pipe (left, right) }

  | e = item_expr
    { e }

// item_expr handles operators with higher precedence than COMMA and PIPE
item_expr:
  | left = item_expr; ADD; right = item_expr;
    { Addition (left, right) }
  | left = item_expr; SUB; right = item_expr;
    { Subtraction (left, right) }
  | left = item_expr; MULT; right = item_expr;
    { Multiply (left, right) }
  | left = item_expr; DIV; right = item_expr;
    { Division (left, right) }
  | left = item_expr; EQUAL; right = item_expr;
    { Equal (left, right) }
  | left = item_expr; NOT_EQUAL; right = item_expr;
    { NotEqual (left, right) }
  | left = item_expr; GREATER; right = item_expr;
    { Greater (left, right) }
  | left = item_expr; LOWER; right = item_expr;
    { Lower (left, right) }
  | left = item_expr; GREATER_EQUAL; right = item_expr;
    { GreaterEqual (left, right) }
  | left = item_expr; LOWER_EQUAL; right = item_expr;
    { LowerEqual (left, right) }
  | left = item_expr; AND; right = item_expr;
    { And (left, right) }
  | left = item_expr; OR; right = item_expr;
    { Or (left, right) }
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
  | f = FUNCTION; from = number; SEMICOLON; upto = number; CLOSE_PARENT;
    { match f with
      | "range" -> Range (int_of_float from, int_of_float upto)
      | _ -> failwith (f ^ " is not a valid function")
     }
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
      | "in" -> In
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

  // Parentheses allow a full sequence_expr inside, reducing to an item_expr
  | OPEN_PARENT; e = sequence_expr; CLOSE_PARENT;
    { e }
  | e = term; OPEN_BRACKET; i = number; CLOSE_BRACKET
    { Pipe (e, Index (int_of_float i)) }

  /* Iterator: .[] */
  | e = term; OPEN_BRACKET; CLOSE_BRACKET
    { Pipe (e, Iterator) }

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
