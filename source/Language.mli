type applicable_to = String | Array | Object | Number | Bool | Nil | Any

type arity =
  | No_args
  | One_arg of string
  | Two_args of string * string
  | Three_args of string * string * string
  | Variable_args of string

type function_info = {
  name : string;
  aliases : string list;
  description : string;
  example : string option;
  applicable_to : applicable_to list;
  insert_text : string option;
  arity : arity;
}

type category = {
  name : string;
  description : string;
  functions : function_info list;
}

val all_categories : category list
val find_category : string -> category option
val category_names : unit -> string list
val all_functions : unit -> function_info list
val all_function_names : unit -> string list
val suggest_function_name : string -> string list
val functions_for_type : string -> function_info list
val function_names_for_type : string -> string list
val type_name_of_applicable : applicable_to -> string
val applicable_of_type_name : string -> applicable_to option
val applicable_of_json_type : string -> applicable_to
val find_function : string -> function_info option
val error_for_missing_arg : string -> string
val map_nullary_fn : string -> (Ast.expression, string) result
val map_unary_fn : string -> Ast.expression -> (Ast.expression, string) result

val map_binary_fn :
  string -> Ast.expression -> Ast.expression -> (Ast.expression, string) result
