include Common

type source = {
  mutable buf : bytes;
  mutable pos : int;
  mutable len : int;
  mutable off : int;
  mutable mark : int;
  mutable pin : int;
  mutable eof : bool;
  ic : in_channel option;
  st : lexer_state;
}

let refill s =
  match s.ic with
  | None ->
      false
  | Some _ when s.eof ->
      false
  | Some ic ->
      let keep = min s.mark (s.pin - s.off) in
      if keep > 0 then (
        Bytes.blit s.buf keep s.buf 0 (s.len - keep);
        s.off <- s.off + keep;
        s.pos <- s.pos - keep;
        s.len <- s.len - keep;
        s.mark <- s.mark - keep
      );
      if s.len = Bytes.length s.buf then (
        let b = Bytes.create (2 * Bytes.length s.buf) in
        Bytes.blit s.buf 0 b 0 s.len;
        s.buf <- b
      );
      let n = input ic s.buf s.len (Bytes.length s.buf - s.len) in
      if n = 0 then s.eof <- true;
      s.len <- s.len + n;
      n > 0

let rec ensure_slow s n = refill s && (s.len - s.pos >= n || ensure_slow s n)
let[@inline] ensure s n = s.len - s.pos >= n || ensure_slow s n
let[@inline] more s = s.pos < s.len || ensure_slow s 1
let[@inline] peek s k = Bytes.unsafe_get s.buf (s.pos + k)

let custom_error st descr ~start ~curr =
  let pos1 = start - st.bol - 2 in
  let pos2 = max pos1 (curr - 1 - st.bol) in
  let file_line =
    match st.fname with
    | None ->
        "Line"
    | Some s ->
        Printf.sprintf "File %s, line" s
  in
  let bytes =
    if pos1 = pos2 then
      Printf.sprintf "byte %i" (pos1 + 1)
    else
      Printf.sprintf "bytes %i-%i" (pos1 + 1) (pos2 + 1)
  in
  json_error (Printf.sprintf "%s %i, %s:\n%s" file_line st.lnum bytes descr)

let eof_error s =
  let p = s.off + s.pos in
  custom_error s.st "Unexpected end of input" ~start:p ~curr:p

let long_error s descr n =
  let start = s.off + s.pos in
  let lexeme = Bytes.sub_string s.buf s.pos n in
  s.pos <- s.pos + n;
  let junk = Buffer.create 32 in
  let rec read k =
    s.mark <- s.pos;
    if k > 0 && more s then (
      Buffer.add_char junk (peek s 0);
      s.pos <- s.pos + 1;
      read (k - 1)
    )
  in
  read 32;
  custom_error s.st
    (Printf.sprintf "%s '%s%s'" descr lexeme (Buffer.contents junk))
    ~start:(start + 1) ~curr:(s.off + s.pos)

let newline s =
  s.st.lnum <- s.st.lnum + 1;
  s.st.bol <- s.off + s.pos

let rec finish_comment s =
  s.mark <- s.pos;
  if not (more s) then
    long_error s "Unterminated comment" 0
  else
    match peek s 0 with
    | '*' when ensure s 2 && peek s 1 = '/' ->
        s.pos <- s.pos + 2
    | '\n' ->
        s.pos <- s.pos + 1;
        newline s;
        finish_comment s
    | _ ->
        s.pos <- s.pos + 1;
        finish_comment s

let rec finish_line_comment s =
  s.mark <- s.pos;
  if more s then
    if peek s 0 = '\n' then
      s.pos <- s.pos + 1
    else (
      s.pos <- s.pos + 1;
      finish_line_comment s
    )

let rec skip_space s =
  s.mark <- s.pos;
  if more s then
    match peek s 0 with
    | ' ' | '\t' | '\r' ->
        s.pos <- s.pos + 1;
        skip_space s
    | '\n' ->
        s.pos <- s.pos + 1;
        newline s;
        skip_space s
    | '/' when ensure s 2 -> (
        match peek s 1 with
        | '/' ->
            s.pos <- s.pos + 2;
            finish_line_comment s;
            newline s;
            skip_space s
        | '*' ->
            s.pos <- s.pos + 2;
            finish_comment s;
            skip_space s
        | _ ->
            ()
      )
    | _ ->
        ()

