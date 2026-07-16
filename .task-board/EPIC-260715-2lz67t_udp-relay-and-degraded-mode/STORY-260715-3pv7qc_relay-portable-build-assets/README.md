# Portable relay builds, manifests, and supply-chain boundaries

## Description
Provide reproducible, rootless relux-relay assets and bundle metadata for Linux and macOS on x86_64 and arm64. Pin source and toolchains, expose protocol and build identity, generate verifiable manifests and notices, and prove each declared asset starts safely in its target environment.

## Scope
In scope: pinned relay source and dependencies; deterministic build entrypoints; Linux x86_64 and arm64; macOS x86_64 and arm64; rootless execution; stdio-only process boundary; build identity and self-hash support; file size and SHA-256 manifest; application-bundle asset selection metadata; CI cross-build and native or emulated smoke execution; license notices, dependency inventory, and release handoff. Out of scope: remote installation, final Apple app signing or notarization, App Store submission, organization-wide SBOM policy, destination UDP behavior, and runtime capability transitions.

## Acceptance Criteria
1. Pinned source, dependency, and toolchain inputs produce one uniquely named asset for each of the four declared OS and architecture pairs. 2. Each asset runs without root, daemonization, public listeners, or writable system locations and reports matching protocol and privacy-safe build identity over approved commands or handshake fields. 3. A generated bundle manifest records protocol version, normalized platform, file size, SHA-256, and build identity and is rejected when an asset is missing, duplicated, renamed ambiguously, or mismatched. 4. CI performs target build, checksum, stdio smoke, self-hash, and clean-exit checks and publishes required license notices and dependency provenance without fetching code at application runtime. 5. A release runbook separates M2 asset integrity responsibilities from later app signing, notarization, attestation, and distribution gates.
