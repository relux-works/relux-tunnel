# TASK-260715-1loqwb review verdict 02

## Verdict

Changes requested. Route to to-dev. Typed relay UDP errors now reach the adapter, both required nonterminal codes preserve the same association ID and HEV channel, and terminal cleanup remains idempotent. One lifecycle mutation remains incompatible with the fresh review contract.

## Blocking finding: nonterminal error observation refreshes idle activity

HEVUDPDatagramAdapter.observeNonterminalRelayError at Sources/ReluxTunnelNativeAdapter/HEVUDPDatagramAdapter.swift:582 validates an active association by calling ClientUDPAssociationRegistry.resolveRemoteDatagram at line 586.

That registry API is explicitly a datagram-activity operation. ClientUDPAssociationRegistry.swift:406 documents that it refreshes idle activity; lines 423-424 call refreshActivity and commit the record. refreshActivity at lines 629-633 cancels the existing timer, advances the deadline by the full idle timeout, schedules a replacement timer, and increments registry.metrics.activityUpdates.

Therefore a received queueSaturated or datagramTooLarge error with no datagram traffic prolongs association lifetime and changes timer state. Repeated legal error-only observations can indefinitely defer expiry. This violates reviewer-focus-02, which requires nonterminal error accounting to be a bounded aggregate observation only and not affect idle activity, queue credits, or hidden retry state. It also weakens AC3 expiry behavior.

The same-ID continuation regression at HEVUDPDatagramAdapterTests.swift:340 asserts active state, byte-exact later traffic, aggregate error metrics, peer close, and resource baseline, but it never asserts the original idle deadline/timer epoch or unchanged registry activityUpdates. The green suite therefore does not detect this defect.

## Required rework

1. Add or use a registry lookup dedicated to nonterminal control observation that validates current generation, active association, exact handle/key, and stale/unknown state without calling refreshActivity.
2. Keep queueSaturated and datagramTooLarge as aggregate-only metrics: no idle deadline/timer rearm, no activityUpdates change, no queue reservation, no retry state, no HEV/relay close, and no ID replacement.
3. Add a deterministic ManualUDPAdapterClock regression for each code. After admission, capture activity/timer state, advance near the original deadline, inject the error, prove the deadline was not extended and expiry occurs at the original deadline. Also retain the existing same-ID later bidirectional traffic and independent close/ack coverage.
4. Re-run the focused 5x, focused TSan, full Swift, protocol, format/diff, boundary/privacy, build, and board gates.

## Positive review evidence

- RelaySession maps the wire u16 to RelayRemoteAssociationError and emits the typed RelaySessionEvent.udpError; the adapter API accepts that exact type with no raw parallel interpretation.
- queueSaturated and datagramTooLarge alone do not close HEV, send CLOSE_ASSOCIATION, replace the ID, or reserve queue bytes.
- A later independent close retires both nonterminal cases exactly once.
- Other finite and unknown errors remain terminal, and error-first/close-first tests restore descriptor, registry, and queue baselines once.
- No wire schema, SSH pump, final resource policy, DNS behavior, destination logging, or public proxy surface was added.

## Independent verification

- Focused adapter suite: 5 consecutive passes, 11 tests each.
- Focused ThreadSanitizer: 11 tests passed, no report.
- Full Swift suite: 330 tests in 29 suites passed.
- make relay-protocol-check passed, including 89 vectors and 58 Swift protocol tests.
- Strict recursive swift-format, git diff --check, make check-core-boundaries, privacy/public-proxy scans, swift build, and task-board validate passed.
