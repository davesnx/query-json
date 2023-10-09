(lang dune 3.0)

(using menhir 2.0)

(generate_opam_files true)

(cram enable)

(license MIT)

(maintainers "David Sancho <dsnxmoreno@gmail.com>")

(authors "David Sancho <dsnxmoreno@gmail.com>")

(source
 (github davesnx/query-json))

(implicit_transitive_deps false)

(version 0.5.10)

(package
 (name query-json)
 (synopsis "Faster, simpler and more portable implementation of `jq` in Reason")
 (description "query-json is a faster and simpler re-implementation of jq's language in Reason, compiled to a native binary and as a JavaScript library.

  It's a CLI to run small programs against JSON, the same idea as sed but for JSON files.

  Play around with it in the online playground: https://query-json.netlify.app")
 (depends
  ocaml
  reason
  dune
  menhir
  cmdliner
  yojson
  sedlex
  ppx_deriving

  js_of_ocaml
  js_of_ocaml-compiler
  js_of_ocaml-ppx
))

(package
 (name query-json-js)
 (synopsis "Faster, simpler and more portable implementation of `jq` in Reason. Shipped as a JavaScript library.")
 (description "query-json is a faster and simpler re-implementation of jq's language in Reason, compiled to a native binary and as a JavaScript library.

  It's a CLI to run small programs against JSON, the same idea as sed but for JSON files.

  Play around with it in the online playground: https://query-json.netlify.app")
 (depends
  ocaml
  reason
  dune
  yojson
  cmdliner
  js_of_ocaml
  js_of_ocaml-compiler
))

(package
 (name query-json-web)
 (allow_empty)
 (synopsis "query-json-web is the web playground for query-json, written in jsoo and jsoo-react.")
 (description "query-json is a faster and simpler re-implementation of jq's language in Reason, compiled to a native binary and as a JavaScript library.

  It's a CLI to run small programs against JSON, the same idea as sed but for JSON files.

  Play around with it in the online playground: https://query-json.netlify.app")
 (depends
  ocaml
  reason
  js_of_ocaml
  js_of_ocaml-compiler
  js_of_ocaml-ppx
  ppx_jsobject_conv
  brr
  jsonoo
))
