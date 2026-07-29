(lang dune 3.17)

(using melange 0.1)

(name query-json)
(version 1.0.0~beta-1)

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
  (ocaml (>= 5.5.1))
  dune-build-info
  (cmdliner (>= 1.1.0))
  sedlex
  ppx_deriving
  mosaic
  zarith
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
  zarith_stubs_js
))

(package
 (name query-json-playground)
 (allow_empty)
 (synopsis "The query-json-playground package is the web playground for query-json, written in reason-react and compiled by Melange")
 (description "query-json is a faster and simpler re-implementation of jq's language in OCaml, compiled to a native binary (query-json) and as a JavaScript library (query-json-js).

  Play with it in the online playground: https://query-json.pages.dev")
 (depends
  (ocaml (>= 5.5.1))
  (mlx (>= 0.11))
  (melange (>= 5.0.1))
  melange-json
   (reason-react (>= 0.17.0))
   (reason-react-ppx (>= 0.17.0))
  (ocamlmerlin-mlx :with-dev-setup)
  (ocamlformat-mlx (and (>= "0.29.0.0") :with-dev-setup))
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
