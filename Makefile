project_name = query-json
opam_file = $(project_name).opam
DUNE = opam exec -- dune
VITE = ./node_modules/.bin/vite

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
	$(DUNE) build --profile=release @all
	$(DUNE) install

.PHONY: dev
dev: ## Build everything in watch mode
	$(DUNE) build -w @all

.PHONY: dev-core
dev-core: ## Build in watch mode
	$(DUNE) build -w source

.PHONY: web-dev
web-dev: ## Build and serve the website via HMR
	$(VITE) --host --config website/vite.config.js --force

.PHONY: web-clean
web-clean: ## Clear Vite's cache
	rm -rf node_modules/.vite

.PHONY: web-build
web-build: ## Bundle the website
	$(VITE) build --config website/vite.config.js

.PHONY: web-preview
web-preview: ## Preview the website
	$(VITE) preview --config website/vite.config.js

.PHONY: web-serve
web-serve: ## Serve the dist directory
	npx serve dist

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

.PHONY: format
format: ## Format the codebase with ocamlformat
	@DUNE_CONFIG__GLOBAL_LOCK=disabled $(DUNE) build @fmt --auto-promote

.PHONY: format-check
format-check: ## Checks if format is correct
	@DUNE_CONFIG__GLOBAL_LOCK=disabled $(DUNE) build @fmt

.PHONY: subst
subst: ## Run dune substitute
	$(DUNE) subst

.PHONY: pin
pin: # pin dependencies
	echo "No pinning needed"

.PHONY: create-switch
create-switch: ## Create opam switch
	opam switch create . 5.3.0 --deps-only --with-test --no-install -y

.PHONY: install
install: ## Install opam deps
	opam install . --deps-only --with-test --with-doc --with-dev-setup -y

.PHONY: npm-install
npm-install: ## Install npm dependencies
	npm install

.PHONY: init
init: setup-githooks create-switch pin install npm-install ## Create a local dev enviroment

.PHONY: bench
bench: ## Run benchmarks
	./benchmarks/bench.sh

.PHONY: release
release: ## Create a new release (usage: make release VERSION=1.2.3)
	@if [ -z "$(VERSION)" ]; then \
		echo "Error: VERSION is required. Usage: make release VERSION=1.2.3"; \
		exit 1; \
	fi
	@echo "Creating release $(VERSION)"
	@sed -i.bak "s/^(version .*)/(version $(VERSION))/" dune-project && rm -f dune-project.bak
	@$(DUNE) build
	@git add dune-project *.opam
	@git commit -m "Bump version to $(VERSION)"
	@git push origin main
	@git tag -d $(VERSION) 2>/dev/null || true
	@git push origin :refs/tags/$(VERSION) 2>/dev/null || true
	@git tag $(VERSION)
	@git push origin $(VERSION)
	@echo "Release $(VERSION) created and pushed!"
