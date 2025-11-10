val parse :
  ?debug:bool -> ?colorize:bool -> string -> (Ast.expression, string) result

val run : ?colorize:bool -> string -> string -> (string, string) result
