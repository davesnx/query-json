%{
    open Ast
%}

%token <string> STRING
%token <float> NUMBER
%token <bool> BOOL
%token DOT
%token <string> KEY
/* %token <string> IDENTIFIER */
%token PIPE
%token ADD SUB MULT DIV
%token EQUAL GREATER_THAN LOWER_THAN GREATER_OR_EQUAL_THAN LOWER_OR_EQUAL_THAN

/*
%token <string> FUNCTION
%token CLOSE_PARENT
*/

/*
%token OPEN_LIST
%token CLOSE_LIST
%token OPEN_OBJ
%token CLOSE_OBJ
 */

%start <Ast.expression> expr

%%

expr:
  | s = STRING
    { Literal (String s) }
  | n = NUMBER
    { Literal (Number n) }
  | b = BOOL
    { Literal (Bool b) }
  /* | f = FUNCTION; cb = callback; CLOSE_PARENT
    { Map f } */
  | k = KEY
    { Key k }
  | DOT
    { Identity }
  | e1 = expr PIPE e2 = expr
    { Pipe (e1, e2) }
  | e1 = expr ADD e2 = expr
    { Addition (e1, e2) }
  | e1 = expr SUB e2 = expr
    { Subtraction (e1, e2) }
  | e1 = expr MULT e2 = expr
    { Multiply (e1, e2) }
  | e1 = expr DIV e2 = expr
    { Division (e1, e2) }
  ;
