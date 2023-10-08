(lang dune 3.0)

(using menhir 2.0)

(generate_opam_files true)

(license MIT)

(maintainers "David Sancho <dsnxmoreno@gmail.com>")

(authors "David Sancho <dsnxmoreno@gmail.com>")

(source
 (github davesnx/query-json))

(implicit_transitive_deps false)

(version 0.5.10)

(package
 (name query-json)
 (synopsis "")
 (description "")
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
 (synopsis "")
 (description "")
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
 (synopsis "")
 (description "")
 (depends
  ocaml
  reason

  brr
  js_of_ocaml
  js_of_ocaml-compiler
  js_of_ocaml-ppx
  jsonoo
  ppx_jsobject_conv
))
