# Add the relay release build and conformance CI matrix

## Description
Orchestrate the pinned relay release inputs across the declared Linux and macOS architectures, consume canonical protocol tests, and expose checksums and manifest inputs to downstream supply-chain gates.

## Scope
In scope: Linux x86_64 and arm64, macOS x86_64 and arm64, pinned toolchains and dependencies, clean builds, unique artifact names, protocol conformance, stdio and self-hash smoke, native or approved emulated execution, checksums, intermediate manifest data, deterministic metadata, and matrix failure aggregation. Out of scope: defining reproducibility policy, authoring SBOMs or notices, Apple bundle signing, remote installation, and publishing production releases.

## Acceptance Criteria
1. The workflow produces one uniquely named candidate per declared OS and architecture from pinned inputs and fails on missing, duplicate, or undeclared outputs. 2. Every candidate passes canonical protocol, stdio-boundary, build-identity, self-hash, clean-exit, and target execution smoke checks. 3. Matrix metadata includes source, dependency lock, toolchain, target, size, and SHA-256 for downstream manifest and provenance tasks. 4. Cross-build and emulator use is explicit and at least one approved native or equivalent smoke route exists for every declared target. 5. Any mutable fetch, target mismatch, checksum mismatch, protocol skew, executable-boundary violation, or partial matrix failure blocks the workflow.
