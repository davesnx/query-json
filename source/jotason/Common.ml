type t =
  [ `Null
  | `Bool of bool
  | `Int of int
  | `Intlit of string
  | `Float of float
  | `Floatlit of string
  | `String of string
  | `Stringlit of string
  | `Assoc of (string * t) list
  | `List of t list ]

exception Json_error of string

let json_error s = raise (Json_error s)

exception End_of_array
exception End_of_object
exception End_of_input

type lexer_state = {
  buf : Buffer.t; (* Buffer used to accumulate substrings *)
  mutable lnum : int; (* Current line number (starting from 1) *)
  mutable bol : int;
      (* Absolute position of the first character of the current line (starting from 0) *)
  mutable fname : string option; (* Name describing the input file *)
}

let init_lexer ?buf ?fname ?(lnum = 1) () =
  let buf = match buf with None -> Buffer.create 256 | Some buf -> buf in
  { buf; lnum; bol = 0; fname }
