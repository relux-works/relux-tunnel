# TASK-260715-1juybj accepted inputs

Record the production contract between the accepted private HEV SOCKS boundary and the candidate-neutral SSH `direct-tcpip` seam. This task is architecture/specification only; do not implement the adapter or select an SSH engine.

Authoritative inputs:

- The task description, scope, AC, and checklist are normative.
- Accepted `TASK-260715-30zng6` M1 runtime ownership/sequencing contract and its review define lifecycle ownership, cancellation, route truthfulness, and future seams.
- Accepted packet-plane outcomes `TASK-260715-uopycx`, `TASK-260715-1vv52g`, `TASK-260715-35wctc`, and their reviews establish the pinned HEV capability and the real internal boundary behavior.
- `Sources/ReluxTunnelNativeAdapter/HEVSOCKSBoundary.swift` is current production evidence: IPv4 loopback-only listener, fresh per-run RFC 1929 credentials, bounded pending admission and authentication deadline, rejection before adapter handoff, and exclusive `HEVSOCKSChannel` ownership positioned at the first request byte.
- `Sources/ReluxTunnelCore/SSHContracts.swift` and accepted `TASK-260715-100wu6` define the engine-neutral `SSHTransport.openDirectTCPIP`, `SSHChannelPolicy`, and `SSHByteChannel` byte/EOF/cancellation surface. Consume that public seam; do not reopen the pending human decision about exact SSH-engine observability or engine selection.
- `.spec/security-privacy.md`, `.spec/packet-plane.md`, `.spec/architecture.md`, and `.spec/routing-dns-lifecycle.md` are normative for privacy, fail-closed behavior, HEV UDP-in-TCP separation, and remote-resolution semantics.

Contract constraints:

- The endpoint is private infrastructure, never a user-configurable or general SOCKS proxy. Prove both iOS and macOS admission from accepted implementation/tests; do not claim process identity from TCP loopback. The security capability is the fresh per-generation credential plus listener lifecycle/ownership.
- Specify SOCKS5 method negotiation and CONNECT byte states for IPv4, IPv6, and domain destinations, including strict bounds, deadlines, unsupported-command/address handling, exact reply mapping, trailing-byte handling, and remote DNS semantics. UDP ASSOCIATE remains out of scope.
- One accepted CONNECT maps to exactly one `direct-tcpip` channel for its lifetime. Destination is preserved; originator is sanitized and must not expose local user/network identity. No flow migration or lane scheduler is implemented; retain only an injectable future lane-selection seam.
- Make all queues, parser buffers, reads, writes, concurrent-flow admission, and deadlines caller-injected or derived from already accepted measured baselines. Do not promote candidate MTU/window/session/buffer values to final product policy. Show the accounting relationship to the accepted HEV M0 baseline and bounded Core diagnostics.
- Define byte ownership and bidirectional backpressure without an unbounded side queue: partial reads/writes, zero-progress defense, local/remote EOF, half-close, reset, open rejection, cancellation, deadline expiry, partial-start rollback, and once-only cleanup.
- Metrics/logs are aggregate and schema-stable. Never record credentials, SOCKS bytes, hostnames, destination/originator addresses, payloads, or per-flow identifiers that reveal traffic. Errors may expose stable domains/codes/phases only.
- Trace each contract clause to an authoritative source or mark it explicitly as an M1 contract decision. Add task-scoped diagrams only when they materially clarify ownership/lifecycle. Validate board/resources and route producer output to `to-review`; do not self-accept.

Expected evidence:

- Byte-level protocol/state/ownership/resource contract satisfying all five AC.
- Source-backed proof of current admission behavior on both platform builds/tests.
- Explicit residual-decision table distinguishing implementable M1 inputs from M3 physical tuning and the separate SSH-engine human decision.
- Relevant validation/hashes and a concise logbook entry for load-bearing decisions or anomalies.
