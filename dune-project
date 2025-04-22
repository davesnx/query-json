(lang dune 3.12)

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
 (description "query-json is a faster and simpler re-implementation of jq's language in OCaml, compiled to a native binary and as a JavaScript library.

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
  easy-format

  js_of_ocaml
  js_of_ocaml-compiler
  js_of_ocaml-ppx

  (alcotest :with-test)
))

(package
 (name query-json-playground)
 (allow_empty)
 (synopsis "query-json-playground is the web playground for query-json, written in jsoo and jsoo-react.")
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
