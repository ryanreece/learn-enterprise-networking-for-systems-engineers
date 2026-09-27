.DEFAULT_GOAL := help

.PHONY: help check build deploy baseline client status scenario reset verify destroy test

help: ## Show Lab 01 commands available in this implementation slice.
	@printf '%s\n' \
	  'Lab 01: Locate the Failing Stage of a Connection' \
	  '' \
	  'Commands:' \
	  '  make help      Show this help.' \
	  '  make check     Validate prerequisites without changing the lab.' \
	  '  make build     Build the repository-maintained client and router images.' \
	  '  make deploy    Generate local state and deploy the known-good topology.' \
	  '  make baseline  Prove DNS, routing, TCP, TLS, and HTTPS behavior.' \
	  '  make client    Open a key-authenticated SSH session to the client.' \
	  '  make status    Show topology and node state.' \
	  '  make scenario SCENARIO=<name>' \
	  '                 Apply a named failure from the known-good baseline.' \
	  '  make reset     Restore the known-good state and verify it.' \
	  '  make verify    Verify the original DNS and HTTPS transaction.' \
	  '  make destroy   Remove this topology and its generated state.' \
	  '  make test      Exercise every implemented scenario and clean up.'

check: ## Validate Lab 01 prerequisites.
	@./scripts/check-prerequisites.sh

build: ## Build the local client, router, and DNS images.
	@$(MAKE) --no-print-directory -C ../.. build
	@./scripts/build-images.sh

deploy: ## Deploy the known-good topology.
	@./scripts/deploy.sh

baseline: ## Prove every stage of the known-good transaction.
	@./scripts/baseline.sh

client: ## Open an SSH session to the diagnostic client.
	@./scripts/client-shell.sh

status: ## Show topology and node state.
	@./scripts/status.sh

scenario: ## Apply a named failure scenario.
	@./scripts/scenario.sh "$(SCENARIO)"

reset: ## Restore and verify the known-good state.
	@./scripts/reset.sh

verify: ## Verify the original transaction without repairing it.
	@./scripts/verify.sh

destroy: ## Remove only this lab's topology and generated state.
	@./scripts/destroy.sh

test: build ## Exercise the implemented scenario lifecycle.
	@./tests/test-dns-failure.sh
	@./tests/test-return-route.sh
