---
name: opam
description: opam is the package manager for ocaml packages. This skill teaches you how to use it
---

# My Skill

## When to Use

- Use this skill when you need to run any command from our dependencies like `dune`. For example `dune build`, you would wrap it with `opam exec -- dune build`
- This skill is helpful for knowing how to use opam properly

## Instructions

- Install a package: `opam install {{package}} -y`
- Pin a package from a github URL `opam pin add {{package}}.dev "{{URL}}" -y`. For example: `opam pin add toffee.dev "https://github.com/davesnx/mosaic.git#20c70887e8357200e2b794cd9dd12095404cabaf" -y`
- Domain-specific conventions
- Best practices and patterns
