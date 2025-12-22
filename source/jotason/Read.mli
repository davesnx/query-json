include module type of T

exception Json_error of string

val from_string : ?buf:Buffer.t -> ?fname:string -> ?lnum:int -> string -> t
val from_channel : ?buf:Buffer.t -> ?fname:string -> ?lnum:int -> in_channel -> t
val from_file : ?buf:Buffer.t -> ?fname:string -> ?lnum:int -> string -> t

val parse_string : string -> (t, string) result
val parse_file : string -> (t, string) result
val parse_channel : in_channel -> (t, string) result
