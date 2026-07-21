# TASK-260715-sdnk2k accepted inputs

Implement the reusable candidate-neutral bounded full-duplex byte pump defined by accepted `TASK-260715-1juybj`, without implementing SOCKS parsing, channel open, terminal policy, or choosing an SSH engine.

Authoritative inputs:

- The task description, scope, AC, and checklist are normative.
- Accepted `TASK-260715-1juybj_contract.md`, especially sections 6-8, its corrected state/ownership diagrams, validation, and final accepted reviewer verdict.
- `Sources/ReluxTunnelCore/SSHContracts.swift` public `SSHByteChannel` semantics are the remote byte seam. Preserve candidate neutrality and do not import or name ReluxNIOSSH/libssh2 in Core.
- Accepted runtime/core ownership from `TASK-260715-30zng6` and `TASK-260715-3tlgwm`: structured generation ownership, cooperative cancellation, no detached/unbounded work, deterministic resource return.
- `.spec/security-privacy.md` and `Sources/ReluxTunnelCore/RuntimeDiagnostics.swift` govern aggregate-only metrics and prohibited data.

Implementation constraints:

- Add the minimum injectable local nonblocking byte-stream/readiness seam needed for deterministic Core tests. Keep Darwin/platform translation outside Core and do not couple this task to NetworkExtension, HEV internals, production composition, or a selected SSH engine.
- Exactly one bounded buffer plus offset per direction. Do not read the next chunk until the current chunk is fully accepted by the destination. No array of chunks, spill storage, unbounded `AsyncStream`, retry queue, or detached callback mailbox.
- Every numeric limit is caller-injected and validated: local/remote chunk sizes, maximum SSH write-call size via accepted policy/seam, aggregate reserved bytes, fairness work/byte budget, readiness/no-progress bound or deadline input. Do not promote M0 candidate values to final policy.
- Local→SSH: partial positive `writeSome` advances once; zero for nonempty input is a typed contract violation; suspended credit awaits through the injected/channel seam without busy spin. SSH→local: partial positive writes advance once; would-block awaits writable readiness; zero for nonempty input is treated as peer closure. Preserve exact order and ownership.
- Emit typed directional outcomes/events for EOF, cancellation, local/remote closure, read/write error, zero progress, and bound violation so the later `1n9v9o` lifecycle task owns half-close/reset/terminal policy. This task must not guess final flow-close semantics.
- Cancellation must wake permanently stalled reads/writes/readiness waits, join both structured pumps, and release buffers/counters once. Old/late completions cannot resume work or double-release.
- Fairness must be observable and deterministic with an injectable yield/scheduler seam or equivalent bounded work slicing. Tests must prove no busy spin and that another flow/lifecycle task makes progress under continuous input.
- Diagnostics contain only direction, aggregate byte/operation/yield/pressure/error counters, stable reason codes, and bounded gauges. Never retain or label destination/originator, hostname/IP/port, payload bytes/hashes, credentials, or per-flow traffic identity in production diagnostics.

Required verification:

- Deterministic randomized bidirectional integrity tests across fragmented reads, partial writes, alternating pressure, EOF, zero progress, cancellation at every await, late completion, and repeated cleanup/resource baselines.
- Explicit memory-accounting assertions proving the fixed per-direction and aggregate ceiling independent of peer-advertised lengths and concurrency.
- Focused normal and TSan runs, repeated seeded runs, full Core validation/build, strict formatting, `git diff --check`, and board validation.
- Attach task-scoped results/evidence and route producer output to `to-review`; do not self-accept.
