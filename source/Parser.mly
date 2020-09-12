%{
  open Ast

  let renamed f name = "'" ^ f ^ "' is not valid in q, use '" ^ name ^ "' instead"
  let notImplemented f = "'" ^ f ^ "' is not implemented"
  let missing f = "'" ^ f ^ "' looks like a function and maybe is not implemented or missing in the parser. Either way, could you open an issue 'https://github.com/davesnx/query-json/issues/new'"
%}

%token <string> STRING
%token <float> NUMBER
%token <bool> BOOL
%token NULL
%token <string> IDENTIFIER
%token DOT
%token PIPE
%token SEMICOLON
%token ADD SUB MULT DIV
%token EQUAL NOT_EQUAL GREATER LOWER GREATER_EQUAL LOWER_EQUAL AND OR

%token <string> FUNCTION
%token CLOSE_PARENT

%token SPACE

%token QUESTION_MARK
%token EXCLAMATION_MARK
%token COMMA

%token OPEN_BRACKET
%token CLOSE_BRACKET
%token OPEN_BRACE
%token CLOSE_BRACE

%token EOF

%left OPEN_BRACKET
%left PIPE SPACE /* lowest precedence */
%left MULT DIV /* medium precedence */
%left ADD SUB /* highest precedence */

%start <Ast.expression> program

%%

program:
  | e = expr; EOF;
    { e }
  | EOF;
    { Identity }

conditional:
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
    { LowerEqual(left, right) }
  | left = expr; OR; right = expr;
    { LowerEqual(left, right) }
  | left = expr; EXCLAMATION_MARK; right = expr;
    { LowerEqual(left, right) }
  ;

path:
  /* We need both:
    String is scaped, while Identifier isn't. */
  | DOT; k = STRING; opt = boption(QUESTION_MARK)
    { Key(k, opt) }
  | DOT; k = IDENTIFIER; opt = boption(QUESTION_MARK)
    { Key(k, opt) }
  | DOT; k = STRING; opt = boption(QUESTION_MARK); rst = path
    { Pipe(Key(k, opt), rst) }
  | DOT; k = IDENTIFIER; opt = boption(QUESTION_MARK); rst = path
    { Pipe(Key(k, opt), rst) }

obj_fields: obj = separated_list(COMMA, obj_field)
  { obj }

obj_field: k = STRING; DOT; v = expr
  { (k, v) }

list_fields: vl = separated_list(COMMA, expr)
  { vl }

expr:
  | left = expr; PIPE; right = expr;
    { Pipe(left, right) }
  | left = expr; SPACE; right = expr;
    { Pipe(left, right) }
  /* Index always gots prefixed by an expr which pipes it. */
  | e = expr; OPEN_BRACKET; num = NUMBER; CLOSE_BRACKET;
    { Pipe(e, Index(int_of_float(num))) }
  | left = expr; ADD; right = expr;
    { Addition(left, right) }
  | left = expr; SUB; right = expr;
    { Subtraction(left, right) }
  | left = expr; MULT; right = expr;
    { Multiply(left, right) }
  | left = expr; DIV; right = expr;
    { Division(left, right) }
  | f = FUNCTION; from = NUMBER; SEMICOLON; upto = NUMBER; CLOSE_PARENT;
    { match f with
      | "range" -> Range(int_of_float(from), int_of_float(upto))
      | _ -> failwith(f ^ " is not a valid function")
     }
  | f = FUNCTION; cb = expr; CLOSE_PARENT;
    { match f with
      | "map" -> Map(cb)
      | "flat_map" -> FlatMap(cb)
      | "select" -> Select(cb)
      | "sort_by" -> SortBy(cb)
      | "min_by" -> MinBy(cb)
      | "max_by" -> MaxBy(cb)
      | "group_by" -> GroupBy(cb)
      | "unique_by" -> UniqueBy(cb)
      | "find" -> Find(cb)
      | "some" -> Some(cb)
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
  | e = path
    { e }
  | f = IDENTIFIER;
    { match f with
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
      | "isnan" -> IsNan
      | "reduce" -> failwith(renamed f "reduce()")
      | "tonumber" -> failwith(renamed f "to_number")
      | "isinfinite" -> failwith(renamed f "is_infinite")
      | "isfinite" -> failwith(renamed f "is_finite")
      | "isnormal" -> failwith(renamed f "is_normal")
      | "tostring" -> failwith(renamed f "to_string")
      | _ -> failwith(missing f)
    }
  | DOT;
    { Identity }
  | DOT; DOT;
    { Recurse }
  | COMMA;
    { Comma }
  | OPEN_BRACE; obj = obj_fields; CLOSE_BRACE
    { Object(obj) }
  | OPEN_BRACKET; vl = list_fields; CLOSE_BRACKET
    { List(vl) }
  | s = STRING;
    { Literal(String(s)) }
  | n = NUMBER;
    { Literal(Number(n)) }
  | b = BOOL;
    { Literal(Bool(b)) }
  | NULL
    { Literal(Null) }
  | f = FUNCTION; cond = conditional; CLOSE_PARENT;
    { match f with
    | "filter" -> Filter(cond)
    | _ -> failwith(missing f)
    }
  ;
