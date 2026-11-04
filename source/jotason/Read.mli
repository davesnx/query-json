include module type of Common

val from_string : ?buf:Buffer.t -> ?fname:string -> ?lnum:int -> string -> t

val from_channel :
  ?buf:Buffer.t -> ?fname:string -> ?lnum:int -> in_channel -> t

val from_file : ?buf:Buffer.t -> ?fname:string -> ?lnum:int -> string -> t
val parse_string : string -> (t, string) result
val parse_file : string -> (t, string) result
val parse_channel : in_channel -> (t, string) result

module Input : sig
  type source =
    | String of string
    | File of string
    | Channel of in_channel
    | Value of t

  type selection = Whole of t | Selected of t

  type item_location = Root | Member of string
  type 'a step = Continue of 'a | Validate_rest of 'a
  type 'a items_result = Folded of 'a | Materialized of selection

  val read : select:string option -> source -> (selection, string) result
  (** Select the first matching root object member, after validating the entire
      input. [select = None] uses the full parser and returns [Whole]. Missing
      members and other roots return [Whole]. [Value] returns [Whole] without
      parsing. Files are closed; channels remain open. *)

  val fold_items :
    at:item_location ->
    init:'a ->
    f:('a -> t -> 'a step) ->
    source ->
    ('a items_result, string) result
  (** Fold complete immediate array elements or object values in source order,
      including duplicate fields. [Member key] uses the first matching direct
      root member. Each child's comma or closing delimiter is consumed before
      [f] runs. Empty containers return [Folded init].

      Unsuitable targets return [Materialized] without calling [f]: [Selected]
      for a scalar matching member, [Whole] for a missing member or unsuitable
      root. [Value] uses the same rules without parsing.

      [Validate_rest state] stops callbacks but validates the remaining document
      and EOF before returning [Folded state]. A later input error returns
      [Error]. Earlier callbacks can precede an input error. Callback exceptions
      escape with their identity and backtrace. Files close on every exit;
      borrowed channels remain open, with possible read-ahead. *)
end
