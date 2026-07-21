.PHONY: check-legacy test-legacy-guard check-core-boundaries core-build core-test \
	check-native-dependencies test-native-dependencies native-apple-matrix validate-core validate-native \
	check-reluxniossh test-reluxniossh build-reluxniossh validate-reluxniossh \
	check-libssh2 test-libssh2 test-libssh2-source-gates validate-libssh2 build-libssh2 \
	relay-protocol-generate relay-protocol-vectors-generate \
	relay-protocol-vectors-check relay-protocol-conformance-check \
	relay-protocol-hostile-diagnostics relay-protocol-check \
	relay-shell-test relay-shell-vet relay-shell-build relay-shell-release \
	relay-shell-verify relay-shell-smoke relay-shell-reproducibility relay-shell-validate \
	relay-provision-go relay-provision-syft relay-provision-tools relay-print-apple-bundle-input

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
	python3 scripts/libssh2-fork-tool.py verify

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

LIBSSH2_SOURCE_ARCHIVE ?= .temp/TASK-260720-3vwls7/libssh2-a343024.tar.gz
OPENSSL_SOURCE_ARCHIVE ?= .temp/TASK-260715-28ok1k/openssl-3.5.7.tar.gz

check-libssh2:
	python3 scripts/libssh2-fork-tool.py verify

test-libssh2:
	python3 scripts/libssh2-fork-tool.py test-rekey

test-libssh2-source-gates:
	python3 scripts/libssh2-fork-tool.py test-source-gates \
		--libssh2-archive "$(LIBSSH2_SOURCE_ARCHIVE)" \
		--openssl-archive "$(OPENSSL_SOURCE_ARCHIVE)"

build-libssh2:
	python3 scripts/libssh2-fork-tool.py build-xcframework \
		--libssh2-archive "$(LIBSSH2_SOURCE_ARCHIVE)" \
		--openssl-archive "$(OPENSSL_SOURCE_ARCHIVE)" \
		--output NativeDependencies/Artifacts/ReluxLibSSH2.xcframework

RELAY_PROTOCOL_ENV = LC_ALL=C LANG=C TZ=UTC PYTHONHASHSEED=0

RELAY_HOST_OS ?= $(shell uname -s | tr '[:upper:]' '[:lower:]')
RELAY_HOST_ARCH ?= $(shell uname -m | sed -e 's/^x86_64$$/amd64/' -e 's/^aarch64$$/arm64/')
RELAY_TOOLCHAIN_ROOT ?= $(CURDIR)/.build/relay/toolchains
RELAY_GO_INSTALL ?= $(RELAY_TOOLCHAIN_ROOT)/go1.26.5-$(RELAY_HOST_OS)-$(RELAY_HOST_ARCH)
RELAY_SYFT_INSTALL ?= $(RELAY_TOOLCHAIN_ROOT)/syft1.48.0-$(RELAY_HOST_OS)-$(RELAY_HOST_ARCH)
RELAY_GO ?= $(RELAY_GO_INSTALL)/go/bin/go
RELAY_GOROOT ?= $(RELAY_GO_INSTALL)/go
RELAY_GO_TOOLCHAIN ?= local
RELAY_SYFT ?= $(RELAY_SYFT_INSTALL)/syft
RELAY_GO_ARCHIVE ?=
RELAY_SYFT_ARCHIVE ?=
RELAY_VERSION ?=
SOURCE_COMMIT ?=
RELAY_APPLE_BUNDLE_INPUT ?= .build/relay/apple-bundle-input
RELAY_PROTOCOL_TEST_OUTPUT ?= .build/relay/protocol-tests
RELAY_REPRO_BUNDLE_INPUT ?= .build/relay/repro/apple-bundle-input
RELAY_REPRO_TEST_OUTPUT ?= .build/relay/repro/protocol-tests

RELAY_BUILD_ARGUMENTS = \
	--go "$(RELAY_GO)" \
	--go-toolchain "$(RELAY_GO_TOOLCHAIN)" \
	--syft "$(RELAY_SYFT)" \
	--relay-version "$(RELAY_VERSION)" \
	--source-commit "$(SOURCE_COMMIT)" \
	--require-provenance

RELAY_GO_ENV = \
	GOROOT="$(RELAY_GOROOT)" \
	GOTOOLCHAIN="$(RELAY_GO_TOOLCHAIN)" \
	GOENV=off \
	GOCACHE="$(CURDIR)/.temp/relay-go-cache" \
	GOPATH="$(CURDIR)/.temp/relay-go-path" \
	CGO_ENABLED=0

