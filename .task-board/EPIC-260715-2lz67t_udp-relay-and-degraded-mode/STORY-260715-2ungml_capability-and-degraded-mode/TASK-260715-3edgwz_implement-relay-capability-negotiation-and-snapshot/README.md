# Implement relay capability negotiation and truthful runtime snapshots

## Description
Combine bootstrap results, protocol handshake, build identity, features, effective limits, relay health, and mandatory base-path readiness into one versioned generation-safe capability snapshot for the provider, containing app, diagnostics, and policy consumers.

## Scope
In scope: consume the state contract; protocol and build identity; normalized platform; bootstrap reason; feature bits; effective frame and resource limits; relay generation and health; TCP and safe-DNS readiness inputs; full, degraded, or failed projection; versioned provider-message model; snapshot sequencing; aggregate counters; privacy-safe encoding; stale and future-version behavior. Out of scope: performing bootstrap, implementing M1 base paths, transition orchestration, final UI rendering, persistence as source of truth, remote-controlled diagnostic text, and path reconnect.

## Acceptance Criteria
1. The provider publishes full only when current-generation mandatory base paths and validated relay evidence are all ready, degraded only when TCP and safe DNS are ready without UDP, and failed otherwise. 2. Snapshot schema versions capability bits, mode, finite reason, relay build identity, normalized platform, feature set, effective limits, health age, and aggregate counters with backward and future-version handling. 3. Bootstrap, handshake, health, association, and safe-DNS inputs are serialized by runtime generation and out-of-order or late events cannot regress or resurrect capability. 4. The containing app can distinguish system session state from provider capability and never infers UDP from connected or TCP from relay presence. 5. Unit and message compatibility tests cover every input combination, generation replacement, stale snapshot, oversized message, unknown reason, redaction, and deterministic no-secret serialization.
