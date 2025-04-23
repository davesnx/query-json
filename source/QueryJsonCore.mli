val parse : ?debug:bool -> string -> (Ast.expression, string) result
val run : string -> string -> (string, string) result
