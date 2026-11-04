module Runtime_error : sig
  type t
  type _ Effect.t += Fail : t -> unit Effect.t

  val to_json : t -> Json.t
  val kind_string : t -> string
  val message : t -> string
  val value : t -> Json.t option
  val suggestion : t -> string option
  val format : colorize:bool -> t -> string
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

val fail_invalid_type : colorize:bool -> string -> Json.t -> 'a

module Operators : sig
  val not : Json.t -> Json.t
  val is_truthy : Json.t -> bool
  val json_of_integer_z : Z.t -> Json.t
  val json_of_decimal : Json.decimal -> Json.t
  val add : colorize:bool -> Json.t -> Json.t -> Json.t
  val apply : colorize:bool -> Ast.op -> Json.t -> Json.t -> Json.t
end

val literal : Ast.literal -> Json.t
val member : string -> Json.t -> Json.t
val iterator : colorize:bool -> Json.t -> Json.t Seq.t
val index : colorize:bool -> int -> Json.t -> Json.t
val map_inputs : colorize:bool -> Json.t -> Json.t list
