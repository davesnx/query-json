(lang dune 3.17)

(using menhir 2.0)
(using melange 0.1)

(name query-json)
(version 0.6.1)

(generate_opam_files true)

(license MIT)

(cram enable)

(maintainers "David Sancho <dsnxmoreno@gmail.com>")

(authors "David Sancho <dsnxmoreno@gmail.com>")

(source
 (github davesnx/query-json))

(implicit_transitive_deps true)

(package
 (name query-json)
 (synopsis "Faster, simpler and more portable implementation of `jq` in OCaml")
 (description "query-json is a faster and simpler re-implementation of jq's language in OCaml, compiled to a native binary (query-json) and as a JavaScript library (query-json-js).

  query-json is a CLI to run small programs against JSON, the same idea as sed but for JSON files.

  Play with it in the online playground: https://query-json.pages.dev")
 (depends
  (ocaml (>= 5.3.0))
  (dune (>= 3.17))
  dune-build-info
  (menhir (>= 20250903))
  (cmdliner (>= 1.1.0))
  (yojson (>= "3.0.0"))
  sedlex
  ppx_deriving
  easy-format
  (alcotest :with-test)
  (ocamlformat :with-dev-setup)
  (ocaml-lsp-server :with-dev-setup)
))

(package
 (name query-json-js)
 (allow_empty)
 (synopsis "The query-json-js package is the JavaScript library for query-json, compiled by js_of_ocaml")
 (description "query-json is a faster and simpler re-implementation of jq's language in OCaml, compiled to a native binary (query-json) and as a JavaScript library (query-json-js).

  Play with it in the online playground: https://query-json.pages.dev")
 (depends
  ocaml
  js_of_ocaml
  js_of_ocaml-compiler
  js_of_ocaml-ppx
))

(package
 (name query-json-playground)
 (allow_empty)
 (synopsis "The query-json-playground package is the web playground for query-json, written in reason-react and compiled by Melange")
 (description "query-json is a faster and simpler re-implementation of jq's language in OCaml, compiled to a native binary (query-json) and as a JavaScript library (query-json-js).

  Play with it in the online playground: https://query-json.pages.dev")
 (depends
  (ocaml (>= 5.3.0))
  mlx
  (melange (>= 5.0.1))
  melange-json
  reason-react
  reason-react-ppx
  (ocamlmerlin-mlx :with-dev-setup)
  (ocamlformat-mlx :with-dev-setup)
  (ocaml-lsp-server :with-dev-setup)
))

(dialect
 (name mlx)
 (implementation
  (extension mlx)
  (merlin_reader mlx)
  (format
   (run ocamlformat-mlx %{input-file}))
  (preprocess
   (run mlx-pp %{input-file}))))
