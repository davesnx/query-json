(* JSON lexer *)

{
  [@@@warning "-32-34"]

  include Common

  (* Override Lexing.engine to avoid creating position records on each match *)
  module Lexing = struct
    include Lexing

    external c_engine : lex_tables -> int -> lexbuf -> int = "caml_lex_engine"

    let engine tbl state buf =
      let result = c_engine tbl state buf in
      (* Position tracking disabled:
         if result >= 0 then begin
           buf.lex_start_p <- buf.lex_curr_p;
           buf.lex_curr_p <- {buf.lex_curr_p with pos_cnum = buf.lex_abs_pos + buf.lex_curr_pos};
         end;
      *)
      result
  end

  (* Lexer state for tracking position and buffering *)
  type lexer_state = Common.lexer_state = {
    buf : Buffer.t;
    mutable lnum : int;
    mutable bol : int;
    mutable fname : string option;
  }

  (* Character conversion helpers *)
  let dec c = Char.code c - 48

  let hex c =
    match c with
    | '0'..'9' -> int_of_char c - int_of_char '0'
    | 'a'..'f' -> int_of_char c - int_of_char 'a' + 10
    | 'A'..'F' -> int_of_char c - int_of_char 'A' + 10
    | _ -> assert false

  (* Error reporting *)
  let custom_error descr v (lexbuf : Lexing.lexbuf) =
    let offs = lexbuf.lex_abs_pos - 1 in
    let bol = v.bol in
    let pos1 = offs + lexbuf.lex_start_pos - bol - 1 in
    let pos2 = max pos1 (offs + lexbuf.lex_curr_pos - bol) in
    let file_line =
      match v.fname with
      | None -> "Line"
      | Some s -> Printf.sprintf "File %s, line" s
    in
    let bytes =
      if pos1 = pos2 then Printf.sprintf "byte %i" (pos1 + 1)
      else Printf.sprintf "bytes %i-%i" (pos1 + 1) (pos2 + 1)
    in
    let msg = Printf.sprintf "%s %i, %s:\n%s" file_line v.lnum bytes descr in
    Common.json_error msg

  let lexer_error descr v lexbuf =
    custom_error (Printf.sprintf "%s '%s'" descr (Lexing.lexeme lexbuf)) v lexbuf

  (* Read extra characters from lexbuf for error context *)
  let read_junk_without_positions buf n (lexbuf : Lexing.lexbuf) =
    let lex_abs_pos = lexbuf.lex_abs_pos in
    let lex_start_pos = lexbuf.lex_start_pos in
    let rec read_chars remaining =
      if remaining <= 0 then ()
      else if lexbuf.lex_curr_pos >= lexbuf.lex_buffer_len then
        if lexbuf.lex_eof_reached then ()
        else begin
          lexbuf.refill_buff lexbuf;
          read_chars remaining
        end
      else begin
        Buffer.add_char buf (Bytes.get lexbuf.lex_buffer lexbuf.lex_curr_pos);
        lexbuf.lex_curr_pos <- lexbuf.lex_curr_pos + 1;
        read_chars (remaining - 1)
      end
    in
    read_chars n;
    lexbuf.lex_start_pos <- lex_start_pos + 1;
    lexbuf.lex_abs_pos <- lex_abs_pos

  let long_error descr v lexbuf =
    let junk = Lexing.lexeme lexbuf in
    let buf = Buffer.create 32 in
    read_junk_without_positions buf 32 lexbuf;
    let extra_junk = Buffer.contents buf in
    custom_error (Printf.sprintf "%s '%s%s'" descr junk extra_junk) v lexbuf

  (* Integer parsing with overflow detection.
     Strategy: try int (63-bit) -> int64 (64-bit) -> Big_int (arbitrary) *)
  let min10 = min_int / 10 - (if min_int mod 10 = 0 then 0 else 1)
  let max10 = max_int / 10 + (if max_int mod 10 = 0 then 0 else 1)

  exception Int_overflow

  let extract_positive_int (lexbuf : Lexing.lexbuf) =
    let start = lexbuf.lex_start_pos in
    let stop = lexbuf.lex_curr_pos in
    let s = lexbuf.lex_buffer in
    let n = ref 0 in
    for i = start to stop - 1 do
      if !n >= max10 then raise Int_overflow
      else n := 10 * !n + dec (Bytes.get s i)
    done;
    if !n < 0 then raise Int_overflow else !n

  let extract_negative_int (lexbuf : Lexing.lexbuf) =
    let start = lexbuf.lex_start_pos + 1 in
    let stop = lexbuf.lex_curr_pos in
    let s = lexbuf.lex_buffer in
    let n = ref 0 in
    for i = start to stop - 1 do
      if !n <= min10 then raise Int_overflow
      else n := 10 * !n - dec (Bytes.get s i)
    done;
    if !n > 0 then raise Int_overflow else !n

  (* Parse integer into smallest fitting type: int -> int64 -> Big_int *)
  let make_positive_int _v lexbuf =
    try `Int (extract_positive_int lexbuf)
    with Int_overflow ->
      let s = Lexing.lexeme lexbuf in
      try `Int64 (Int64.of_string s)
      with Failure _ -> `Big_int (Z.of_string s)

  let make_negative_int _v lexbuf =
    try `Int (extract_negative_int lexbuf)
    with Int_overflow ->
      let s = Lexing.lexeme lexbuf in
      try `Int64 (Int64.of_string s)
      with Failure _ -> `Big_int (Z.of_string s)

  (* Position tracking *)
  let newline v (lexbuf : Lexing.lexbuf) =
    v.lnum <- v.lnum + 1;
    v.bol <- lexbuf.lex_abs_pos + lexbuf.lex_curr_pos

  let add_lexeme buf (lexbuf : Lexing.lexbuf) =
    let len = lexbuf.lex_curr_pos - lexbuf.lex_start_pos in
    Buffer.add_subbytes buf lexbuf.lex_buffer lexbuf.lex_start_pos len

  let map_lexeme f (lexbuf : Lexing.lexbuf) =
    let len = lexbuf.lex_curr_pos - lexbuf.lex_start_pos in
    f (Bytes.sub_string lexbuf.lex_buffer lexbuf.lex_start_pos len) 0 len
}

