%{
  open Ast;;
  open Console.Errors;;
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
%token COMMA

%token OPEN_BRACKET
%token CLOSE_BRACKET
/*
%token OPEN_BRACE
%token CLOSE_BRACE
 */
%token EOF

/* %left OPEN_BRACKET */
/* according to https://github.com/stedolan/jq/issues/1326 */
%right PIPE /* lowest precedence */
%left COMMA
%left OR
%left AND
%nonassoc NOT_EQUAL EQUAL LOWER GREATER LOWER_EQUAL GREATER_EQUAL
%left ADD SUB
%left MULT DIV /* highest precedence */

%start <expression> program

%%

program:
  | e = expr; EOF;
    { e }
  | EOF;
    { Identity }

expr:
  | left = expr; COMMA; right = expr;
    { Comma(left, right) }
  | left = expr; PIPE; right = expr;
    { Pipe(left, right) }
  | left = expr; ADD; right = expr;
    { Addition(left, right) }
  | left = expr; SUB; right = expr;
    { Subtraction(left, right) }
  | left = expr; MULT; right = expr;
    { Multiply(left, right) }
  | left = expr; DIV; right = expr;
    { Division(left, right) }
  | left = expr; EQUAL; right = expr;
    { Equal(left, right) }
  | left = expr; NOT_EQUAL; right = expr;
    { NotEqual(left, right) }
  | left = expr; GREATER; right = expr;
    { Greater(left, right) }
  | left = expr; LOWER; right = expr;
    { Lower(left, right) }
  | left = expr; GREATER_EQUAL; right = expr;
    { GreaterEqual(left, right) }
  | left = expr; LOWER_EQUAL; right = expr;
    { LowerEqual(left, right) }
  | left = expr; AND; right = expr;
    { And(left, right) }
  | left = expr; OR; right = expr;
    { Or(left, right) }
  | e = term
    { e }

term:
  | DOT;
    { Identity }
  | RECURSE;
    { Recurse }
  | s = STRING;
    { Literal(String(s)) }
  | n = NUMBER;
    { Literal(Number(n)) }
  | b = BOOL;
    { Literal(Bool(b)) }
  | NULL
    { Literal(Null) }
  | f = FUNCTION; from = NUMBER; SEMICOLON; upto = NUMBER; CLOSE_PARENT;
    { match f with
      | "range" -> Range(int_of_float(from), int_of_float(upto))
      | _ -> failwith(f ^ " is not a valid function")
     }
  | f = FUNCTION; CLOSE_PARENT;
    { failwith(f ^ "(), should contain a body") }
  | f = FUNCTION; cb = expr; CLOSE_PARENT;
    { match f with
      | "filter" -> Map(Select(cb)) (* for backward compatibility *)
      | "map" -> Map(cb)
      | "flat_map" -> FlatMap(cb)
      | "select" -> Select(cb)
      | "sort_by" -> SortBy(cb)
      | "min_by" -> MinBy(cb)
      | "max_by" -> MaxBy(cb)
      | "group_by" -> GroupBy(cb)
      | "unique_by" -> UniqueBy(cb)
      | "find" -> Find(cb)
      | "some" -> Some_(cb)
      | "path" -> Path(cb)
      | "any" -> AnyWithCondition(cb)
      | "all" -> AllWithCondition(cb)
      | "walk" -> Walk(cb)
      | "transpose" -> Transpose(cb)
      | "has" -> Has(cb)
      | "starts_with" -> StartsWith(cb)
      | "ends_with" -> EndsWith(cb)
      | "split" -> Split(cb)
      | "join" -> Join(cb)
      | "contains" -> Contains(cb)
      | "startswith" -> failwith(renamed f "starts_with")
      | "endswith" -> failwith(renamed f "ends_with")
      | _ -> failwith(missing f)
    }
  | f = IDENTIFIER;
    { match f with
      | "empty" -> Empty
      | "if" -> failwith(notImplemented f)
      | "then" -> failwith(notImplemented f)
      | "else" -> failwith(notImplemented f)
      | "break" -> failwith(notImplemented f)
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
      | "isnan" -> failwith(renamed f "is_nan")
      | "reduce" -> failwith(renamed f "reduce()")
      | "tonumber" -> failwith(renamed f "to_number")
      | "isinfinite" -> failwith(renamed f "is_infinite")
      | "isfinite" -> failwith(renamed f "is_finite")
      | "isnormal" -> failwith(renamed f "is_normal")
      | "tostring" -> failwith(renamed f "to_string")
      | _ -> failwith(missing f)
    }
  | OPEN_BRACKET; CLOSE_BRACKET;
    { List(Empty) }
  | OPEN_BRACKET; e = expr; CLOSE_BRACKET;
    { List(e) }
  | OPEN_PARENT; e = expr; CLOSE_PARENT;
    { e }
  | e = term; OPEN_BRACKET; i = NUMBER; CLOSE_BRACKET
    { Pipe(e, Index(int_of_float(i))) }

  | DOT; k = STRING; opt = boption(QUESTION_MARK)
    { Key(k, opt) }

  | e = term; DOT; k = STRING; opt = boption(QUESTION_MARK)
    { Pipe(e, Key(k, opt)) }

  | DOT; k = IDENTIFIER; opt = boption(QUESTION_MARK)
    { Key(k, opt) }

  | e = term; DOT; k = IDENTIFIER; opt = boption(QUESTION_MARK)
    { Pipe(e, Key(k, opt)) }
  ;
