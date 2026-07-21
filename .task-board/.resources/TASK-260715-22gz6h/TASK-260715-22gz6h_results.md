# TASK-260715-22gz6h implementation results

## Delivered

- Added the actor-isolated client UDP association registry with generation-scoped nonzero UInt32 IDs, bounded admission/allocation search, active/closing/expired/closed states, exactly-once HEV and relay cleanup, cancellation, and privacy-safe aggregate metrics.
- Retained closing and expired IDs until relay retirement proof or generation teardown; generation plus allocation tokens reject stale work after permitted numeric reuse.
- Fixed the reviewed idle timer ABA race with a monotonic per-record arm epoch. A callback must match the current association key and arm epoch before it can clear, replace, reschedule, or expire timer state. Stale callbacks are counted only as an aggregate metric.
- Kept the implementation in ReluxTunnelCore with no NetworkExtension, SSH engine, destination history, payload history, or new runtime dependency.

## Tests

- Expanded the Swift Testing suite from 10 to 12 tests. The deterministic barrier test wakes an old sleep, commits activity and replacement first, observes the stale callback, and proves the replacement remains the sole real sleeper.
- Added 100-rearm churn coverage and real fake-clock pending/outstanding sleep assertions: one sleep per active association and zero after local/remote close, remote error, expiry, session replacement/loss, cancellation, provider stop, and property cleanup.
- Existing concurrency, wraparound/collision exhaustion, duplicate/crossed close, expiry race, generation/ABA reuse, cancellation, and seeded property coverage remains passing.

## Verification

- Focused registry suite: 12 tests pass, repeated 5/5.
- swift test: 318 tests in 28 suites pass on rerun.
- swift format lint --recursive Sources Tests Package.swift: pass.
- git diff --check: pass.
- make relay-protocol-check: pass, including 89 canonical vectors, Go protocol tests, 57 Swift relay tests, 12 negative fixtures, deterministic generation/drift checks, digest checks, and Swift build.
- Final swift build: pass.
- Task-scoped privacy scan: pass.

The first full Swift run observed one unrelated ProviderAdapterContractTests race-test issue. That suite passed immediately in isolation and the full 318-test rerun passed without unrelated changes. No commit, staging, or push was performed.