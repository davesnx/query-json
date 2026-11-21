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
