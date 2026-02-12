# opam Documentation

opam is the OCaml package manager. It handles installing, upgrading, and managing OCaml compilers, tools, and libraries.

**Source:** [https://opam.ocaml.org/doc/](https://opam.ocaml.org/doc/)

## Installation

### Binary Distribution (Quickest)

**Linux/macOS:**
```bash
bash -c "sh <(curl -fsSL https://opam.ocaml.org/install.sh)"
```

**Windows PowerShell:**
```powershell
Invoke-Expression "& { $(Invoke-RestMethod https://opam.ocaml.org/install.ps1) }"
```

This checks your architecture, downloads the proper binary, backs up opam data if upgrading, and runs `opam init`.

**Manual binary install:**
```bash
sudo install <downloaded file> /usr/local/bin/opam
```

### System Package Managers

| System | Command |
|--------|---------|
| Arch Linux | `pacman -S opam` |
| Debian/Ubuntu | `apt install opam` |
| Fedora | `dnf install opam` |
| Mageia | `urpmi opam` |
| Alpine Linux | `apk add opam` |
| OpenBSD | `pkg_add opam` |
| FreeBSD | `pkg install ocaml-opam` |
| macOS (Homebrew) | `brew install opam` |
| macOS (MacPorts) | `port install opam` |
| Guix | `guix install opam` |
| Windows | `winget install Git.Git OCaml.opam` |

### From Sources

Sources available at [Opam releases on Github](https://github.com/ocaml/opam/releases). Follow the `README.md` instructions.

### Upgrading

Reproduce the same installation steps. opam auto-updates its internal repository at `~/.opam` on first run.

For shell scripts and sandboxing, run:
```bash
opam init --reinit -ni
```

## Basic Usage

### Getting Help
```bash
opam --help
opam <command> --help
```

### Essential Commands

```bash
# Initialize opam (creates ~/.opam)
opam init

# List all available packages
opam list -a

# Search packages by name or description
opam search QUERY

# Show package information
opam show PACKAGE

# Install a package and its dependencies
opam install PACKAGE

# Uninstall a package
opam remove PACKAGE

# Update package database
opam update

# Upgrade all installed packages to latest versions
opam upgrade

# Command-specific manpage
opam CMD --help
```

### Browsing Packages

Browse packages online at [opam.ocaml.org/packages](https://opam.ocaml.org/packages/).

If a package exists online but not locally, run `opam update` to refresh the package database.

## opam init

Creates the `~/.opam` directory with opam's internal state. Automatically picks a compiler to install unless `--bare` is specified.

Sets shell environment variables. You'll be prompted to configure your shell, or can manually source the environment:

```bash
eval $(opam env)
```

## Switches

Switches are independent OCaml environments with their own compiler version and installed packages.

```bash
# List switches
opam switch list

# Create a new switch with a specific compiler
opam switch create <switch-name> <compiler-version>

# Switch to a different environment
opam switch <switch-name>

# Create a local switch in current directory
opam switch create . <compiler-version>
```

Local switches create a `_opam/` directory. The installation prefix becomes `/_opam/`.

## Packaging

An opam package is defined by a `<pkgname>.opam` file containing metadata.

### Creating a Package Definition

From your project root:
```bash
opam pin .
```

Or create `<pkgname>.opam` manually:

```
opam-version: "2.0"
name: "project"
version: "0.1"
synopsis: "One-line description"
description: """
Longer description
"""

maintainer: "Name <email>"
authors: "Name <email>"
license: ""
homepage: ""
bug-reports: ""
dev-repo: ""
depends: [ "ocaml" "ocamlfind" ]
build: [
  ["./configure" "--prefix=%{prefix}%"]
  [make]
]
install: [make "install"]
```

### For Dune Projects

Skip `install:` field and use:
```
build: ["dune" "build" "-p" name "-j" jobs]
```

### Validating

```bash
opam lint
```

### Testing Locally

```bash
git add *.opam && git commit
opam install .
```

### Publishing

Uses GitHub pull-request mechanism to [opam-repository](https://github.com/ocaml/opam-repository).

```bash
opam publish --help
```

## FAQ Highlights

### What is opam for?

Installing, upgrading, and managing OCaml compilers, tools, and libraries. Consists of the opam package manager tool and a community-maintained package repository.

### What does opam do to my filesystem?

opam only writes to:
- `~/.opam` (configuration, internal data, cache, OCaml installations)
- `/tmp` (temporary files)

For local switches, also writes to `/_opam/` in the specified directory.

Since opam 2.0.0~rc2, package build/install/remove runs in a sandbox (bwrap on Linux, sandbox-exec on macOS).

### Why does opam require bwrap?

opam uses [bubblewrap](https://github.com/containers/bubblewrap) on Linux to sandbox package instructions, preventing packages from writing outside their allotted filesystem space or accessing the network.

View sandboxing configuration:
```bash
opam init --show-default-opamrc
```

### Where is the manual?

- `opam --help` for quick reference
- [Usage guide](https://opam.ocaml.org/doc/Usage.html)
- [Packaging Howto](https://opam.ocaml.org/doc/Packaging.html)
- [Manual](https://opam.ocaml.org/doc/Manual.html) for internals and file formats
- [Library APIs](https://opam.ocaml.org/doc/api/)

## Advanced Tricks

### Simulate Actions (Debugging)

```bash
# Stop at action summary dialog
opam upgrade --show-actions

# Display only, no changes
opam upgrade --dry-run

# Export state, test in temporary switch, then import with --fake
opam switch export testing-state.export
opam switch create tmp-testing --empty
opam switch import testing-state.export --fake
# Revert:
opam switch <previous>; opam switch remove tmp-testing
```

### Install in All Switches

```bash
for switch in $(opam switch list -s); do
  opam install --switch $switch PACKAGE
done
```

Add `--yes` if confident.

### Update opam Environment in Emacs

Install `opam-user-setup`:
```bash
opam user-setup install
```

This provides `opam-update-env` in Emacs.

Or define manually in Emacs:
```elisp
(defun opam-env ()
  (interactive nil)
  (dolist (var (car (read-from-string (shell-command-to-string
    "opam config env --sexp"))))
    (setenv (car var) (cadr var))))
```

### Share Package Sets

Create a package with dependencies and host as a Gist (file must be named `opam`):

```
opam-version: "2.0"
name: "ocaml101"
version: "0.1"
maintainer: "Your Name <email>"
depends: [ "menhir" { = "20140422" }
           "merlin" { >= "2" }
           "ocp-indent"
           "ocp-index" ]
```

Then pin it:
```bash
opam pin add ocaml101 <HTTPS clone URL>
```

## Environment

After installing packages, load the environment:
```bash
eval $(opam env)
```

Or configure your shell profile during `opam init`.

## External Solvers

opam can use external CUDF solvers for dependency resolution:
```bash
opam <request> --cudf=cudf-file
opam config cudf-universe >cudf-file-1.cudf
aspcud cudf-file-1.cudf /dev/stdout CRITERIA
```

## Docker Images

For CI, use pre-built Docker images instead of the install script: [Docker images for various configurations](https://hub.docker.com/r/ocaml/opam/).

## Resources

- **Package Repository:** [opam.ocaml.org/packages](https://opam.ocaml.org/packages/)
- **GitHub:** [github.com/ocaml/opam](https://github.com/ocaml/opam)
- **opam-repository:** [github.com/ocaml/opam-repository](https://github.com/ocaml/opam-repository)
- **Commercial Support:** [OCamlPro](https://ocamlpro.com/)