(* Token definitions *)
let space = [' ' '\t' '\r']+
let digit = ['0'-'9']
let nonzero = ['1'-'9']
let digits = digit+
let frac = '.' digits
let e = ['e' 'E']['+' '-']?
let exp = e digits
let positive_int = (digit | nonzero digits)
let float = '-'? positive_int (frac | exp | frac exp)
let number = '-'? positive_int (frac | exp | frac exp)?
let hex = ['0'-'9' 'a'-'f' 'A'-'F']
let ident = ['a'-'z' 'A'-'Z' '_']['a'-'z' 'A'-'Z' '_' '0'-'9']*

(* Main JSON parser *)
rule read_json v = parse
  | "true"        { `Bool true }
  | "false"       { `Bool false }
  | "null"        { `Null }
  | "NaN"         { `Float nan }
  | "Infinity"    { `Float infinity }
  | "-Infinity"   { `Float neg_infinity }
  | '"'           { Buffer.clear v.buf; `String (finish_string v lexbuf) }
  | positive_int  { make_positive_int v lexbuf }
  | '-' positive_int { make_negative_int v lexbuf }
  | float         { `Decimal (Common.Decimal.of_lexeme_exn (Lexing.lexeme lexbuf)) }
  | '{' {
      let acc = ref [] in
      try
        read_space v lexbuf;
        read_object_end lexbuf;
        let field_name = read_ident v lexbuf in
        read_space v lexbuf;
        read_colon v lexbuf;
        read_space v lexbuf;
        acc := (field_name, read_json v lexbuf) :: !acc;
        while true do
          read_space v lexbuf;
          read_object_sep v lexbuf;
          read_space v lexbuf;
          let field_name = read_ident v lexbuf in
          read_space v lexbuf;
          read_colon v lexbuf;
          read_space v lexbuf;
          acc := (field_name, read_json v lexbuf) :: !acc
        done;
        assert false
      with Common.End_of_object -> `Assoc (List.rev !acc)
    }
  | '[' {
      let acc = ref [] in
      try
        read_space v lexbuf;
        read_array_end lexbuf;
        acc := read_json v lexbuf :: !acc;
        while true do
          read_space v lexbuf;
          read_array_sep v lexbuf;
          read_space v lexbuf;
          acc := read_json v lexbuf :: !acc
        done;
        assert false
      with Common.End_of_array -> `List (List.rev !acc)
    }
  | "//"[^'\n']*  { read_json v lexbuf }
  | "/*"          { finish_comment v lexbuf; read_json v lexbuf }
  | "\n"          { newline v lexbuf; read_json v lexbuf }
  | space         { read_json v lexbuf }
  | eof           { custom_error "Unexpected end of input" v lexbuf }
  | _             { long_error "Invalid token" v lexbuf }

(* String parsing *)
and finish_string v = parse
  | '"'           { Buffer.contents v.buf }
  | '\\'          { finish_escaped_char v lexbuf; finish_string v lexbuf }
  | [^ '"' '\\']+  { add_lexeme v.buf lexbuf; finish_string v lexbuf }
  | eof           { custom_error "Unexpected end of input" v lexbuf }

and map_string v f = parse
  | '"'           { let b = v.buf in f (Buffer.contents b) 0 (Buffer.length b) }
  | '\\'          { finish_escaped_char v lexbuf; map_string v f lexbuf }
  | [^ '"' '\\']+  { add_lexeme v.buf lexbuf; map_string v f lexbuf }
  | eof           { custom_error "Unexpected end of input" v lexbuf }

