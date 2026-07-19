.PHONY: check-legacy test-legacy-guard

LEGACY_ROOT ?= ../relux-proxy

check-legacy:
	./scripts/check-legacy-preservation.sh --legacy-root "$(LEGACY_ROOT)"

test-legacy-guard:
	./scripts/tests/test-legacy-preservation-guard.sh --legacy-root "$(LEGACY_ROOT)"
