# Record iOS source-to-archive provenance and reproducibility evidence

## Description
Demonstrate reproducibility of pinned source, dependencies, generated project, unsigned resources and payload inputs, then bind signed archive and exported output to those inputs and Apple distribution metadata.

## Scope
In scope: source and dirty-state assertion, dependency locks, generator and project output, Xcode and SDK, build settings, version inputs, relay staging digests, resource inventories, unsigned object or payload comparison where stable, signed archive and IPA hashes, certificate and profile public metadata, signing timestamps, App Store Connect build ID, provenance attestation, known signed nondeterminism, and independent verification. Out of scope: claiming byte-identical signed IPAs, storing private keys or issuer credentials, accepting unexplained unsigned differences, and rebuilding after TestFlight.

## Acceptance Criteria
1. Two clean preparations reproduce the approved generated project, dependency graph, relay and resource inputs, version metadata, and every unsigned payload component designated by the contract. 2. Any Apple signing, profile, timestamp, archive-container, or export nondeterminism is identified explicitly and cannot conceal a source, dependency, resource, version, or binary-code difference. 3. Provenance binds source commit, locks, toolchains, build invocation, unsigned input digests, signed archive and export digests, public signing identity, profiles, versions, and App Store Connect build ID. 4. An independent verifier can start from retained inputs and reports and prove the TestFlight or App Review candidate came from the approved candidate without post-validation rebuild. 5. Dirty source, generator drift, dependency drift, relay mismatch, unsigned payload difference, unknown signed difference, wrong profile, or wrong App Store build ID blocks promotion.
