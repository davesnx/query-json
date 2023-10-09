project_name = query-json

DUNE = opam exec -- dune
opam_file = $(project_name).opam

.PHONY: help
help: ## Print this help message
	@echo "";
	@echo "List of available make commands";
	@echo "";
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}';
	@echo "";

.PHONY: build
build: ## Build the project, including non installable libraries and executables
	$(DUNE) build @all

.PHONY: build-prod
build-prod: ## Build for production (--profile=prod)
	$(DUNE) build --profile=prod @all

.PHONY: dev
dev: ## Build in watch mode
	$(DUNE) build -w @all

.PHONY: clean
clean: ## Clean artifacts
	$(DUNE) clean

.PHONY: test
test: ## Run the unit tests
	$(DUNE) build @runtest

.PHONY: test-watch
test-watch: ## Run the unit tests in watch mode
	$(DUNE) build @runtest -w

.PHONY: test-promote
test-promote: ## Updates snapshots and promotes it to correct
	$(DUNE) build @runtest --auto-promote

.PHONY: deps
deps: $(opam_file) ## Alias to update the opam file and install the needed deps

.PHONY: format
format: ## Format the codebase with ocamlformat
	$(DUNE) build @fmt --auto-promote

.PHONY: format-check
format-check: ## Checks if format is correct
	$(DUNE) build @fmt

.PHONY: pin
pin: ## Pin dependencies
	opam pin add jsoo-react.dev "git+https://github.com/ml-in-barcelona/jsoo-react.git#8fda15c39665ac27841c7659422f82ac331e0a01" -y
	opam pin add jsoo-css.dev "git+https://github.com/ml-in-barcelona/jsoo-css.git#8169b6764eab18d4cb98ce8f791cd47a54b1e954" -y

.PHONY: create-switch
create-switch: ## Create opam switch
	opam switch create . 5.1.0 --deps-only --with-test -y

.PHONY: install
install: create-switch pin ## Install dependencies

.PHONY: init
init: install ## Create a local dev enviroment

.PHONY: subst
subst: ## Run dune substitute
	$(DUNE) subst

$(opam_file): dune-project ## Update the package dependencies when new deps are added to dune-project
	$(DUNE) build @install
	opam install . --deps-only --with-test # Install the new dependencies
