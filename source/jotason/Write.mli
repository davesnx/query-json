include module type of T

exception Json_error of string
val json_error : string -> 'a

val to_buffer : ?suf:string -> ?std:bool -> Buffer.t -> t -> unit
val to_string : ?buf:Buffer.t -> ?len:int -> ?suf:string -> ?std:bool -> t -> string
val to_channel : ?buf:Buffer.t -> ?len:int -> ?suf:string -> ?std:bool -> out_channel -> t -> unit
val to_output : ?buf:Buffer.t -> ?len:int -> ?suf:string -> ?std:bool -> < output : string -> int -> int -> int; .. > -> t -> unit
val to_file : ?len:int -> ?std:bool -> ?suf:string -> string -> t -> unit

val seq_to_buffer : ?suf:string -> ?std:bool -> Buffer.t -> t Seq.t -> unit
val seq_to_string : ?buf:Buffer.t -> ?len:int -> ?suf:string -> ?std:bool -> t Seq.t -> string
val seq_to_channel : ?buf:Buffer.t -> ?len:int -> ?suf:string -> ?std:bool -> out_channel -> t Seq.t -> unit
val seq_to_file : ?len:int -> ?suf:string -> ?std:bool -> string -> t Seq.t -> unit

val sort : t -> t
val pp : Format.formatter -> t -> unit
val show : t -> string
val equal : t -> t -> bool

module Pretty : sig
  val to_buffer_colored : Buffer.t -> colorize:bool -> summarize:bool -> t -> unit
  val to_string_colored : colorize:bool -> summarize:bool -> t -> string
  val print_colored : colorize:bool -> summarize:bool -> t -> unit
end