and finish_escaped_char v = parse
  | '"' | '\\' | '/' as c { Buffer.add_char v.buf c }
  | 'b'  { Buffer.add_char v.buf '\b' }
  | 'f'  { Buffer.add_char v.buf '\012' }
  | 'n'  { Buffer.add_char v.buf '\n' }
  | 'r'  { Buffer.add_char v.buf '\r' }
  | 't'  { Buffer.add_char v.buf '\t' }
  | 'u' (hex as a) (hex as b) (hex as c) (hex as d) {
      let x = (hex a lsl 12) lor (hex b lsl 8) lor (hex c lsl 4) lor hex d in
      if x >= 0xD800 && x <= 0xDBFF then
        finish_surrogate_pair v x lexbuf
      else
        Codec.utf8_of_code v.buf x
    }
  | _    { long_error "Invalid escape sequence" v lexbuf }
  | eof  { custom_error "Unexpected end of input" v lexbuf }

and finish_surrogate_pair v x = parse
  | "\\u" (hex as a) (hex as b) (hex as c) (hex as d) {
      let y = (hex a lsl 12) lor (hex b lsl 8) lor (hex c lsl 4) lor hex d in
      if y >= 0xDC00 && y <= 0xDFFF then
        Codec.utf8_of_surrogate_pair v.buf x y
      else
        long_error "Invalid low surrogate for code point beyond U+FFFF" v lexbuf
    }
  | _ { long_error "Missing escape sequence representing low surrogate for code point beyond U+FFFF" v lexbuf }
  | eof { custom_error "Unexpected end of input" v lexbuf }

and finish_stringlit v = parse
  | ('\\' (['"' '\\' '/' 'b' 'f' 'n' 'r' 't'] | 'u' hex hex hex hex) | [^'"' '\\'])* '"' {
      let len = lexbuf.lex_curr_pos - lexbuf.lex_start_pos in
      let s = Bytes.create (len + 1) in
      Bytes.set s 0 '"';
      Bytes.blit lexbuf.lex_buffer lexbuf.lex_start_pos s 1 len;
      Bytes.to_string s
    }
  | _   { long_error "Invalid string literal" v lexbuf }
  | eof { custom_error "Unexpected end of input" v lexbuf }

(* Comments *)
and finish_comment v = parse
  | "*/" { () }
  | eof  { long_error "Unterminated comment" v lexbuf }
  | '\n' { newline v lexbuf; finish_comment v lexbuf }
  | _    { finish_comment v lexbuf }

(* Whitespace and structure *)
and read_space v = parse
  | "//"[^'\n']* ('\n'|eof) { newline v lexbuf; read_space v lexbuf }
  | "/*"                    { finish_comment v lexbuf; read_space v lexbuf }
  | '\n'                    { newline v lexbuf; read_space v lexbuf }
  | [' ' '\t' '\r']+        { read_space v lexbuf }
  | ""                      { () }

and read_eof = parse
  | eof { true }
  | ""  { false }

(* Punctuation readers *)
and read_colon v = parse
  | ':'  { () }
  | _    { long_error "Expected ':' but found" v lexbuf }
  | eof  { custom_error "Unexpected end of input" v lexbuf }

and read_comma v = parse
  | ','  { () }
  | _    { long_error "Expected ',' but found" v lexbuf }
  | eof  { custom_error "Unexpected end of input" v lexbuf }

and read_lt v = parse
  | '<'  { () }
  | _    { long_error "Expected '<' but found" v lexbuf }
  | eof  { custom_error "Unexpected end of input" v lexbuf }

and read_gt v = parse
  | '>'  { () }
  | _    { long_error "Expected '>' but found" v lexbuf }
  | eof  { custom_error "Unexpected end of input" v lexbuf }

and read_lpar v = parse
  | '('  { () }
  | _    { long_error "Expected '(' but found" v lexbuf }
  | eof  { custom_error "Unexpected end of input" v lexbuf }

and read_rpar v = parse
  | ')'  { () }
  | _    { long_error "Expected ')' but found" v lexbuf }
  | eof  { custom_error "Unexpected end of input" v lexbuf }

and read_lbr v = parse
  | '['  { () }
  | _    { long_error "Expected '[' but found" v lexbuf }
  | eof  { custom_error "Unexpected end of input" v lexbuf }

and read_rbr v = parse
  | ']'  { () }
  | _    { long_error "Expected ']' but found" v lexbuf }
  | eof  { custom_error "Unexpected end of input" v lexbuf }

and read_lcurl v = parse
  | '{'  { () }
  | _    { long_error "Expected '{' but found" v lexbuf }
  | eof  { custom_error "Unexpected end of input" v lexbuf }

(* Array structure *)
and read_array_end = parse
  | ']'  { raise Common.End_of_array }
  | ""   { () }

and read_array_sep v = parse
  | ','  { () }
  | ']'  { raise Common.End_of_array }
  | _    { long_error "Expected ',' or ']' but found" v lexbuf }
  | eof  { custom_error "Unexpected end of input" v lexbuf }

and read_array_start = parse
  | '['  { true }
  | ""   { false }

(* Object structure *)
and read_object_start = parse
  | '{'  { true }
  | ""   { false }

and read_object_end = parse
  | '}'  { raise Common.End_of_object }
  | ""   { () }

