# Flight Logbook

> Institutional memory. Concise, factual, high-signal.
> Newest entries first. One block per insight.

## 2026-07-20

### 0407 — PacketFlowBridge contract accepted (TASK-260715-p89bdj)
- MILESTONE: Bridge concurrency/observability contract reviewed and accepted; unblocks TASK-260720-9xy8yx and TASK-260715-3o0co4 on the packet-plane critical path.
- DECISION: Endpoint B is an exclusive scoped borrow to HEV, never an ownership transfer; bridge closes B only after HEV blocking main returns (matches TASK-260715-uopycx pinned audit).
- DECISION: ENOBUFS/EAGAIN = counted packet drop, no retry, no side buffer; EMSGSIZE/EOF/persistent errno = fatal run failure. EWOULDBLOCK==EAGAIN (35) on Darwin, so one normalized wouldBlock counter per operation.
- FINDING: Both accepted adapters have real read-lifecycle defects — non-cancellable `withCheckedContinuation` and silent `zip` truncation at Sources/ReluxTunnelMacOSAdapter/MacOSProviderCompositionRoot.swift:19 and Sources/ReluxTunnelIOSAdapter/IOSProviderCompositionRoot.swift:21; gap-closure task TASK-260720-9xy8yx correctly blocks the bridge implementation.
- NOTE: Contract artifacts (design, lifecycle-state.puml, ownership-sequence.puml, validation log) live in .task-board/.resources/TASK-260715-p89bdj/. PlantUML renderer unavailable; .puml sources are authoritative.
