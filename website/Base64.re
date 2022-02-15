open Brr;

let error_to_string = e => e |> Jv.Error.message |> Jstr.to_string;

let encode = text => {
  text
  |> Jstr.v
  |> Base64.data_utf_8_of_jstr
  |> Base64.encode
  |> Result.map(Jstr.to_string)
  |> Result.to_option;
};

let decode = text => {
  switch (text |> Jstr.of_string |> Base64.decode) {
  | Ok(dec) =>
    switch (Base64.data_utf_8_to_jstr(dec)) {
    | Ok(str) => Some(Jstr.to_string(str))
    | Error(e) =>
      Printf.eprintf("decode 1 %s", e |> error_to_string);
      None;
    }
  | Error(e) =>
    Printf.eprintf("decode 2 %s", e |> error_to_string);
    None;
  };
};