relay-shell-test:
	cd relay && RELUX_TUNNEL_REPO_ROOT="$(CURDIR)" $(RELAY_GO_ENV) "$(RELAY_GO)" test ./...
	python3 -m unittest scripts/tests/test_relay_release.py

relay-shell-vet:
	cd relay && RELUX_TUNNEL_REPO_ROOT="$(CURDIR)" $(RELAY_GO_ENV) "$(RELAY_GO)" vet ./...

relay-provision-go:
	python3 scripts/relay_release.py provision-go \
		--archive "$(RELAY_GO_ARCHIVE)" \
		--destination "$(RELAY_GO_INSTALL)"

relay-provision-syft:
	python3 scripts/relay_release.py provision-syft \
		--archive "$(RELAY_SYFT_ARCHIVE)" \
		--destination "$(RELAY_SYFT_INSTALL)"

relay-provision-tools: relay-provision-go relay-provision-syft

relay-shell-build:
	python3 scripts/relay_release.py build \
		$(RELAY_BUILD_ARGUMENTS) \
		--output "$(RELAY_APPLE_BUNDLE_INPUT)" \
		--test-output "$(RELAY_PROTOCOL_TEST_OUTPUT)"

relay-shell-release:
	python3 scripts/relay_release.py build \
		$(RELAY_BUILD_ARGUMENTS) \
		--require-clean \
		--output "$(RELAY_APPLE_BUNDLE_INPUT)" \
		--test-output "$(RELAY_PROTOCOL_TEST_OUTPUT)"

relay-shell-verify:
	python3 scripts/relay_release.py verify \
		--go "$(RELAY_GO)" \
		--go-toolchain "$(RELAY_GO_TOOLCHAIN)" \
		--require-provenance \
		--output "$(RELAY_APPLE_BUNDLE_INPUT)" \
		--test-output "$(RELAY_PROTOCOL_TEST_OUTPUT)"

relay-shell-smoke:
	./scripts/tests/test-relay-shell-artifacts.sh \
		"$(RELAY_APPLE_BUNDLE_INPUT)" \
		"$(RELAY_PROTOCOL_TEST_OUTPUT)" \
		"$(RELAY_VERSION)" \
		"$(SOURCE_COMMIT)"

relay-shell-reproducibility: relay-shell-build
	python3 scripts/relay_release.py build \
		$(RELAY_BUILD_ARGUMENTS) \
		--output "$(RELAY_REPRO_BUNDLE_INPUT)" \
		--test-output "$(RELAY_REPRO_TEST_OUTPUT)"
	python3 scripts/relay_release.py compare \
		--first "$(RELAY_APPLE_BUNDLE_INPUT)" \
		--second "$(RELAY_REPRO_BUNDLE_INPUT)" \
		--first-tests "$(RELAY_PROTOCOL_TEST_OUTPUT)" \
		--second-tests "$(RELAY_REPRO_TEST_OUTPUT)"

relay-shell-validate: relay-shell-test relay-shell-vet relay-shell-reproducibility relay-shell-verify relay-shell-smoke

relay-print-apple-bundle-input:
	@echo "$(RELAY_APPLE_BUNDLE_INPUT)"

relay-protocol-generate:
	env $(RELAY_PROTOCOL_ENV) python3 scripts/relay-protocol-tool.py generate

relay-protocol-vectors-generate:
	env $(RELAY_PROTOCOL_ENV) python3 scripts/relay-protocol-vectors.py generate

relay-protocol-vectors-check:
	env $(RELAY_PROTOCOL_ENV) python3 scripts/relay-protocol-vectors.py check

relay-protocol-conformance-check: relay-protocol-vectors-check
	./scripts/tests/test-relay-protocol-go.sh -v
	swift test --filter RelayProtocol

relay-protocol-hostile-diagnostics:
	./scripts/tests/test-relay-protocol-go.sh -run TestHostileInputCorpus -count=1 -gcflags=all=-d=checkptr=2
	swift test --sanitize=address --filter RelayProtocolHostileInputTests

relay-protocol-check: relay-protocol-conformance-check
	env $(RELAY_PROTOCOL_ENV) python3 scripts/relay-protocol-tool.py check
	swift build

validate-libssh2: check-libssh2 test-libssh2
