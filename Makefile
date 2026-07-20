.PHONY: check-legacy test-legacy-guard check-core-boundaries core-build core-test \
	check-native-dependencies test-native-dependencies native-apple-matrix validate-core validate-native \
	check-reluxniossh test-reluxniossh build-reluxniossh validate-reluxniossh

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

check-native-dependencies:
	./scripts/native-dependency-tool.py verify --dependency relux-native-fixture

test-native-dependencies:
	./scripts/tests/test-native-dependencies.sh

native-apple-matrix:
	./scripts/build-native-apple-matrix.sh

validate-core: check-core-boundaries check-native-dependencies core-test core-build

validate-native: check-core-boundaries check-native-dependencies test-native-dependencies native-apple-matrix core-test core-build

check-reluxniossh:
	python3 scripts/reluxniossh-fork-tool.py verify

test-reluxniossh:
	cd Dependencies/ReluxNIOSSH && swift test

build-reluxniossh:
	cd Dependencies/ReluxNIOSSH && swift build

validate-reluxniossh: check-reluxniossh test-reluxniossh build-reluxniossh
