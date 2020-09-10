%{
  open Ast
%}

%token <string> STRING
%token <float> NUMBER
%token <bool> BOOL
%token <string> IDENTIFIER
%token DOT
%token PIPE
%token ADD SUB MULT DIV
%token EQUAL NOT_EQUAL GREATER LOWER GREATER_EQUAL LOWER_EQUAL

%token <string> FUNCTION
%token CLOSE_PARENT

%token SPACE

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
  ;

path:
  /* We need both:
    String is scaped, while Identifier isn't. */
  | DOT; k = STRING;
    { Key(k) }
  | DOT; k = IDENTIFIER;
    { Key(k) }
  | DOT; k = STRING; rst = path
    { Pipe(Key(k), rst) }
  | DOT; k = IDENTIFIER; rst = path
    { Pipe(Key(k), rst) }

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
  | s = STRING;
    { Literal(String(s)) }
  | n = NUMBER;
    { Literal(Number(n)) }
  | b = BOOL;
    { Literal(Bool(b)) }
  | f = FUNCTION; cb = expr; CLOSE_PARENT;
    { match f with
      | "map" -> Map(cb)
      | "select" -> Select(cb)
      | "sort_by" -> SortBy(cb)
      | "group_by" -> GroupBy(cb)
      | _ -> failwith(f ^ "is not a valid function")
    }
  | e = path
    { e }
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
      | _ -> failwith(i ^ "is not a valid function")
    }
  | DOT;
    { Identity }
  | OPEN_BRACKET; CLOSE_BRACKET;
    { List }
  | OPEN_BRACE; CLOSE_BRACE;
    { Object }
  | f = FUNCTION; cond = conditional; CLOSE_PARENT;
    { match f with
    | "filter" -> Filter(cond)
    | "has" -> Has(cond)
    | _ -> failwith(f ^ " is not a valid function")
    }
  ;
