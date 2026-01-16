type location = { input : string; start_pos : int; end_pos : int }

type context =
  | Json_value of Json.t
  | Expected of string
  | Found of string
  | Available_keys of string list
  | Example of string
  | Usage of string
  | Description of string
  | Applicable_to of string

type t = {
  kind : string;
  message : string;
  location : location option;
  contexts : context list;
  suggestion : string option;
}

val with_location : input:string -> start_pos:int -> end_pos:int -> t -> t
val with_context : context -> t -> t

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
val not_implemented : ?suggestion:string -> ?description:string -> string -> t
val invalid_regex : pattern:string -> t
val requires_literal : fn_name:string -> what:string -> example:string -> t

val requires_number_literal :
  fn_name:string -> what:string -> ?example:string -> unit -> t

val unsupported :
  fn_name:string -> message:string -> ?suggestion:string -> unit -> t

val missing_argument :
  fn_name:string ->
  ?message:string ->
  usage:string ->
  description:string ->
  ?applicable_to:string ->
  ?example:string ->
  unit ->
  t

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
  ?expected:string ->
  ?found:string ->
  unit ->
  t

val context_error : message:string -> t

exception Parse_exception of string * Lexing.position * Lexing.position
exception Rich_parse_exception of t * Lexing.position * Lexing.position

val raise_parse_exception : t -> Lexing.position -> Lexing.position -> 'a

module Runtime : sig
  type t
  type _ Effect.t += Fail : t -> unit Effect.t

  val to_json : t -> Json.t
  val kind_string : t -> string
  val message : t -> string
  val value : t -> Json.t option
  val suggestion : t -> string option
  val key_not_found : key:string -> value:Json.t -> 'a
  val null_access : key:string -> value:Json.t -> 'a
  val type_mismatch : value:Json.t -> ?suggestion:string -> string -> 'a
  val index_out_of_bounds : index:int -> length:int -> value:Json.t -> 'a
  val empty_array : string -> 'a
  val invalid_argument : fn:string -> expected:string -> found:string -> 'a
  val undefined_function : name:string -> 'a
  val empty_result : op:string -> ?suggestion:string -> unit -> 'a
  val assertion_error : value:Json.t -> string -> 'a
  val custom : kind:string -> value:Json.t -> string -> 'a
end
