# Execute the relay release-asset conformance and smoke matrix

## Description
Validate the exact reproducible relay bytes across all target environments using protocol, hostile-input, stdio-boundary, resource, identity, self-hash, startup, and clean-exit checks.

## Scope
In scope: Linux x86_64 and arm64, macOS x86_64 and arm64, native execution where available and approved emulation otherwise, canonical vectors, incremental and coalesced frames, malformed and oversized input, unknown types and flags, association and queue boundaries, handshake and build identity, self-hash, no public listener, rootless paths, signal and EOF handling, repeated start and stop, and metrics. Out of scope: remote SSH installation, destination traffic acceptance, Apple app lifecycle, production hosts, and performance optimization beyond release ceilings.

## Acceptance Criteria
1. Each exact asset hash passes the same versioned conformance corpus and reports the expected protocol, feature, build identity, and self-hash. 2. Stdio input and output remain framed, stderr is bounded and diagnostic only, no public listener or daemon survives, and execution requires no root or writable system location. 3. Malformed, oversized, split, coalesced, unknown, queue-pressure, signal, EOF, and cancellation cases remain bounded and return resources to baseline. 4. Target evidence records native or emulated status, OS, architecture, runner, duration, peak resources, exit codes, corpus revision, and asset digest. 5. Any target gap, emulator-only exception without approval, identity mismatch, protocol failure, leak, hang, public listener, or nonzero clean-exit result blocks staging.
