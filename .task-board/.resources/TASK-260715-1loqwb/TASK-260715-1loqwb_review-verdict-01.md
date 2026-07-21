# TASK-260715-1loqwb review verdict 01

## Verdict

Changes requested. Route to `to-dev`. The framing, admission, byte preservation, bounded queues, lifecycle cleanup, privacy, and existing tests are otherwise sound, but relay UDP error disposition is not compatible with the accepted v1 contract.

## Blocking finding: relay UDP error code is discarded

`HEVUDPDatagramAdapter.receiveRelayError` at `Sources/ReluxTunnelNativeAdapter/HEVUDPDatagramAdapter.swift:293` accepts only association ID and generation. It discards the `RelayRemoteAssociationError` produced by `RelaySession`. Every received UDP error therefore calls `ClientUDPAssociationRegistry.receiveRemoteError`, which transitions the active association to closing, closes the HEV TCP channel, and emits `CLOSE_ASSOCIATION`.

This is wrong for at least two accepted nonterminal cases. `QUEUE_SATURATED` 0x0006 is an edge-triggered drop signal and the association must survive. `DATAGRAM_TOO_LARGE` 0x0005 is also nonterminal when emitted for a lowered relay-local payload cap; a terminal protocol-oversize case is followed by `CLOSE_ASSOCIATION`, which can drive retirement separately. The relay session proves the distinction: `reportQueueSaturation` emits only UDP_ERROR, and lower-local-cap datagram rejection emits UDP_ERROR without a close. With the current adapter, either legal signal becomes an HEV-visible EOF and destroys the registry handle, violating AC3 and AC4 backpressure outcomes.

The existing lifecycle test at `Tests/ReluxTunnelNativeAdapterTests/HEVUDPDatagramAdapterTests.swift:267` injects an untyped generic error and expects closure. The backpressure test exercises only local `HEVUDPRelaySink.queueSaturated`, not a received relay UDP_ERROR, so this regression is uncovered.

## Required rework

1. Carry the typed `RelayRemoteAssociationError` or generated UDP error code into the adapter callback.
2. Keep the association active for received `queueSaturated` and nonterminal `datagramTooLarge`; count the drop without HEV close or relay close. Preserve association-local terminal handling for the remaining finite and unknown errors, with a following close remaining idempotent.
3. Add deterministic fake-relay tests proving 0x0006 and nonterminal 0x0005 preserve the same association ID and allow subsequent bidirectional datagrams, while terminal error plus close still cleans exactly once.
4. Re-run focused repeats, TSan, full Swift tests, protocol check, format, privacy scans, build, and board validation.

## Independent verification

- Pinned unmodified HEV source and real-HEV integration confirm command 0x05 and exact `MSGLEN | HDRLEN | ATYP | address | port | data` framing under `socks5.udp = tcp`.
- External no-auth ingress remains rejected before the adapter seam; accepted descriptors carry `SO_NOSIGPIPE`. No public destination logging or adapter-created listener/socket was found.
- Focused adapter suite passed 5 of 5 runs, 9 tests each.
- Focused ThreadSanitizer passed 9 tests with no report.
- Full Swift suite passed 328 tests in 29 suites.
- `make relay-protocol-check`, strict swift-format, `git diff --check`, `make check-core-boundaries`, privacy/proxy scans, Swift build, and `task-board validate` passed.
