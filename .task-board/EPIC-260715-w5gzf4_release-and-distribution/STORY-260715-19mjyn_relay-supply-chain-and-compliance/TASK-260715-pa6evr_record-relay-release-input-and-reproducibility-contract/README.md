# Record the relay release input and reproducibility contract

## Description
Define the authoritative source, dependency, toolchain, target, naming, normalization, reproducibility, manifest, SBOM, notice, scan, provenance, and exception rules for release relay assets.

## Scope
In scope: approved source revisions, submodules or vendored inputs, lockfiles, compiler and linker versions, container or runner images, Linux and macOS x86_64 and arm64 targets, environment normalization, timestamps, paths, locale, archive order, build identity, output names, bit-for-bit pass condition, manifest schema, SBOM format, license policy, vulnerability thresholds, provenance predicate, and exception approval. Out of scope: implementing builds, changing relay protocol behavior, Apple signing, remote installation, and silently classifying unexplained differences as acceptable.

## Acceptance Criteria
1. A TASK-ID-scoped contract identifies every mutable build input and the exact pin or immutable digest that controls it. 2. The four target triples, binary names, executable boundary, platform normalization, build identity, protocol compatibility, and release directory layout are unambiguous. 3. Two isolated unsigned builds must be bit-for-bit identical after only explicitly defined deterministic normalization; every allowed normalization has rationale and a test. 4. Manifest, SBOM, notice, scan, provenance, staging, retention, and exception schemas identify owners and downstream consumers. 5. Security, release, relay, and legal or compliance owners approve the contract or unresolved policy choices remain blocking tasks with concrete options.
