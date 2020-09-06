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

%token OPEN_LIST
%token CLOSE_LIST
%token OPEN_OBJ
%token CLOSE_OBJ

%token EOF

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
  | k = pair(DOT, STRING)
    { Key(snd(k)) }
  | k = pair(DOT, IDENTIFIER)
    { Key(snd(k)) }
  | k = pair(DOT, STRING); rst = path
    { Pipe(Key(snd(k)), rst) }
  | k = pair(DOT, IDENTIFIER); rst = path
    { Pipe(Key(snd(k)), rst) }

expr:
  | left = expr; PIPE; right = expr;
    { Pipe(left, right) }
  | left = expr; SPACE; right = expr;
    { Pipe(left, right) }
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
      | _ -> failwith "is not a valid function" (* TODO: Print i *)
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
      | _ -> failwith "is not a valid function" (* TODO: Print i *)
    }
  /* | path = separated_nonempty_list(KEY, expr);
    { match path with
      | key::[] -> Key(key)
      | key::keys -> Key(keys)
    } */
  | DOT; SPACE;
    { Identity }
  | OPEN_LIST; CLOSE_LIST;
    { List }
  | OPEN_OBJ; CLOSE_OBJ;
    { Object }
  | f = FUNCTION; cond = conditional; CLOSE_PARENT;
    { match f with
    | "filter" -> Filter(cond)
    | "has" -> Has(cond)
    | _ -> failwith "not a valid function"
    }
  ;