let hex_value c =
  match c with
  | '0' .. '9' ->
      Char.code c - 48
  | 'a' .. 'f' ->
      Char.code c - 87
  | 'A' .. 'F' ->
      Char.code c - 55
  | _ ->
      -1

let hex4 s k =
  let a = hex_value (peek s k) in
  let b = hex_value (peek s (k + 1)) in
  let c = hex_value (peek s (k + 2)) in
  let d = hex_value (peek s (k + 3)) in
  if a < 0 || b < 0 || c < 0 || d < 0 then
    -1
  else
    (a lsl 12) lor (b lsl 8) lor (c lsl 4) lor d

let read_escape s b =
  s.mark <- s.pos;
  if not (more s) then eof_error s;
  match peek s 0 with
  | ('"' | '\\' | '/') as c ->
      Buffer.add_char b c;
      s.pos <- s.pos + 1
  | 'b' ->
      Buffer.add_char b '\b';
      s.pos <- s.pos + 1
  | 'f' ->
      Buffer.add_char b '\012';
      s.pos <- s.pos + 1
  | 'n' ->
      Buffer.add_char b '\n';
      s.pos <- s.pos + 1
  | 'r' ->
      Buffer.add_char b '\r';
      s.pos <- s.pos + 1
  | 't' ->
      Buffer.add_char b '\t';
      s.pos <- s.pos + 1
  | 'u' ->
      let x =
        if ensure s 5 then
          hex4 s 1
        else
          -1
      in
      if x < 0 then long_error s "Invalid escape sequence" 1;
      s.pos <- s.pos + 5;
      if x >= 0xD800 && x <= 0xDBFF then (
        s.mark <- s.pos;
        if not (more s) then eof_error s;
        let y =
          if ensure s 6 && peek s 0 = '\\' && peek s 1 = 'u' then
            hex4 s 2
          else
            -1
        in
        if y < 0 then
          long_error s
            "Missing escape sequence representing low surrogate for code point \
             beyond U+FFFF"
            1
        else if y >= 0xDC00 && y <= 0xDFFF then (
          Codec.utf8_of_surrogate_pair b x y;
          s.pos <- s.pos + 6
        ) else
          long_error s "Invalid low surrogate for code point beyond U+FFFF" 6
      ) else
        Codec.utf8_of_code b x
  | _ ->
      long_error s "Invalid escape sequence" 1

let scan_string buf i len =
  let i = ref i in
  while
    !i < len
    && match Bytes.unsafe_get buf !i with '"' | '\\' -> false | _ -> true
  do
    incr i
  done;
  !i

let rec finish_string s b =
  s.mark <- s.pos;
  if not (more s) then eof_error s;
  let i = scan_string s.buf s.pos s.len in
  Buffer.add_subbytes b s.buf s.pos (i - s.pos);
  s.pos <- i;
  if i = s.len then
    finish_string s b
  else if Bytes.unsafe_get s.buf i = '"' then (
    s.pos <- i + 1;
    Buffer.contents b
  ) else (
    s.pos <- i + 1;
    read_escape s b;
    finish_string s b
  )

let read_string s =
  let i = scan_string s.buf s.pos s.len in
  if i < s.len && Bytes.unsafe_get s.buf i = '"' then (
    let r = Bytes.sub_string s.buf s.pos (i - s.pos) in
    s.pos <- i + 1;
    r
  ) else
    let b = s.st.buf in
    Buffer.clear b;
    finish_string s b

let rec skip_string s =
  s.mark <- s.pos;
  if not (more s) then eof_error s;
  let i = scan_string s.buf s.pos s.len in
  s.pos <- i;
  if i = s.len then
    skip_string s
  else if Bytes.unsafe_get s.buf i = '"' then
    s.pos <- i + 1
  else (
    s.pos <- i + 1;
    Buffer.clear s.st.buf;
    read_escape s s.st.buf;
    skip_string s
  )

let[@inline] is_digit c = c >= '0' && c <= '9'
let peek_or_nul s k =
  if ensure s (k + 1) then
    peek s k
  else
    '\000'

let rec skip_digits s k =
  if is_digit (peek_or_nul s k) then
    skip_digits s (k + 1)
  else
    k

exception Int_overflow

