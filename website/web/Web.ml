external window : Dom.window = "window"

module Window = struct
  external document : Dom.window -> Dom.document = "document" [@@mel.get]
  external location : Dom.window -> Dom.location = "location" [@@mel.get]
end

module Location = struct
  external hash : Dom.location -> string = "hash" [@@mel.get]
  external setHash : Dom.location -> string -> unit = "hash" [@@mel.set]
  external origin : Dom.location -> string = "origin" [@@mel.get]
end

module Document = struct
  external querySelector :
    string -> (Dom.document[@mel.this]) -> Dom.element option = "querySelector"
  [@@mel.send] [@@mel.return nullable]
end
