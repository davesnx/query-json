%{
    open Ast
%}

%token <string> STRING
%token <float> NUMBER
%token <bool> BOOL
%token DOT
%token <string> KEY
%token <string> IDENTIFIER
%token PIPE
%token ADD SUB MULT DIV
%token EQUAL GREATER_THAN LOWER_THAN GREATER_OR_EQUAL_THAN LOWER_OR_EQUAL_THAN

%token <string> FUNCTION
%token CLOSE_PARENT

%token OPEN_LIST
%token CLOSE_LIST
%token OPEN_OBJ
%token CLOSE_OBJ

%token NOT_EQUAL
%token WHITESPACE
%token EOF

%start <Ast.expression> expr

%%

/* identifiers:
  | "keys"
    { Keys }
  | "flatten"
    { Flatten }
  | "head"
    { Head }
  | "tail"
    { Tail }
  | "length"
    { Length }
  | "to_entries"
    { ToEntries }
  | "from_entries"
    { FromEntries }
  | "to_string"
    { ToString }
  | "to_num"
    { ToNumber }
  | "type"
    { Type }
  | "sort"
    { Sort }
  | "uniq"
    { Unique }
  | "reverse"
    { Reverse }
  | "starts_with"
    { StartsWith }
  | "ends_with"
    { EndsWith }
  | "split"
    { Split }
  | "join"
    { Join }
 */

expr:
  | s = STRING
    { Literal (String s) }
  | n = NUMBER
    { Literal (Number n) }
  | b = BOOL
    { Literal (Bool b) }
  | f = FUNCTION; cb = expr; CLOSE_PARENT
    { match f with
      | "map" -> Map cb
      | "select" -> Select cb
      | "sort_by" -> SortBy cb
      | "group_by" -> GroupBy cb
      | _ -> failwith "Exn"
    }
  | k = KEY
    { Key k }
  | DOT
    { Identity }
  /* | e1 = expr PIPE e2 = expr
    { Pipe (e1, e2) }
  | e1 = expr ADD e2 = expr
    { Addition (e1, e2) }
  | e1 = expr SUB e2 = expr
    { Subtraction (e1, e2) }
  | e1 = expr MULT e2 = expr
    { Multiply (e1, e2) }
  | e1 = expr DIV e2 = expr
    { Division (e1, e2) } */
  ;