and read_object_sep v = parse
  | ','  { () }
  | '}'  { raise Common.End_of_object }
  | _    { long_error "Expected ',' or '}' but found" v lexbuf }
  | eof  { custom_error "Unexpected end of input" v lexbuf }

(* Identifiers and keys *)
and read_ident v = parse
  | '"'      { Buffer.clear v.buf; finish_string v lexbuf }
  | ident as s { s }
  | _        { long_error "Expected string or identifier but found" v lexbuf }
  | eof      { custom_error "Unexpected end of input" v lexbuf }

and map_ident v f = parse
  | '"'   { Buffer.clear v.buf; map_string v f lexbuf }
  | ident { map_lexeme f lexbuf }
  | _     { long_error "Expected string or identifier but found" v lexbuf }
  | eof   { custom_error "Unexpected end of input" v lexbuf }

(* Primitive readers *)
and read_null v = parse
  | "null" { () }
  | _      { long_error "Expected 'null' but found" v lexbuf }
  | eof    { custom_error "Unexpected end of input" v lexbuf }

and read_null_if_possible _v = parse
  | "null" { true }
  | ""     { false }

and read_bool v = parse
  | "true"      { true }
  | "false"     { false }
  | "\"true\""  { true }   (* tolerate quoted booleans *)
  | "\"false\"" { false }
  | _           { long_error "Expected 'true' or 'false' but found" v lexbuf }
  | eof         { custom_error "Unexpected end of input" v lexbuf }

and read_int v = parse
  | positive_int {
      try extract_positive_int lexbuf
      with Int_overflow -> lexer_error "Int overflow" v lexbuf
    }
  | '-' positive_int {
      try extract_negative_int lexbuf
      with Int_overflow -> lexer_error "Int overflow" v lexbuf
    }
  | '"' {
      Buffer.clear v.buf;
      let s = finish_string v lexbuf in
      try int_of_string s
      with _ -> custom_error "Expected an integer but found a string that doesn't represent an integer" v lexbuf
    }
  | _   { long_error "Expected integer but found" v lexbuf }
  | eof { custom_error "Unexpected end of input" v lexbuf }

and read_int32 v = parse
  | '-'? positive_int {
      try Int32.of_string (Lexing.lexeme lexbuf)
      with _ -> lexer_error "Int32 overflow" v lexbuf
    }
  | '"' {
      Buffer.clear v.buf;
      let s = finish_string v lexbuf in
      try Int32.of_string s
      with _ -> custom_error "Expected an int32 but found a string that doesn't represent an integer" v lexbuf
    }
  | _   { long_error "Expected int32 but found" v lexbuf }
  | eof { custom_error "Unexpected end of input" v lexbuf }

and read_int64 v = parse
  | '-'? positive_int {
      try Int64.of_string (Lexing.lexeme lexbuf)
      with _ -> lexer_error "Int64 overflow" v lexbuf
    }
  | '"' {
      Buffer.clear v.buf;
      let s = finish_string v lexbuf in
      try Int64.of_string s
      with _ -> custom_error "Expected an int64 but found a string that doesn't represent an integer" v lexbuf
    }
  | _   { long_error "Expected int64 but found" v lexbuf }
  | eof { custom_error "Unexpected end of input" v lexbuf }

and read_number v = parse
  | "NaN"       { nan }
  | "Infinity"  { infinity }
  | "-Infinity" { neg_infinity }
  | number      { float_of_string (Lexing.lexeme lexbuf) }
  | '"' {
      Buffer.clear v.buf;
      let s = finish_string v lexbuf in
      try float_of_string s
      with _ ->
        match s with
        | "NaN" -> nan
        | "Infinity" -> infinity
        | "-Infinity" -> neg_infinity
        | _ -> custom_error "Expected a number but found a string that doesn't represent a number" v lexbuf
    }
  | _   { long_error "Expected number but found" v lexbuf }
  | eof { custom_error "Unexpected end of input" v lexbuf }

and read_string v = parse
  | '"'  { Buffer.clear v.buf; finish_string v lexbuf }
  | _    { long_error "Expected '\"' but found" v lexbuf }
  | eof  { custom_error "Unexpected end of input" v lexbuf }

(* Sequence readers *)
and read_sequence read_cell init_acc v = parse
  | '[' {
      let acc = ref init_acc in
      try
        read_space v lexbuf;
        read_array_end lexbuf;
        acc := read_cell !acc v lexbuf;
        while true do
          read_space v lexbuf;
          read_array_sep v lexbuf;
          read_space v lexbuf;
          acc := read_cell !acc v lexbuf
        done;
        assert false
      with Common.End_of_array -> !acc
    }
  | _   { long_error "Expected '[' but found" v lexbuf }
  | eof { custom_error "Unexpected end of input" v lexbuf }

