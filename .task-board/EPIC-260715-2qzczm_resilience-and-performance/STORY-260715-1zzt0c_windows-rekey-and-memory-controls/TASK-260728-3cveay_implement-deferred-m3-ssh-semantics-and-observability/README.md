# TASK-260728-3cveay: implement-deferred-m3-ssh-semantics-and-observability

## Description
Deliver the four SSH transport semantics deliberately deferred from the approved M0 viability scope, on the selected engine, with reproducible evidence. These are not optional: M0 shipped explicit not-reported states for them and this task converts those states into real, measured behavior inside the accepted memory ledger.

## Scope
In scope: consumer-driven receive-window credit with an immutable per-channel cap that is not auto-adjusted before consumer delivery; RFC 4254 channel-open rejection reason taxonomy preserved end to end; exact exec-exit metadata distinguishing status 0 from absent metadata and exposing exit-signal coreDumped; deep rekey and keepalive observability including server-initiated KEX lifecycle/generation and reply-correlated keepalive RTT, timeout, and miss metrics; the fork or upstream change needed on the selected engine plus its maintenance and rebase owner; conformance tests and harness evidence. Out of scope: re-opening the M0 engine selection, NIOSSH fork work while libssh2 remains primary, lane scheduling policy, and hardcoding numeric window or rekey values outside the accepted memory ledger.

## Acceptance Criteria
1. Each of the four deferred semantics is implemented or explicitly recorded red with pinned-source evidence; no semantic is silently dropped. 2. Receive-window credit is consumer-driven with an immutable cap proven by a test that stalls the consumer and observes no credit return. 3. Channel-open rejection reasons, exec exit status/notReported/coreDumped, and server-rekey generation plus keepalive RTT/timeout/miss are asserted against a real SSH host, not mocks. 4. Every added buffer, window, and metric fits the accepted TASK-260715-1pn983 memory ledger and the task reports measured footprint deltas. 5. Any engine fork records exact pinned revision, patch scope, security-monitoring, and rebase owner.