let extract_int s k =
  let neg = peek s 0 = '-' in
  let n = ref 0 in
  for i = Bool.to_int neg to k - 1 do
    if !n < min_int / 10 then raise Int_overflow;
    n := (10 * !n) - (Char.code (peek s i) - 48);
    if !n > 0 then raise Int_overflow
  done;
  if neg then
    !n
  else if !n = min_int then
    raise Int_overflow
  else
    - !n

let int_end s =
  let k =
    if peek s 0 = '-' then
      1
    else
      0
  in
  if peek_or_nul s k = '0' then
    k + 1
  else
    skip_digits s (k + 1)

let frac_end s k =
  if peek_or_nul s k = '.' && is_digit (peek_or_nul s (k + 1)) then
    skip_digits s (k + 2)
  else
    k

let exp_end s k =
  match peek_or_nul s k with
  | 'e' | 'E' ->
      let j =
        match peek_or_nul s (k + 1) with '+' | '-' -> k + 2 | _ -> k + 1
      in
      if is_digit (peek_or_nul s j) then
        skip_digits s (j + 1)
      else
        k
  | _ ->
      k

let read_number s : t =
  let int_end = int_end s in
  let k = exp_end s (frac_end s int_end) in
  let result =
    if k = int_end then
      try `Int (extract_int s k)
      with Int_overflow -> (
        let lexeme = Bytes.sub_string s.buf s.pos k in
        try `Int64 (Int64.of_string lexeme)
        with Failure _ -> `Big_int (Z.of_string lexeme)
      )
    else
      `Decimal (Decimal.of_lexeme_exn (Bytes.sub_string s.buf s.pos k))
  in
  s.pos <- s.pos + k;
  result

(* Without an exponent the conversion in [read_number] cannot fail. With one,
   [Decimal.of_lexeme_exn] can raise or take long, so it runs here too. *)
let skip_number s =
  let f = frac_end s (int_end s) in
  let k = exp_end s f in
  if k > f then
    ignore (read_number s)
  else
    s.pos <- s.pos + k

let rec literal_matches s lit i =
  i = String.length lit || (peek s i = lit.[i] && literal_matches s lit (i + 1))

let literal s lit (v : t) : t =
  let n = String.length lit in
  if ensure s n && literal_matches s lit 1 then (
    s.pos <- s.pos + n;
    v
  ) else
    long_error s "Invalid token" 1

let is_ident_char c =
  match c with 'a' .. 'z' | 'A' .. 'Z' | '_' | '0' .. '9' -> true | _ -> false

let rec ident_end s k =
  if is_ident_char (peek_or_nul s k) then
    ident_end s (k + 1)
  else
    k

let read_key s =
  s.mark <- s.pos;
  if not (more s) then eof_error s;
  match peek s 0 with
  | '"' ->
      s.pos <- s.pos + 1;
      read_string s
  | 'a' .. 'z' | 'A' .. 'Z' | '_' ->
      let k = ident_end s 1 in
      let r = Bytes.sub_string s.buf s.pos k in
      s.pos <- s.pos + k;
      r
  | _ ->
      long_error s "Expected string or identifier but found" 1

let no_field = ("", Skip)

let rec sub_equal buf off k i n =
  i = n
  || Bytes.unsafe_get buf (off + i) = String.unsafe_get k i
     && sub_equal buf off k (i + 1) n

let rec find_field buf off n = function
  | [] ->
      no_field
  | ((k, _) as f) :: rest ->
      if String.length k = n && sub_equal buf off k 0 n then
        f
      else
        find_field buf off n rest

let key_field s fs =
  s.mark <- s.pos;
  if not (more s) then eof_error s;
  match peek s 0 with
  | '"' ->
      let i = scan_string s.buf (s.pos + 1) s.len in
      if i < s.len && Bytes.unsafe_get s.buf i = '"' then (
        let f = find_field s.buf (s.pos + 1) (i - s.pos - 1) fs in
        s.pos <- i + 1;
        f
      ) else (
        s.pos <- s.pos + 1;
        if fs = [] then (
          skip_string s;
          no_field
        ) else
          let k = read_string s in
          find_field (Bytes.unsafe_of_string k) 0 (String.length k) fs
      )
  | 'a' .. 'z' | 'A' .. 'Z' | '_' ->
      let k = ident_end s 1 in
      let f = find_field s.buf s.pos k fs in
      s.pos <- s.pos + k;
      f
  | _ ->
      long_error s "Expected string or identifier but found" 1

