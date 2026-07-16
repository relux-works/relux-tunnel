# Add shared-core unit and protocol conformance CI

## Description
Run ReluxTunnelCore, protocol codec, golden-vector, malformed-input, lifecycle, and portable relay protocol suites on macOS with deterministic reporting and bounded test artifacts.

## Scope
In scope: Swift and relay protocol unit tests, golden vectors, incremental and coalesced reads, unknown types and flags, oversized lengths, cancellation, resource bounds, cross-language conformance, deterministic seeds, timeouts, test sharding only where reproducible, coverage or result bundles, and failure diagnostics. Out of scope: physical-device lifecycle, production SSH hosts, relay release publication, packet performance matrices, and hiding flaky failures through automatic retries.

## Acceptance Criteria
1. The workflow runs all approved shared-core and protocol suites from pinned dependencies on the declared macOS runner and fails when any suite or vector is omitted. 2. Test metadata records source and dependency revisions, platform, tool versions, deterministic seeds, durations, and suite inventory. 3. Malformed, oversized, split, coalesced, cancellation, and resource-bound fixtures execute with bounded time and memory and produce redacted diagnostics. 4. Results are published in a stable machine-readable format with a human-readable summary and failed cases are reproducible locally. 5. A controlled protocol incompatibility, missing golden vector, flaky retry dependency, timeout, or resource leak fails the required check.
