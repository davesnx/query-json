include module type of Common

val from_string : ?buf:Buffer.t -> ?fname:string -> ?lnum:int -> string -> t

val from_channel :
  ?buf:Buffer.t -> ?fname:string -> ?lnum:int -> in_channel -> t

val from_file : ?buf:Buffer.t -> ?fname:string -> ?lnum:int -> string -> t

type json_parse_error = {
  message : string;
  start_pos : int option;
  end_pos : int option;
  input : string option;
}

val parse_string : string -> (t, json_parse_error) result
val parse_file : string -> (t, json_parse_error) result
val parse_channel : in_channel -> (t, json_parse_error) result
