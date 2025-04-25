project_name = query-json
opam_file = $(project_name).opam
DUNE = opam exec -- dune
NPX = npx

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

.PHONY: web-dev
web-dev: ## Build and serve the website via HMR
	$(NPX) vite --host

.PHONY: web-build
web-build: ## Bundle the website
	$(NPX) vite build

.PHONY: web-preview
web-preview: ## Preview the website
	$(NPX) vite preview

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

.PHONY: setup-githooks
setup-githooks: ## Setup githooks
	git config core.hooksPath .githooks

.PHONY: deps
deps: $(opam_file) ## Alias to update the opam file and install the needed deps

.PHONY: format
format: ## Format the codebase with ocamlformat
	@DUNE_CONFIG__GLOBAL_LOCK=disabled $(DUNE) build @fmt --auto-promote

.PHONY: format-check
format-check: ## Checks if format is correct
	@DUNE_CONFIG__GLOBAL_LOCK=disabled $(DUNE) build @fmt

.PHONY: pin
pin: ## Pin dependencies
	echo "Nothing to pin"

.PHONY: create-switch
create-switch: ## Create opam switch
	opam switch create . 5.2.1 --deps-only --with-test -y

.PHONY: install
install: ## Install opam deps
	opam install . --deps-only --with-test --with-doc --with-dev-setup -y

.PHONY: npm-install
npm-install: ## Install npm dependencies
	npm install

.PHONY: init
init: setup-githooks create-switch pin install install-npm ## Create a local dev enviroment
