# Implement lane-pool lifecycle and same-host identity enforcement

## Description
Implement the bounded lane-pool owner that starts lane A first, opens general and optional bulk lanes only when admitted, verifies every lane against the same approved session identity, and closes all resources deterministically.

## Scope
In scope: construction from the selected SSH transport factory; lane A mandatory startup; B and C general and optional D bulk lifecycle; maximum two to four live or opening lanes; canonical profile, host-key, credential, and transport generation binding; server connection limit and memory admission hooks; idempotent start, close, cancellation, and stale callback handling; aggregate events and metrics. Out of scope: scheduler scoring, channel-window calculation, reconnect across physical paths, relay protocol implementation, credential UI, host-key replacement, or physical performance measurement.

## Acceptance Criteria
1. Start opens and verifies lane A before optional lanes and never exceeds the configured opening-plus-live lane ceiling. 2. Every accepted lane matches the canonical profile generation, approved host-key algorithm and fingerprint, and credential generation, while mismatch closes it before any channel opens and emits a finite privacy-safe reason. 3. Optional lanes honor server-capacity and memory-admission results and can be suppressed or retired without affecting lane A ownership. 4. Concurrent start, cancel, stop, duplicate completion, and late callback sequences run one cleanup path and return sessions, sockets, tasks, timers, and observers to baseline. 5. Unit and selected-engine integration tests cover one, two, and four lanes, partial startup, identity mismatch, optional rejection, cancellation, and repeated lifecycle.
