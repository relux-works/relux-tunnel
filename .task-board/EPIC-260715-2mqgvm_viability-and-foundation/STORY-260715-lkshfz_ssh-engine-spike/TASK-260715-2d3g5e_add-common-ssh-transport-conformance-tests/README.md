# Add common SSH transport conformance tests

## Description
Implement one Swift Testing and harness suite that runs unchanged against both candidate adapters, asserts every M0-viability-mandatory requirement, and verifies explicit not-reported or unsupported states for the four M3-deferred semantics.

## Scope
In scope: Tier-1 M0-viability host-key ordering, approved auth, direct-tcpip, exec/stdin upload, bounded buffers and backpressure, client rekey, server-rekey handling, keepalive, cancellation, lifecycle, privacy-safe errors, available metrics, and deterministic resource baselines; explicit deferred-state assertions for consumer-driven receive credit, RFC open reasons, exact exec-exit metadata, and deep rekey/keepalive observability. Out of scope: treating M3 exact values as M0 selection gates, candidate-specific pass exceptions, production lane scheduling, full physical performance matrix, relay framing, UI, and sleep-only tests.

## Acceptance Criteria
1. The same named suite runs against both adapters with candidate selection as data, and every M0-viability-mandatory gate has an explicit assertion rather than an informal log check. 2. Host verification proves raw key evidence reaches policy before credential lookup/authentication and changed keys open no destination channel. 3. Direct/exec/upload tests verify independent open, bounded read/write/backpressure, EOF, half-close, reset, cancel, close, and server-rekey-safe active traffic. 4. Fake-clock and byte-count tests trigger mandatory client rekey; the four M3-deferred semantics assert explicit reported, not-reported, or unsupported states and map exact-value work to TASK-260728-3cveay. 5. Repeated cancellation restores tasks, channels, sockets, descriptors, and buffers to baseline; mandatory metrics reconcile and privacy sentinels are absent.
