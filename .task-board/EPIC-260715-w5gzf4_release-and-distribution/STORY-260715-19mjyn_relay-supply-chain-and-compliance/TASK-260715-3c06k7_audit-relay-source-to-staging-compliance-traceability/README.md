# Audit relay source-to-staging integrity and compliance traceability

## Description
Perform an independent release-readiness audit that traces every relay staging byte back to approved source and toolchains and reconciles manifests, SBOMs, notices, scans, tests, provenance, and the deterministic Apple-bundle input contract.

## Scope
In scope: independent digest recomputation, source and dependency material verification, toolchain identity, reproducibility pairs, staging contents, manifest selection rules, protocol identity, SBOM-to-binary reconciliation, notice completeness, scan disposition, attestation verification, exception expiry, Apple archive input expectations, and evidence index. Out of scope: inspecting downstream signed iOS or macOS archives, rebuilding product features, accepting legal risk without owner approval, Apple signature validation, and reviewing runtime tunnel behavior.

## Acceptance Criteria
1. The auditor starts from exact staged bytes and independently verifies hashes, identities, attestations, source and dependency materials, toolchains, and reproducibility evidence. 2. Every binary component maps to the SBOM and notice set and every manifest entry maps to exactly one staged asset with no extras. 3. Protocol and build identities agree across binary output, manifest, provenance, staging metadata, and the declared Apple bundle input contract. 4. All vulnerabilities, license findings, exceptions, and legal reviews are current, scoped, approved, and unexpired at staging time. 5. A TASK-ID-scoped verdict lists pass or fail by requirement, evidence digests, anomalies, residual risk, and exact blockers; downstream Apple archives must consume this accepted staging bundle by digest.