and read_list_rev read_cell v = parse
  | '[' {
      let acc = ref [] in
      try
        read_space v lexbuf;
        read_array_end lexbuf;
        acc := read_cell v lexbuf :: !acc;
        while true do
          read_space v lexbuf;
          read_array_sep v lexbuf;
          read_space v lexbuf;
          acc := read_cell v lexbuf :: !acc
        done;
        assert false
      with Common.End_of_array -> !acc
    }
  | _   { long_error "Expected '[' but found" v lexbuf }
  | eof { custom_error "Unexpected end of input" v lexbuf }

and read_abstract_fields read_key read_field init_acc v = parse
  | '{' {
      let acc = ref init_acc in
      try
        read_space v lexbuf;
        read_object_end lexbuf;
        let field_name = read_key v lexbuf in
        read_space v lexbuf;
        read_colon v lexbuf;
        read_space v lexbuf;
        acc := read_field !acc field_name v lexbuf;
        while true do
          read_space v lexbuf;
          read_object_sep v lexbuf;
          read_space v lexbuf;
          let field_name = read_key v lexbuf in
          read_space v lexbuf;
          read_colon v lexbuf;
          read_space v lexbuf;
          acc := read_field !acc field_name v lexbuf
        done;
        assert false
      with Common.End_of_object -> !acc
    }
  | _   { long_error "Expected '{' but found" v lexbuf }
  | eof { custom_error "Unexpected end of input" v lexbuf }

(* Skip rules - for ignoring field values *)
and skip_json v = parse
  | '{' {
      try
        read_space v lexbuf;
        read_object_end lexbuf;
        ignore (read_ident v lexbuf);
        read_space v lexbuf;
        read_colon v lexbuf;
        read_space v lexbuf;
        skip_json v lexbuf;
        while true do
          read_space v lexbuf;
          read_object_sep v lexbuf;
          read_space v lexbuf;
          ignore (read_ident v lexbuf);
          read_space v lexbuf;
          read_colon v lexbuf;
          read_space v lexbuf;
          skip_json v lexbuf
        done;
        assert false
      with Common.End_of_object -> ()
    }
  | '[' {
      try
        read_space v lexbuf;
        read_array_end lexbuf;
        skip_json v lexbuf;
        while true do
          read_space v lexbuf;
          read_array_sep v lexbuf;
          read_space v lexbuf;
          skip_json v lexbuf
        done;
        assert false
      with Common.End_of_array -> ()
    }
  | "//"[^'\n']* { skip_json v lexbuf }
  | "/*"         { finish_comment v lexbuf; skip_json v lexbuf }
  | "\n"         { newline v lexbuf; skip_json v lexbuf }
  | space        { skip_json v lexbuf }
  | ""           { ignore (read_json v lexbuf) }

(* Buffer rules - for capturing deferred values *)
and buffer_json v = parse
  | "true" | "false" | "null" | "NaN" | "Infinity" | "-Infinity"
  | '-'? positive_int | float { add_lexeme v.buf lexbuf }
  | '"' { finish_buffer_stringlit v lexbuf }
  | '{' {
      try
        Buffer.add_char v.buf '{';
        buffer_space v lexbuf;
        buffer_object_end v lexbuf;
        buffer_ident v lexbuf;
        buffer_space v lexbuf;
        buffer_colon v lexbuf;
        buffer_space v lexbuf;
        buffer_json v lexbuf;
        while true do
          buffer_space v lexbuf;
          buffer_object_sep v lexbuf;
          buffer_space v lexbuf;
          buffer_ident v lexbuf;
          buffer_space v lexbuf;
          buffer_colon v lexbuf;
          buffer_space v lexbuf;
          buffer_json v lexbuf
        done;
        assert false
      with Common.End_of_object -> ()
    }
  | '[' {
      try
        Buffer.add_char v.buf '[';
        buffer_space v lexbuf;
        buffer_array_end v lexbuf;
        buffer_json v lexbuf;
        while true do
          buffer_space v lexbuf;
          buffer_array_sep v lexbuf;
          buffer_space v lexbuf;
          buffer_json v lexbuf
        done;
        assert false
      with Common.End_of_array -> ()
    }
  | "//"[^'\n']* { add_lexeme v.buf lexbuf; buffer_json v lexbuf }
  | "/*" {
      Buffer.add_string v.buf "/*";
      finish_buffer_comment v lexbuf;
      buffer_json v lexbuf
    }
  | "\n" {
      Buffer.add_char v.buf '\n';
      newline v lexbuf;
      buffer_json v lexbuf
    }
  | space { add_lexeme v.buf lexbuf; buffer_json v lexbuf }
  | eof   { custom_error "Unexpected end of input" v lexbuf }
  | _     { long_error "Invalid token" v lexbuf }

and finish_buffer_stringlit v = parse
  | ('\\' (['"' '\\' '/' 'b' 'f' 'n' 'r' 't'] | 'u' hex hex hex hex) | [^'"' '\\'])* '"' {
      Buffer.add_char v.buf '"';
      add_lexeme v.buf lexbuf
    }
  | _   { long_error "Invalid string literal" v lexbuf }
  | eof { custom_error "Unexpected end of input" v lexbuf }

