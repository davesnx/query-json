(lang dune 3.17)

(using menhir 2.0)
(using melange 0.1)

(generate_opam_files true)

(license MIT)

(cram enable)

(maintainers "David Sancho <dsnxmoreno@gmail.com>")

(authors "David Sancho <dsnxmoreno@gmail.com>")

(source
 (github davesnx/query-json))

(implicit_transitive_deps true)

(version 0.5.10)

(package
 (name query-json)
 (synopsis "Faster, simpler and more portable implementation of `jq` in OCaml")
 (description "query-json is a faster and simpler re-implementation of jq's language in OCaml, compiled to a native binary (query-json) and as a JavaScript library (query-json-js).

  query-json is a CLI to run small programs against JSON, the same idea as sed but for JSON files.

  Play with it in the online playground: https://query-json.netlify.app")
 (depends
  ocaml
  reason
  dune
  menhir
  cmdliner
  yojson
  sedlex
  ppx_deriving
  easy-format

  js_of_ocaml
  js_of_ocaml-compiler
  js_of_ocaml-ppx

  (alcotest :with-test)
))

(package
 (name query-json-js)
 (allow_empty)
 (synopsis "query-json-js is the JavaScript library for query-json, compiled by js_of_ocaml")
 (description "query-json is a faster and simpler re-implementation of jq's language in OCaml, compiled to a native binary (query-json) and as a JavaScript library (query-json-js).

  Play with it in the online playground: https://query-json.netlify.app")
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

(package
 (name query-json-playground)
 (allow_empty)
 (synopsis "query-json-playground is the web playground for query-json, written in reason-react and compiled by Melange.")
 (description "query-json is a faster and simpler re-implementation of jq's language in OCaml, compiled to a native binary (query-json) and as a JavaScript library (query-json-js).

  Play with it in the online playground: https://query-json.netlify.app")
 (depends
  ocaml
  reason
  melange
  melange-json
  melange-webapi
  reason-react
  reason-react-ppx
))
