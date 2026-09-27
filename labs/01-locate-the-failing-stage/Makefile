.DEFAULT_GOAL := help

.PHONY: help check build deploy baseline status verify destroy

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
	  '  make status    Show topology and node state.' \
	  '  make verify    Verify the original DNS and HTTPS transaction.' \
	  '  make destroy   Remove this topology and its generated state.'

check: ## Validate Lab 01 prerequisites.
	@./scripts/check-prerequisites.sh

build: ## Build the local client, router, and DNS images.
	@$(MAKE) --no-print-directory -C ../.. build
	@./scripts/build-images.sh

deploy: ## Deploy the known-good topology.
	@./scripts/deploy.sh

baseline: ## Prove every stage of the known-good transaction.
	@./scripts/baseline.sh

status: ## Show topology and node state.
	@./scripts/status.sh

verify: ## Verify the original transaction without repairing it.
	@./scripts/verify.sh

destroy: ## Remove only this lab's topology and generated state.
	@./scripts/destroy.sh