and buffer_ident v = parse
  | '"'   { finish_buffer_stringlit v lexbuf }
  | ident { add_lexeme v.buf lexbuf }
  | _     { long_error "Expected string or identifier but found" v lexbuf }
  | eof   { custom_error "Unexpected end of input" v lexbuf }

and buffer_space v = parse
  | "//"[^'\n']* ('\n'|eof) { add_lexeme v.buf lexbuf; newline v lexbuf; buffer_space v lexbuf }
  | "/*" { Buffer.add_string v.buf "/*"; finish_buffer_comment v lexbuf; buffer_space v lexbuf }
  | '\n' { Buffer.add_char v.buf '\n'; newline v lexbuf; buffer_space v lexbuf }
  | [' ' '\t' '\r']+ { add_lexeme v.buf lexbuf; buffer_space v lexbuf }
  | ""   { () }

and buffer_object_end v = parse
  | '}' { Buffer.add_char v.buf '}'; raise Common.End_of_object }
  | ""  { () }

and buffer_object_sep v = parse
  | ',' { Buffer.add_char v.buf ',' }
  | '}' { Buffer.add_char v.buf '}'; raise Common.End_of_object }
  | _   { long_error "Expected ',' or '}' but found" v lexbuf }
  | eof { custom_error "Unexpected end of input" v lexbuf }

and buffer_array_end v = parse
  | ']' { Buffer.add_char v.buf ']'; raise Common.End_of_array }
  | ""  { () }

and buffer_array_sep v = parse
  | ',' { Buffer.add_char v.buf ',' }
  | ']' { Buffer.add_char v.buf ']'; raise Common.End_of_array }
  | _   { long_error "Expected ',' or ']' but found" v lexbuf }
  | eof { custom_error "Unexpected end of input" v lexbuf }

and buffer_colon v = parse
  | ':' { Buffer.add_char v.buf ':' }
  | _   { long_error "Expected ':' but found" v lexbuf }
  | eof { custom_error "Unexpected end of input" v lexbuf }

and buffer_gt v = parse
  | '>' { Buffer.add_char v.buf '>' }
  | _   { long_error "Expected '>' but found" v lexbuf }
  | eof { custom_error "Unexpected end of input" v lexbuf }

and finish_buffer_comment v = parse
  | "*/" { Buffer.add_string v.buf "*/" }
  | eof  { long_error "Unterminated comment" v lexbuf }
  | '\n' { Buffer.add_char v.buf '\n'; newline v lexbuf; finish_buffer_comment v lexbuf }
  | _    { add_lexeme v.buf lexbuf; finish_buffer_comment v lexbuf }

