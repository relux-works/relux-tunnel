# Add relay license, provenance, and supply-chain metadata

## Description
Generate auditable metadata for relay source and transitive dependencies, including revisions, source hashes, licenses, required notices, build inputs, provenance, and the explicit handoff from M2 bundled-asset integrity to later distribution gates.

## Scope
In scope: relay repository revision; dependency lock and source hashes; compiler and base-image identifiers; license classification and notice text; machine-readable dependency inventory or scoped SBOM; build command and target; manifest linkage; vulnerability-review input; provenance record; policy that runtime never fetches code; M5 signing, notarization, attestation, and release boundary. Out of scope: changing licenses, legal advice, final product-wide SBOM, Apple archive signing, notarization, publishing assets independently, vulnerability remediation unrelated to selected dependencies, and remote host installation.

## Acceptance Criteria
1. Every source and build dependency affecting relay bytes maps to a pinned revision or content hash, license identifier, notice obligation, and provenance entry. 2. Required relay and transitive notices are generated into the product notice input and an automated test fails when a dependency lacks approved metadata. 3. The artifact manifest references the matching source and build provenance without embedding credentials, workstation paths, private repository tokens, or mutable latest URLs. 4. A supply-chain boundary table assigns M2 source pinning, build reproducibility, asset hashes, and notices while assigning app signing, notarization, release attestation, and distribution approval to concrete M5 scope. 5. A clean audit command verifies locks, hashes, notice coverage, inventory consistency, and zero application-runtime code download.
