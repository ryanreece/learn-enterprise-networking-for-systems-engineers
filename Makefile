.DEFAULT_GOAL := help

.PHONY: help check build lint test

help: ## Show repository commands.
	@printf '%s\n' \
	  'Enterprise Networking for Systems Engineers' \
	  '' \
	  'Repository commands:' \
	  '  make help   Show this help.' \
	  '  make check  Check host tools and Docker access without changing the host.' \
	  '  make build  Build shared images (none exist in this documentation phase).' \
	  '  make lint   Run validation available in this repository phase.' \
	  '  make test   Run repository tests (documentation validation only for now).'

check: ## Check required host commands and Docker daemon access.
	@command -v docker >/dev/null || { echo 'ERROR: docker was not found. See docs/installing-containerlab.md.' >&2; exit 1; }
	@command -v containerlab >/dev/null || { echo 'ERROR: containerlab was not found. See docs/installing-containerlab.md.' >&2; exit 1; }
	@docker info >/dev/null 2>&1 || { echo 'ERROR: Docker is installed, but this user cannot reach the daemon. See docs/troubleshooting-the-lab-environment.md.' >&2; exit 1; }
	@printf 'Docker:       %s\n' "$$(docker version --format '{{.Server.Version}}')"
	@printf 'Containerlab: %s\n' "$$(containerlab version 2>/dev/null | awk '/version:/ {print $$2; exit}')"
	@echo 'Host prerequisite check passed.'

build: ## Build repository-maintained images when they are added.
	@echo 'No repository-maintained images exist in the current documentation phase.'

lint: ## Check tracked and untracked text for whitespace errors.
	@! rg -n '[[:blank:]]+$$' --glob '*.md' --glob '*.yml' --glob '*.yaml' --glob 'Makefile' --glob '.editorconfig' --glob '.gitignore' . || { echo 'ERROR: trailing whitespace found.' >&2; exit 1; }
	@git diff --check -- .
	@echo 'Whitespace validation passed.'

test: lint ## Run tests available in the current repository phase.
	@echo 'No executable lab tests exist yet; documentation validation passed.'
