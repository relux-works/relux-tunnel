# Establish the pinned portable relay build toolchain

## Description
Create the deterministic build environment and commands for the approved relay language across Linux and macOS x86_64 and arm64, with pinned compilers, linkers, dependencies, target settings, and offline-ready inputs.

## Scope
In scope: consume the relay binding decision; exact compiler and linker versions; dependency lockfiles and source hashes; four target triples; minimum runtime assumptions; static versus dynamic linkage policy; build flags; source-date and locale controls; container or runner images where applicable; cache isolation; clean and incremental commands; dependency license extraction. Out of scope: protocol implementation, executable CLI behavior, producing final app archives, remote installation, Apple app code signing, notarization, and organization-wide CI migration.

## Acceptance Criteria
1. One documented command per target builds from pinned source and toolchain inputs without resolving floating branches, latest tags, or undeclared network dependencies. 2. Toolchain manifests name exact compiler, linker, SDK or sysroot, target triple, minimum OS or libc assumptions, dependency revisions, hashes, and license identifiers. 3. Clean builds run in isolated paths with deterministic locale, time, path, and cache inputs and cannot silently use workstation-global libraries or credentials. 4. The produced linkage and runtime contract is compatible with unprivileged user execution on the declared Linux and macOS baseline fixtures. 5. CI verifies pins, missing-input failure, offline dependency availability after approved fetch, and a representative clean build for all four targets.
