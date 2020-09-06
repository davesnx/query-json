%{
  open Ast
%}

%token <string> STRING
%token <float> NUMBER
%token <bool> BOOL
%token <string> KEY
%token <string> IDENTIFIER
%token DOT
%token PIPE
%token ADD SUB MULT DIV
%token EQUAL NOT_EQUAL GREATER LOWER GREATER_EQUAL LOWER_EQUAL

%token <string> FUNCTION
%token CLOSE_PARENT

%token OPEN_LIST
%token CLOSE_LIST
%token OPEN_OBJ
%token CLOSE_OBJ

%token EOF

%left ADD SUB /* lowest precedence */
%left MULT DIV /* medium precedence */
%nonassoc PIPE /* highest precedence */

%start <Ast.expression> program

%%

program:
  | e = expr; EOF;
    { e }
  | e1 = expr; e2 = expr; EOF;
    { Pipe(e1, e2) }
  | e1 = expr; e2 = expr; e3 = expr; EOF;
    { Pipe(e1, Pipe(e2, e3)) }
  ;

conditional:
  | e1 = expr; EQUAL; e2 = expr;
    { Equal(e1, e2) }
  | e1 = expr; NOT_EQUAL; e2 = expr;
    { NotEqual(e1, e2) }
  | e1 = expr; GREATER; e2 = expr;
    { Greater(e1, e2) }
  | e1 = expr; LOWER; e2 = expr;
    { Lower(e1, e2) }
  | e1 = expr; GREATER_EQUAL; e2 = expr;
    { GreaterEqual(e1, e2) }
  | e1 = expr; LOWER_EQUAL; e2 = expr;
    { LowerEqual(e1, e2) }
  ;

expr:
  | s = STRING;
    { Literal(String s) }
  | n = NUMBER;
    { Literal(Number n) }
  | b = BOOL;
    { Literal(Bool b) }
  | f = FUNCTION; cb = expr; CLOSE_PARENT;
    { match f with
      | "map" -> Map cb
      | "select" -> Select cb
      | "sort_by" -> SortBy cb
      | "group_by" -> GroupBy cb
      | _ -> failwith "is not a valid function"
    }
  | i = IDENTIFIER;
    { match i with
      | "keys" -> Keys
      | "flatten" -> Flatten
      | "head" -> Head
      | "tail" -> Tail
      | "length" -> Length
      | "to_entries" -> ToEntries
      | "from_entries" -> FromEntries
      | "to_string" -> ToString
      | "to_num" -> ToNumber
      | "type" -> Type
      | "sort" -> Sort
      | "uniq" -> Unique
      | "reverse" -> Reverse
      | "starts_with" -> StartsWith
      | "ends_with" -> EndsWith
      | "split" -> Split
      | "join" -> Join
      | _ -> failwith "is not a valid function"
    }
  | k = KEY;
    { Key k }
  | DOT;
    { Identity }
  | e1 = expr; PIPE; e2 = expr;
    { Pipe(e1, e2) }
  | OPEN_LIST; CLOSE_LIST;
    { List }
  | OPEN_OBJ; CLOSE_OBJ;
    { Object }
  | e1 = expr; ADD; e2 = expr;
    { Addition(e1, e2) }
  | e1 = expr; SUB; e2 = expr;
    { Subtraction(e1, e2) }
  | e1 = expr; MULT; e2 = expr;
    { Multiply(e1, e2) }
  | e1 = expr; DIV; e2 = expr;
    { Division(e1, e2) }
  | f = FUNCTION; cond = conditional; CLOSE_PARENT;
    { match f with
    | "filter" -> Filter(cond)
    | "has" -> Has(cond)
    | _ -> failwith "not a valid function"
    }
  ;
