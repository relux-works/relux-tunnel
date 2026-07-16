# Generate a machine-readable relay dependency SBOM

## Description
Produce and validate a release SBOM for relux-relay and every compiled or bundled dependency, with source, version, checksum, license, supplier, relationship, and target coverage.

## Scope
In scope: SPDX or CycloneDX format selected by contract, relay source, generated protocol code, static and dynamic libraries, compiler runtime where distributable, transitive packages, source revisions, package URLs or CPEs where known, file hashes, licenses, target variants, relationships, build metadata, schema validation, and deterministic output. Out of scope: claiming complete Apple application SBOM coverage outside the relay boundary, legal conclusions, vulnerability remediation, and hand-authored components that cannot be traced to build inputs.

## Acceptance Criteria
1. The SBOM validates against the approved schema and identifies every shipped relay component and dependency with revision or version, source, checksum, license expression, supplier or unknown marker, and dependency relationship. 2. Components are reconciled against lockfiles, link maps or binary inspection, and the build input inventory; missing and unexpected components fail. 3. Target-specific differences are represented without duplicating identities ambiguously and every one of the four assets maps to an SBOM scope. 4. Identical approved inputs produce deterministic SBOM content apart from explicitly normalized generation metadata. 5. Fixtures for missing transitive dependencies, unknown license, wrong hash, duplicate component, malformed relationship, and stale source revision fail validation.
