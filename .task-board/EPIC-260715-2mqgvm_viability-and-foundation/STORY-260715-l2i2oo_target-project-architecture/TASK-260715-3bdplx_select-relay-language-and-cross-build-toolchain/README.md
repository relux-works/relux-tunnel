# Select the relay language and cross-build toolchain

## Description
Close the unresolved implementation gap for the portable relux-relay target by selecting a language, build system, and reproducible cross-build strategy compatible with rootless Linux and macOS hosts on x86_64 and arm64.

## Scope
In scope: candidate language and runtime footprint; UDP and stdio support; bounded memory; static or self-contained distribution; Linux and macOS x86_64 and arm64 builds; testability; SBOM and license output; reproducibility; team maintenance; protocol-fuzz support; upgrade policy. Out of scope: implementing the relay protocol, remote installation, Apple provider bundling, SSH exec integration, and product behavior.

## Acceptance Criteria
1. A TASK-ID-scoped comparison evaluates at least the viable Swift, Go, and Rust or C-family options against the stated portability, binary, memory, build, testing, security, and maintenance criteria. 2. The selected language, compiler and toolchain versions, dependency policy, target triples, output names, and checksum or manifest format are explicit. 3. A minimal hello-stdio and UDP capability proof or equivalent primary evidence validates every required OS and architecture claim. 4. Tradeoffs and rejected options are recorded, including whether static linking is feasible and what runtime dependencies remain. 5. The decision provides enough detail for the dependent target-shell task to begin without a language or tooling question.