{
  (* Type annotation for the main parser *)
  let _ = (read_json : lexer_state -> Lexing.lexbuf -> t)

  let read_t = read_json

  let read_int8 v lexbuf =
    let n = read_int v lexbuf in
    if n < 0 || n > 255 then lexer_error "Int8 overflow" v lexbuf
    else char_of_int n

  let read_list read_cell v lexbuf =
    List.rev (read_list_rev read_cell v lexbuf)

  let array_of_rev_list l =
    match l with
    | [] -> [||]
    | x :: tl ->
        let len = List.length l in
        let a = Array.make len x in
        let r = ref tl in
        for i = len - 2 downto 0 do
          a.(i) <- List.hd !r;
          r := List.tl !r
        done;
        a

  let read_array read_cell v lexbuf =
    let l = read_list_rev read_cell v lexbuf in
    array_of_rev_list l

  let read_fields read_field init_acc v =
    read_abstract_fields read_ident read_field init_acc v

  let finish v lexbuf =
    read_space v lexbuf;
    if not (read_eof lexbuf) then
      long_error "Junk after end of JSON value:" v lexbuf

  let init_lexer = Common.init_lexer

  let from_lexbuf v ?(stream = false) lexbuf =
    read_space v lexbuf;
    let x =
      if read_eof lexbuf then raise Common.End_of_input
      else read_json v lexbuf
    in
    if not stream then finish v lexbuf;
    x

  let from_string ?buf ?fname ?lnum s =
    try
      let lexbuf = Lexing.from_string s in
      let v = init_lexer ?buf ?fname ?lnum () in
      from_lexbuf v lexbuf
    with Common.End_of_input -> Common.json_error "Blank input data"

  let from_channel ?buf ?fname ?lnum ic =
    try
      let lexbuf = Lexing.from_channel ic in
      let v = init_lexer ?buf ?fname ?lnum () in
      from_lexbuf v lexbuf
    with Common.End_of_input -> Common.json_error "Blank input data"

  let with_file read file =
    let ic = open_in file in
    try
      let x = read ic in
      close_in ic;
      x
    with e ->
      close_in_noerr ic;
      raise e

  let from_file ?buf ?fname ?lnum file =
    with_file (from_channel ?buf ?fname ?lnum) file

  exception Finally of exn * exn

  let seq_from_lexbuf v ?(fin = fun () -> ()) lexbuf =
    let stream = Some true in
    let rec f () =
      try Seq.Cons (from_lexbuf v ?stream lexbuf, f)
      with
      | Common.End_of_input -> fin (); Seq.Nil
      | e -> (try fin () with fin_e -> raise (Finally (e, fin_e))); raise e
    in
    f

  let seq_from_string ?buf ?fname ?lnum s =
    let v = init_lexer ?buf ?fname ?lnum () in
    seq_from_lexbuf v (Lexing.from_string s)

  let seq_from_channel ?buf ?fin ?fname ?lnum ic =
    let lexbuf = Lexing.from_channel ic in
    let v = init_lexer ?buf ?fname ?lnum () in
    seq_from_lexbuf v ?fin lexbuf

  let seq_from_file ?buf ?fname ?lnum file =
    let ic = open_in file in
    let fin () = close_in ic in
    let fname = match fname with None -> Some file | x -> x in
    let lexbuf = Lexing.from_channel ic in
    let v = init_lexer ?buf ?fname ?lnum () in
    seq_from_lexbuf v ~fin lexbuf

  type json_line = [ `Json of t | `Exn of exn ]

  let lineseq_from_channel ?buf ?(fin = fun () -> ()) ?fname ?lnum:(lnum0 = 1) ic =
    let buf = match buf with None -> Some (Buffer.create 256) | Some _ -> buf in
    let rec f lnum () =
      try
        let line = input_line ic in
        Seq.Cons (`Json (from_string ?buf ?fname ~lnum line), f (lnum + 1))
      with
      | End_of_file -> fin (); Seq.Nil
      | e -> Seq.Cons (`Exn e, f (lnum + 1))
    in
    f lnum0

  let lineseq_from_file ?buf ?fname ?lnum file =
    let ic = open_in file in
    let fin () = close_in ic in
    let fname = match fname with None -> Some file | x -> x in
    lineseq_from_channel ?buf ~fin ?fname ?lnum ic

  (* Re-export from Common *)
  exception Json_error = Common.Json_error

  (* Result-based parsing wrappers *)
  let parse_with_error context read input =
    try Ok (read input)
    with
    | Common.Json_error msg -> Error ("JSON parse error: " ^ msg)
    | e -> Error (Printexc.to_string e ^ " There was an error reading " ^ context)

  let parse_string str =
    parse_with_error "the string" from_string str

  let parse_file file =
    parse_with_error "the file" from_file file

  let parse_channel channel =
    parse_with_error "from standard input" from_channel channel

  module Input = struct
    type source = String of string | File of string | Channel of in_channel | Value of t
    type selection = Whole of t | Selected of t
    type item_location = Root | Member of string
    type 'a step = Continue of 'a | Validate_rest of 'a
    type 'a items_result = Folded of 'a | Materialized of selection

    type position = First | Next | Tail | Done
    type cursor = { next : unit -> t option; drain : unit -> unit }
    type probe = Items of cursor | Ready of selection

    let array_closed read =
      try read (); false with Common.End_of_array -> true

    let object_closed read =
      try read (); false with Common.End_of_object -> true

    let read_key v lexbuf =
      let name = read_ident v lexbuf in
      read_space v lexbuf;
      read_colon v lexbuf;
      read_space v lexbuf;
      name

    let container_cursor v lexbuf ~is_object ~after =
      let position = ref First in
      let at_end () =
        if is_object then object_closed (fun () -> read_object_end lexbuf)
        else array_closed (fun () -> read_array_end lexbuf)
      in
      let boundary () =
        read_space v lexbuf;
        let closed =
          if is_object then object_closed (fun () -> read_object_sep v lexbuf)
          else array_closed (fun () -> read_array_sep v lexbuf)
        in
        position := if closed then Tail else Next
      in
      let rec advance read () =
        match !position with
        | Done -> None
        | Tail -> after (); position := Done; None
        | First ->
            read_space v lexbuf;
            position := if at_end () then Tail else Next;
            advance read ()
        | Next ->
            read_space v lexbuf;
            if is_object then ignore (read_key v lexbuf);
            let value = read v lexbuf in
            boundary ();
            Some value
      in
      let rec drain () =
        match advance skip_json () with
        | None -> ()
        | Some () -> drain ()
      in
      { next = advance read_json; drain }

    let probe_items at lexbuf =
      let v = init_lexer () in
      let finish () = finish v lexbuf in
      let materialize selection = finish (); Ready selection in
      let container ~after =
        if read_array_start lexbuf then
          Some (Items (container_cursor v lexbuf ~is_object:false ~after))
        else if read_object_start lexbuf then
          Some (Items (container_cursor v lexbuf ~is_object:true ~after))
        else None
      in
      let rec object_tail () =
        read_space v lexbuf;
        if object_closed (fun () -> read_object_sep v lexbuf) then finish ()
        else begin
          read_space v lexbuf;
          ignore (read_key v lexbuf);
          skip_json v lexbuf;
          object_tail ()
        end
      in
      let rec member key fields =
        let name = read_key v lexbuf in
        if name = key then
          match container ~after:object_tail with
          | Some items -> items
          | None ->
              let value = read_json v lexbuf in
              object_tail ();
              Ready (Selected value)
        else begin
          let value = read_json v lexbuf in
          let fields = (name, value) :: fields in
          read_space v lexbuf;
          if object_closed (fun () -> read_object_sep v lexbuf) then
            materialize (Whole (`Assoc (List.rev fields)))
          else begin
            read_space v lexbuf;
            member key fields
          end
        end
      in
      read_space v lexbuf;
      if read_eof lexbuf then Common.json_error "Blank input data";
      match at with
      | Root ->
          (match container ~after:finish with
          | Some items -> items
          | None -> materialize (Whole (read_json v lexbuf)))
      | Member key ->
          if not (read_object_start lexbuf) then
            materialize (Whole (read_json v lexbuf))
          else begin
            read_space v lexbuf;
            if object_closed (fun () -> read_object_end lexbuf) then
              materialize (Whole (`Assoc []))
            else member key []
          end

    let fold_lexbuf context ~at ~init ~f lexbuf =
      let parse read = parse_with_error context read () in
      let rec loop cursor state =
        match parse cursor.next with
        | Error _ as error -> error
        | Ok None -> Ok (Folded state)
        | Ok (Some value) ->
            match f state value with
            | Continue state -> loop cursor state
            | Validate_rest state ->
                Result.map (fun () -> Folded state) (parse cursor.drain)
      in
      match parse (fun () -> probe_items at lexbuf) with
      | Error _ as error -> error
      | Ok (Ready selection) -> Ok (Materialized selection)
      | Ok (Items cursor) -> loop cursor init

    let fold_value ~at ~init ~f value =
      let rec fold get state = function
        | [] -> Folded state
        | item :: rest ->
            match f state (get item) with
            | Continue state -> fold get state rest
            | Validate_rest state -> Folded state
      in
      let selection =
        match at, value with
        | Member key, `Assoc fields ->
            (match List.assoc_opt key fields with
            | Some value -> Selected value
            | None -> Whole value)
        | _ -> Whole value
      in
      let target = match selection with Whole value | Selected value -> value in
      match at, selection, target with
      | Member _, Whole _, _ -> Materialized selection
      | _, _, `List items -> fold Fun.id init items
      | _, _, `Assoc fields -> fold snd init fields
      | _ -> Materialized selection

    let fold_items ~at ~init ~f source =
      let from_channel context channel =
        fold_lexbuf context ~at ~init ~f (Lexing.from_channel channel)
      in
      match source with
      | Value value -> Ok (fold_value ~at ~init ~f value)
      | String text -> fold_lexbuf "the string" ~at ~init ~f (Lexing.from_string text)
      | Channel channel -> from_channel "from standard input" channel
      | File file ->
          match parse_with_error "the file" open_in file with
          | Error _ as error -> error
          | Ok channel ->
              match from_channel "the file" channel with
              | result -> close_in_noerr channel; result
              | exception error ->
                  let backtrace = Printexc.get_raw_backtrace () in
                  close_in_noerr channel;
                  Printexc.raise_with_backtrace error backtrace

    let read_selected key lexbuf =
      let v = init_lexer () in
      read_space v lexbuf;
      if read_eof lexbuf then Common.json_error "Blank input data";
      let result =
        if not (read_object_start lexbuf) then Whole (read_json v lexbuf)
        else
          let fields = ref [] in
          let selected = ref None in
          let read_field () =
            let name = read_ident v lexbuf in
            read_space v lexbuf;
            read_colon v lexbuf;
            read_space v lexbuf;
            match !selected with
            | Some _ -> skip_json v lexbuf
            | None ->
                if name = key then begin
                  fields := [];
                  selected := Some (read_json v lexbuf)
                end else
                  fields := (name, read_json v lexbuf) :: !fields
          in
          (try
            read_space v lexbuf;
            read_object_end lexbuf;
            read_field ();
            while true do
              read_space v lexbuf;
              read_object_sep v lexbuf;
              read_space v lexbuf;
              read_field ()
            done
          with Common.End_of_object -> ());
          match !selected with
          | Some value -> Selected value
          | None -> Whole (`Assoc (List.rev !fields))
      in
      finish v lexbuf;
      result

    let read ~select source =
      match select, source with
      | _, Value value -> Ok (Whole value)
      | None, String str -> Result.map (fun value -> Whole value) (parse_string str)
      | None, File file -> Result.map (fun value -> Whole value) (parse_file file)
      | None, Channel channel -> Result.map (fun value -> Whole value) (parse_channel channel)
      | Some key, String str ->
          parse_with_error "the string"
            (fun str -> read_selected key (Lexing.from_string str)) str
      | Some key, File file ->
          parse_with_error "the file"
            (with_file (fun channel -> read_selected key (Lexing.from_channel channel))) file
      | Some key, Channel channel ->
          parse_with_error "from standard input"
            (fun channel -> read_selected key (Lexing.from_channel channel)) channel
  end
}
