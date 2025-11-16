external btoa : string -> string = "btoa"
external atob : string -> string = "atob"

let encode text = match btoa text with v -> Some v | exception _ -> None
let decode text = match atob text with v -> Some v | exception _ -> None
