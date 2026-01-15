external window : Dom.window = "window"

module Window = struct
  external document : Dom.window -> Dom.document = "document" [@@mel.get]
  external location : Dom.window -> Dom.location = "location" [@@mel.get]

  external add_event_listener :
    Dom.window -> string -> (Dom.keyboardEvent -> unit) -> unit
    = "addEventListener"
  [@@mel.send]

  external remove_event_listener :
    Dom.window -> string -> (Dom.keyboardEvent -> unit) -> unit
    = "removeEventListener"
  [@@mel.send]
end

module KeyboardEvent = struct
  external key : Dom.keyboardEvent -> string = "key" [@@mel.get]
end

module Location = struct
  external hash : Dom.location -> string = "hash" [@@mel.get]
  external setHash : Dom.location -> string -> unit = "hash" [@@mel.set]
  external origin : Dom.location -> string = "origin" [@@mel.get]
  external pathname : Dom.location -> string = "pathname" [@@mel.get]
end

module Document = struct
  external querySelector :
    string -> (Dom.document[@mel.this]) -> Dom.element option = "querySelector"
  [@@mel.send] [@@mel.return nullable]
end

module History = struct
  type t

  external history : Dom.window -> t = "history" [@@mel.get]

  external pushState : t -> 'a Js.nullable -> string -> string -> unit
    = "pushState"
  [@@mel.send]
end
