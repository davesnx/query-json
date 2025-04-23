let encode text =
  match Webapi.Base64.btoa text with v -> Some v | exception _ -> None

let decode text =
  match Webapi.Base64.atob text with v -> Some v | exception _ -> None
