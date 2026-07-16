# Enforce Apple bundle relay selection and integrity

## Description
Integrate the canonical relay manifest with generated Apple target resources so only declared assets are bundled and every copied byte is verified before archive signing.

## Scope
In scope: resource layout, target membership, platform and remote-host selection metadata, manifest copy, checksum verification before and after copy, protocol compatibility, duplicate and stale asset removal, deterministic build-phase inputs and outputs, archive inspection, extension-safe resource access, and failure diagnostics. Out of scope: runtime upload implementation, changing platform selection policy, code signing, notarization, TestFlight, and fetching relay binaries during application runtime.

## Acceptance Criteria
1. The generated project consumes only assets from the approved release staging directory and bundles the manifest and exact declared target set required by product policy. 2. A pre-sign build gate verifies names, sizes, SHA-256 values, protocol compatibility, and build identities against the canonical manifest, then re-verifies bytes in the archived application. 3. Stale, duplicated, undeclared, missing, renamed, or manually replaced assets fail before Apple signing credentials are used. 4. Bundle selection is deterministic across iOS and macOS configurations and no target downloads or modifies relay bytes at application runtime. 5. Automated archive fixtures cover correct bundles, platform mismatch, protocol skew, tampering before and after copy, incremental-build stale output, and generated-project drift.
