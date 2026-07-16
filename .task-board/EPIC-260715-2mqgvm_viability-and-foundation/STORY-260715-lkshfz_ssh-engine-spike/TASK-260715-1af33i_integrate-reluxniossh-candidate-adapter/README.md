# Integrate the ReluxNIOSSH candidate adapter

## Description
Implement the candidate adapter behind the common SSH transport contract and build it through the generated native and Swift dependency seams in the macOS harness and both Apple provider configurations.

## Scope
In scope: pinned fork dependency; client bootstrap; raw host-key callback; approved public-key authentication; direct-tcpip; bidirectional exec; bounded async reads and writes; per-channel windows; automatic and explicit rekey; keepalive; cancellation; metrics; error mapping; harness registration; iOS and macOS compile and smoke paths. Out of scope: selecting NIOSSH, production lane scheduler, relay protocol, SFTP, password prompts, ProxyJump, agent forwarding, and candidate-specific types outside the adapter module.

## Acceptance Criteria
1. The adapter satisfies every compile-time conformance requirement and exposes no ReluxNIOSSH type across the shared transport boundary. 2. Host-key material reaches policy before authentication acceptance and first-use, match, rejection, and change smoke paths are observable. 3. Direct-tcpip and exec channels support bounded writes, reads, EOF, half-close, cancellation, and independent close with configurable receive windows. 4. Byte and time rekey thresholds, server requests, keepalive, connection and channel metrics, and privacy-safe errors are wired to the common schema. 5. The adapter builds and smoke-connects in macOS harness, macOS provider, iOS simulator, and Gate P0 iPhone configurations with pinned dependency evidence.
