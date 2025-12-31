type location = { input : string; start_pos : int; end_pos : int }

type context =
  | Json_value of Json.t
  | Expected of string
  | Found of string
  | Available_keys of string list
  | Example of string
  | Note of string

type t = {
  kind : string;
  message : string;
  location : location option;
  contexts : context list;
  suggestion : string option;
}

val with_location : input:string -> start_pos:int -> end_pos:int -> t -> t
val with_context : context -> t -> t
val with_suggestion : string -> t -> t

val format : colorize:bool -> t -> string
(** Format error with colors and Rust-style layout *)

val to_string : t -> string
(** Get just the message string *)

(** {2 Common Error Constructors} *)

val key_not_found : key:string -> json:Json.t -> available_keys:string list -> t

val type_mismatch :
  operation:string -> expected:string -> actual_json:Json.t -> t

val invalid_argument :
  fn_name:string ->
  expected:string ->
  found:string ->
  ?example:string ->
  unit ->
  t

val deprecated : old_name:string -> new_name:string -> t
val not_implemented : string -> t

val missing_argument :
  fn_name:string ->
  usage:string ->
  description:string ->
  ?example:string ->
  unit ->
  t

val empty_collection : operation:string -> t
val null_access : key:string -> t
val index_out_of_bounds : index:int -> length:int -> t

val parse_error :
  message:string -> input:string -> start_pos:int -> end_pos:int -> t

val lexer_error :
  message:string -> input:string -> start_pos:int -> end_pos:int -> t

val semantic_error :
  message:string -> input:string -> start_pos:int -> end_pos:int -> t

val runtime_error :
  kind:string ->
  message:string ->
  ?value:Json.t ->
  ?suggestion:string ->
  unit ->
  t

val context_error : message:string -> t

val json_error :
  colorize:bool ->
  message:string ->
  ?input:string ->
  ?start_pos:int ->
  ?end_pos:int ->
  unit ->
  string
