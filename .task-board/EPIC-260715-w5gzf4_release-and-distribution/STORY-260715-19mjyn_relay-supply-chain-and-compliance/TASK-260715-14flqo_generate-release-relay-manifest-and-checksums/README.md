# Generate the release relay manifest and checksums

## Description
Generate the canonical manifest and checksum files that bind every reproducible relay asset to protocol, platform, architecture, byte size, hash, build identity, source, dependencies, and toolchain inputs.

## Scope
In scope: versioned schema, deterministic ordering and serialization, OS and architecture normalization, file names, byte sizes, SHA-256, protocol version, feature set where approved, build identity, source commit, dependency lock digest, toolchain digest, reproducibility run identifiers, and manifest self-digest. Out of scope: signing Apple bundles, runtime handshake implementation, remote install policy, SBOM generation, and accepting hand-edited manifest fields.

## Acceptance Criteria
1. Manifest generation discovers the declared release directory and emits exactly one deterministic entry for each required target with every contract field. 2. Values are derived from binaries and pinned metadata rather than duplicated manual input and build identity or self-hash discrepancies fail. 3. Missing, extra, duplicate, ambiguous, renamed, wrong-platform, wrong-architecture, zero-size, oversize, or hash-mismatched assets are rejected. 4. Repeated generation over identical bytes produces identical manifest and checksum files with a recorded schema version and self-digest. 5. Golden, tamper, schema-version, ordering, path-traversal, Unicode-name, and oversized-field tests verify bounded fail-closed parsing.