let read_colon s =
  s.mark <- s.pos;
  if not (more s) then eof_error s;
  if peek s 0 = ':' then
    s.pos <- s.pos + 1
  else
    long_error s "Expected ':' but found" 1

let next_member s close descr =
  skip_space s;
  s.mark <- s.pos;
  if not (more s) then eof_error s;
  let c = peek s 0 in
  if c = ',' then (
    s.pos <- s.pos + 1;
    skip_space s;
    true
  ) else if c = close then (
    s.pos <- s.pos + 1;
    false
  ) else
    long_error s descr 1

let rec read_value s : t =
  s.mark <- s.pos;
  if not (more s) then eof_error s;
  match peek s 0 with
  | '"' ->
      s.pos <- s.pos + 1;
      `String (read_string s)
  | '{' ->
      s.pos <- s.pos + 1;
      read_object s
  | '[' ->
      s.pos <- s.pos + 1;
      read_array s
  | '0' .. '9' ->
      read_number s
  | '-' when ensure s 2 && is_digit (peek s 1) ->
      read_number s
  | '-' when ensure s 2 && peek s 1 = 'I' ->
      literal s "-Infinity" (`Float neg_infinity)
  | 't' ->
      literal s "true" (`Bool true)
  | 'f' ->
      literal s "false" (`Bool false)
  | 'n' ->
      literal s "null" `Null
  | 'N' ->
      literal s "NaN" (`Float nan)
  | 'I' ->
      literal s "Infinity" (`Float infinity)
  | _ ->
      long_error s "Invalid token" 1

and read_object s =
  skip_space s;
  if more s && peek s 0 = '}' then (
    s.pos <- s.pos + 1;
    `Assoc []
  ) else
    fields s []

and fields s acc =
  let key = read_key s in
  skip_space s;
  read_colon s;
  skip_space s;
  let acc = (key, read_value s) :: acc in
  if next_member s '}' "Expected ',' or '}' but found" then
    fields s acc
  else
    `Assoc (List.rev acc)

and read_array s =
  skip_space s;
  if more s && peek s 0 = ']' then (
    s.pos <- s.pos + 1;
    `List []
  ) else
    items s []

and items s acc =
  let acc = read_value s :: acc in
  if next_member s ']' "Expected ',' or ']' but found" then
    items s acc
  else
    `List (List.rev acc)

let skip_or d (v : t) : t = match d with Skip -> `Null | _ -> v

