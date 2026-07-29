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

.PHONY: repl
repl: ## Run repl with "package.json"
	$(DUNE) exec ./cli/cli.exe -- --repl package.json

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
	opam pin add toffee.dev "https://github.com/tmattio/mosaic.git#12e4c090f941442e9d55d2816873f596399eb8df" -y
	opam pin add matrix.dev "https://github.com/tmattio/mosaic.git#12e4c090f941442e9d55d2816873f596399eb8df" -y
	opam pin add mosaic.dev "https://github.com/tmattio/mosaic.git#12e4c090f941442e9d55d2816873f596399eb8df" -y


.PHONY: create-switch
create-switch: ## Create opam switch
	opam switch create . ocaml.5.5.1 --deps-only --with-test --no-install -y

.PHONY: install
install: ## Install opam deps
	opam install . --deps-only --with-test --with-doc --with-dev-setup -y

.PHONY: npm-install
npm-install: ## Install npm dependencies
	npm install

.PHONY: init
init: setup-githooks create-switch pin install npm-install ## Create a local dev enviroment

DEMO_FILES = \
	repl-demo \
	cli-basic \
	cli-advanced \
	comparison \
	jq-compat-demos/00-error-messages \
	jq-compat-demos/01-stricter-null-handling \
	jq-compat-demos/02-fn-vs-def \
	jq-compat-demos/03-snake-case-naming \
	jq-compat-demos/04-clearer-naming \
	jq-compat-demos/05-group-by-behavior \
	jq-compat-demos/06-keys-insertion-order \
	jq-compat-demos/07-unique-insertion-order \
	jq-compat-demos/08-infinite-generator \
	jq-compat-demos/09-optional-access-functions \
	jq-compat-demos/10-additional-features \
	jq-compat-demos/all-demos


.PHONY: demo
demo: demo-cast demo-gif ## Generate cast+gif demo (usage: make demo FILE=cli-basic)

.PHONY: demo-cast
demo-cast: ## Record demo cast (usage: make demo-cast FILE=cli-basic)
	@if [ -z "$(FILE)" ]; then \
		echo "Error: FILE is required. Usage: make demo FILE=repl-demo"; \
		exit 1; \
	fi
	$(DUNE) install
	@if [ "$(FILE)" = "repl-demo" ]; then \
		asciinema rec --overwrite --cols 140 --rows 48 -c "python3 docs/record-repl-demo.py" docs/repl-demo.cast; \
	elif [ -f "docs/demo-scripts/$(FILE).sh" ]; then \
		asciinema rec --overwrite --cols 140 --rows 48 -c "bash docs/demo-scripts/$(FILE).sh" "docs/$(FILE).cast"; \
	else \
		echo "Error: unknown demo '$(FILE)'. Expected docs/demo-scripts/$(FILE).sh"; \
		exit 1; \
	fi

.PHONY: demo-gif
demo-gif: ## Render demo gif from cast (usage: make demo-gif FILE=cli-basic)
	@if [ -z "$(FILE)" ]; then \
		echo "Error: FILE is required. Usage: make demo-gif FILE=repl-demo"; \
		exit 1; \
	fi
	@if [ ! -f "docs/$(FILE).cast" ]; then \
		echo "Error: docs/$(FILE).cast not found. Run: make demo-cast FILE=$(FILE)"; \
		exit 1; \
	fi
	@if ! command -v agg >/dev/null 2>&1; then \
		echo "Error: agg is required to render GIFs."; \
		echo "Install it from: https://github.com/asciinema/agg"; \
		exit 1; \
	fi
	agg "docs/$(FILE).cast" "docs/$(FILE).gif"

.PHONY: demo-all-cast
demo-all-cast: ## Record all demos as .cast files
	@for demo in $(DEMO_FILES); do \
		$(MAKE) demo-cast FILE=$$demo || exit 1; \
	done

.PHONY: demo-all-gif
demo-all-gif: ## Render all demos as .gif files
	@for demo in $(DEMO_FILES); do \
		$(MAKE) demo-gif FILE=$$demo || exit 1; \
	done

.PHONY: demo-all
demo-all: demo-all-cast demo-all-gif ## Record and render all demos

.PHONY: bench
bench: ## Run benchmarks
	./benchmarks/bench.sh

.PHONY: bench-parser
bench-parser: ## Run parser-only benchmark
	$(DUNE) exec benchmarks/bench_parser.exe

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
