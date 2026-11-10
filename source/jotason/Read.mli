include module type of Common

val from_string :
  ?buf:Buffer.t -> ?fname:string -> ?lnum:int -> ?demand:demand -> string -> t

val from_channel :
  ?buf:Buffer.t ->
  ?fname:string ->
  ?lnum:int ->
  ?demand:demand ->
  in_channel ->
  t

val from_file :
  ?buf:Buffer.t -> ?fname:string -> ?lnum:int -> ?demand:demand -> string -> t

val parse_string : ?demand:demand -> string -> (t, string) result
val parse_file : ?demand:demand -> string -> (t, string) result
val parse_channel : ?demand:demand -> in_channel -> (t, string) result

exception Stop

val parse_string_each :
  demand:demand ->
  ?each:demand * (t -> bool) ->
  string ->
  (t option, string) result
(** Like [parse_string] with [demand], but when [each] is [Some (d, f)] and the
    value is an array, each element is read with [d] and passed to [f], and the
    result is [None]. Once [f] returns [false], the remaining elements are only
    validated. Any other value is read with [demand]. When [f] raises [Stop],
    the read ends at once with [Ok None]: the rest of the input is not read. *)

val parse_file_each :
  demand:demand ->
  ?each:demand * (t -> bool) ->
  string ->
  (t option, string) result

val parse_channel_each :
  demand:demand ->
  ?each:demand * (t -> bool) ->
  in_channel ->
  (t option, string) result