let rec value_d s d : t =
  match d with
  | All ->
      read_value s
  | _ -> (
      s.mark <- s.pos;
      if not (more s) then eof_error s;
      match peek s 0 with
      | '"' -> (
          s.pos <- s.pos + 1;
          match d with
          | Skip ->
              skip_string s;
              `Null
          | _ ->
              `String (read_string s)
        )
      | '{' -> (
          s.pos <- s.pos + 1;
          match d with
          | Skip ->
              ignore (members s []);
              `Null
          | Fields fs ->
              fields_d s fs
          | _ ->
              read_object s
        )
      | '[' -> (
          s.pos <- s.pos + 1;
          match d with
          | Skip ->
              ignore (elements s ~keep:false Skip);
              `Null
          | Items d ->
              `List (elements s ~keep:true d)
          | _ ->
              read_array s
        )
      | '0' .. '9' ->
          number_d s d
      | '-' when ensure s 2 && is_digit (peek s 1) ->
          number_d s d
      | '-' when ensure s 2 && peek s 1 = 'I' ->
          skip_or d (literal s "-Infinity" (`Float neg_infinity))
      | 't' ->
          skip_or d (literal s "true" (`Bool true))
      | 'f' ->
          skip_or d (literal s "false" (`Bool false))
      | 'n' ->
          literal s "null" `Null
      | 'N' ->
          skip_or d (literal s "NaN" (`Float nan))
      | 'I' ->
          skip_or d (literal s "Infinity" (`Float infinity))
      | _ ->
          long_error s "Invalid token" 1
    )

and number_d s d =
  match d with
  | Skip ->
      skip_number s;
      `Null
  | _ ->
      read_number s

and fields_d s fs =
  let start = s.off + s.pos in
  let lnum = s.st.lnum and bol = s.st.bol and pin = s.pin in
  if start < pin then s.pin <- start;
  let acc = members s fs in
  s.pin <- pin;
  if List.for_all (fun (k, _) -> List.mem_assoc k acc) fs then
    `Assoc (List.rev acc)
  else (
    s.pos <- start - s.off;
    s.st.lnum <- lnum;
    s.st.bol <- bol;
    read_object s
  )

and members s fs =
  skip_space s;
  if more s && peek s 0 = '}' then (
    s.pos <- s.pos + 1;
    []
  ) else
    members_loop s fs []

and members_loop s fs acc =
  let ((key, d) as f) = key_field s fs in
  skip_space s;
  read_colon s;
  skip_space s;
  let acc =
    if f == no_field then (
      ignore (value_d s Skip);
      acc
    ) else
      (key, value_d s d) :: acc
  in
  if next_member s '}' "Expected ',' or '}' but found" then
    members_loop s fs acc
  else
    acc

and elements s ~keep d =
  skip_space s;
  if more s && peek s 0 = ']' then (
    s.pos <- s.pos + 1;
    []
  ) else
    elements_loop s ~keep d []

and elements_loop s ~keep d acc =
  let v = value_d s d in
  let acc =
    if keep then
      v :: acc
    else
      acc
  in
  if next_member s ']' "Expected ',' or ']' but found" then
    elements_loop s ~keep d acc
  else
    List.rev acc

let rec each_element s d f =
  let v = value_d s d in
  let d =
    match d with
    | Skip ->
        Skip
    | _ ->
        if f v then
          d
        else
          Skip
  in
  if next_member s ']' "Expected ',' or ']' but found" then each_element s d f

let toplevel s read =
  skip_space s;
  if not (more s) then json_error "Blank input data";
  let x = read s in
  skip_space s;
  if more s then long_error s "Junk after end of JSON value:" 0;
  x

let read_toplevel ?(demand = All) s = toplevel s (fun s -> value_d s demand)

exception Stop

let read_each ~demand ?each s =
  try
    toplevel s (fun s ->
        match each with
        | Some (d, f) when peek s 0 = '[' ->
            s.pos <- s.pos + 1;
            skip_space s;
            if more s && peek s 0 = ']' then
              s.pos <- s.pos + 1
            else
              each_element s d f;
            None
        | _ ->
            Some (value_d s demand)
    )
  with Stop -> None

let make ?buf ?fname ?lnum ic bytes len =
  {
    buf = bytes;
    pos = 0;
    len;
    off = 0;
    mark = 0;
    pin = max_int;
    eof = false;
    ic;
    st = init_lexer ?buf ?fname ?lnum ();
  }

(* [refill] never writes to the buffer when [ic] is [None], so the string is
   only read. *)
let string_source ?buf ?fname ?lnum str =
  make ?buf ?fname ?lnum None (Bytes.unsafe_of_string str) (String.length str)

let channel_source ?buf ?fname ?lnum ic =
  make ?buf ?fname ?lnum (Some ic) (Bytes.create 65536) 0

let from_string ?buf ?fname ?lnum ?demand str =
  read_toplevel ?demand (string_source ?buf ?fname ?lnum str)

let from_channel ?buf ?fname ?lnum ?demand ic =
  read_toplevel ?demand (channel_source ?buf ?fname ?lnum ic)

let from_file ?buf ?fname ?lnum ?demand file =
  In_channel.with_open_text file (from_channel ?buf ?fname ?lnum ?demand)

let parse what f x =
  try Ok (f x) with
  | Json_error msg ->
      Error ("JSON parse error: " ^ msg)
  | e ->
      Error (Printexc.to_string e ^ " There was an error reading " ^ what)

let parse_string ?demand = parse "the string" (fun s -> from_string ?demand s)
let parse_file ?demand = parse "the file" (fun f -> from_file ?demand f)

let parse_channel ?demand =
  parse "from standard input" (fun c -> from_channel ?demand c)

let parse_string_each ~demand ?each =
  parse "the string" (fun s -> read_each ~demand ?each (string_source s))

let parse_file_each ~demand ?each =
  parse "the file" (fun f ->
      In_channel.with_open_text f (fun ic ->
          read_each ~demand ?each (channel_source ic)
      )
  )

let parse_channel_each ~demand ?each =
  parse "from standard input" (fun c ->
      read_each ~demand ?each (channel_source c)
  )
