# TASK-260715-1loqwb implementation and rework results

## Delivered

The private authenticated HEV UDP-in-TCP adapter preserves IPv4, IPv6, opaque domain, port, payload, response-source, and association bytes through relay-v1 without resolution, normalization, destination history, public listener creation, or destination-bearing logging. Incremental split/coalesced parsing, bounded oversize skip, bounded per-association and aggregate queues, generation isolation, cancellation, and exactly-once lifecycle cleanup remain covered.

Typed RelayRemoteAssociationError reaches the adapter. queueSaturated and datagramTooLarge remain nonterminal aggregate observations; other finite and unknown errors remain terminal. Rework 02 adds ClientUDPAssociationRegistry.observeActiveAssociation, which validates current generation, association ID, allocation-bearing key, owner handle, and active state without refreshing activity or rearming the idle timer.

## Deterministic regressions

Both nonterminal codes preserve same-ID bidirectional traffic and accept a later independent close exactly once. ManualUDPAdapterClock cases capture activityUpdates, the exact pending deadline, timer-arm count, and scheduled timer after admission; advancing to one millisecond before expiry and injecting either error changes none of them, and expiry occurs at the original deadline with one cleanup and zero queue bytes. Registry tests cover active, stale-generation, unknown-ID, and closing-state no-refresh branches.

## Verification

Focused adapter suite: 12 tests, repeated 5/5. Focused ThreadSanitizer: 12 tests with no report. Registry suite: 13 tests. Full Swift suite: 332 tests in 29 suites. make relay-protocol-check passed with 89 vectors and 58 Swift protocol tests. Strict recursive Swift format, git diff check, core boundaries, privacy/public-proxy/admission scans, fresh Swift build, and task-board validate passed. No commit, staging, or push was performed.