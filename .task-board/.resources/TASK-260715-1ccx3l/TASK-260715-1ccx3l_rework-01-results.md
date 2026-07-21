# TASK-260715-1ccx3l rework 01 results

## Provenance enforcement

Release Make entry points now select repository-local preprovisioned tools, force GOTOOLCHAIN=local, and never invoke automatic Go acquisition. Offline provision-go and provision-syft commands accept an existing official host archive, verify the pinned filename and SHA-256 before extraction, retain that archive, and emit a canonical path-free provenance receipt. Every release build rechecks the receipt and archive and compares installed Go driver, assembler, compiler, and linker or the Syft executable against the accepted archive member.

Go is exact go1.26.5 with the four accepted Darwin/Linux amd64/arm64 archive hashes. Syft is exact 1.48.0, commit 3e2bc6ed095f7ec1a415fb38cfe1c319e95dfed6, with the four official host archive hashes. Structured Syft identity requires Application, Version, GitCommit, GitDescription, and Platform. Build and SBOM work is offline after provisioning.

## Negative coverage

Eleven Python release-tool tests pass. They reject missing Go, older and newer Go, wrong Go host architecture, nonlocal automatic toolchain selection, wrong Go archive checksum, Syft version-only output, wrong Syft commit, wrong Syft platform, wrong Syft archive checksum, substituted installed Syft bytes, and path-bearing or noncanonical provenance. Real tampered Go and Syft archive provisioning attempts were also rejected. The release target rejected the dirty checkout as required.

## Build and test evidence

The accepted Darwin arm64 Go archive verified as efb87ff28af9a188d0536ef5d42e63dd52ba8263cd7344a993cc48dd11dedb6a. The accepted Darwin arm64 Syft archive verified as fef3e6d5df336a0a4c3e421e503119d1e221cf82a3ef5e426a791fcd81667e87 and reported the pinned commit.

make relay-shell-validate with version 0.1.0 and the checkout revision passed after final changes. It built the four relay and four protocol-test artifacts twice; every executable pair was byte-identical. Mach-O x86_64 and arm64 plus static ELF x86-64 and aarch64 formats, exact build metadata, strict manifest schema, sorted checksums, SPDX 2.3 package policy, Go and repository notices, Apple bundle input, deterministic smoke output, and the two-case protocol-test entry point all verified. Darwin arm64 ran natively; Darwin amd64 passed under Rosetta and remains a native Intel release-CI gate. Linux amd64 and arm64 remain native release-CI gates and are not local passes.

Additional passing gates: Go unit tests, Go race tests, Go vet, gofmt, Python compile and tests, ShellCheck, relay protocol vectors and regeneration, Go conformance, 57 Swift relay protocol tests, Swift build, core boundaries/native dependency checks, and the full 306-test make validate-core rerun. git diff --check and the versionable privacy scan pass. One first-run packet-fuzz counter mismatch outside this task passed its isolated seven-test rerun and the immediate full validation rerun without source changes; it is recorded in LOGBOOK.md. No raw spawn log, host identifier, absolute local path, credential, payload, or remote-controlled string is attached.