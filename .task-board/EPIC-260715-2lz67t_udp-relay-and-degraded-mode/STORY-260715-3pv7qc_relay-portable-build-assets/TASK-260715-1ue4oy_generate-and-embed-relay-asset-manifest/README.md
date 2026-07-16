# Generate and embed the relay asset manifest

## Description
Create the deterministic bundle manifest and client lookup layer that binds each normalized remote platform tuple to one trusted asset with protocol version, file size, SHA-256, build identity, and bundle location.

## Scope
In scope: manifest schema and version; Linux and macOS x86_64 or arm64 normalization; stable ordering; asset file name; protocol version; exact byte size; lowercase SHA-256; build identity; build provenance reference; generator; application-bundle inclusion; typed read-only client lookup; duplicate, missing, extra, stale, and mismatched asset validation. Out of scope: remote uname parsing, upload, application signing, runtime manifest updates, network fetch, protocol handshake implementation, and final release attestation.

## Acceptance Criteria
1. A deterministic generator emits one schema-validated entry for each of the four assets and no unsupported or duplicate platform tuple. 2. Every recorded size and SHA-256 is computed from the exact bundled bytes and every build identity matches the executable response or handshake contract. 3. Bundle validation fails on missing, extra, renamed, duplicate, zero-length, hash-mismatched, protocol-mismatched, or unparseable assets before runtime selection. 4. The Apple client consumes a generated or validated typed lookup without caller-supplied file paths, mutable manifest data, or network access. 5. Tests cover all valid tuples, common uname normalization handoff values, schema version mismatch, tampering, deterministic regeneration, and generated-resource inclusion in both platform products.
