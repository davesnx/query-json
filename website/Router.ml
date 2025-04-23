let getHash () = None

(* let getHash = () =>
   try(Some(Url.Current.get_fragment() |> Url.urldecode)) {
   | _ => None
   }; *)

let setHash _hash = ()

(* let setHash = (hash): unit => {
     Url.Current.set_fragment(hash |> Url.urlencode(~with_plus=true));
   };
    *)
