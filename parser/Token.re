/* [@deriving show]
   type t =
     | NUMBER(float)
     | STRING(string)
     | BOOL(bool)
     | IDENTIFIER(string)
     | FUN
     | OPEN_LIST
     | CLOSE_LIST
     | OPEN_OBJ
     | CLOSE_OBJ
     | EQUAL
     | GREATER_THAN
     | LOWER_THAN
     | GREATER_OR_EQUAL_THAN
     | LOWER_OR_EQUAL_THAN
     | DOT
     | PIPE
     | ADD
     | SUB
     | DIV
     | MULT
     | WHITESPACE
     | EOF;

   type token = t;
    */
