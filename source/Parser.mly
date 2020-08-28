%token <float> NUMBER
%token <string> STRING
%token <bool> BOOL
%token <string> IDENTIFIER
%token <string> KEY
%token <string> FUNCTION
%token CLOSE_PARENT
%token OPEN_LIST
%token CLOSE_LIST
%token OPEN_OBJ
%token CLOSE_OBJ
%token DOT
%token PIPE
%token ADD
%token SUB
%token DIV
%token MULT
%token EQUAL
%token GREATER_THAN
%token LOWER_THAN
%token GREATER_OR_EQUAL_THAN
%token LOWER_OR_EQUAL_THAN
%token WHITESPACE
%token EOF

/* changed the type, because the script does not return one value, but all
 * results which are calculated in the file */
%start <int list> main

%%

/* the calculated results are accumalted in an OCaml int list */
main:
| stmt = statement EOF { [stmt] }
| stmt = statement m = main { stmt :: m}

/* expressions end with a semicolon, not with a newline character */
statement:
| e = expr SEMICOLON { e }

expr:
| i = INT
    { i }
| LPAREN e = expr RPAREN
    { e }
| e1 = expr PLUS e2 = expr
    { e1 + e2 }
| e1 = expr MINUS e2 = expr
    { e1 - e2 }
| e1 = expr TIMES e2 = expr
    { e1 * e2 }
| e1 = expr DIV e2 = expr
    { e1 / e2 }
| MINUS e = expr %prec UMINUS
    { - e }
