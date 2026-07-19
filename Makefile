.PHONY: check-legacy test-legacy-guard check-core-boundaries core-build core-test validate-core

LEGACY_ROOT ?= ../relux-proxy

check-legacy:
	./scripts/check-legacy-preservation.sh --legacy-root "$(LEGACY_ROOT)"

test-legacy-guard:
	./scripts/tests/test-legacy-preservation-guard.sh --legacy-root "$(LEGACY_ROOT)"

check-core-boundaries:
	./scripts/check-core-boundaries.sh

core-build:
	swift build

core-test:
	swift test

validate-core: check-core-boundaries core-test core-build
