# Flight Logbook

> Institutional memory. Concise, factual, high-signal.
> Newest entries first. One block per insight.

## 2026-07-20

### 0425 — PacketFlow adapter read lifecycle accepted (TASK-260720-9xy8yx)
- MILESTONE: Read-lifecycle hardening reviewed and accepted; both read-lifecycle defects from the 0407 entry (non-cancellable continuation, silent `zip` truncation) are closed and TASK-260715-3o0co4 (PacketFlowBridge) is unblocked.
- VERIFICATION: Reviewer independently reran swift build, swift test (26/26), swift format lint --strict, and a TSan pass of PacketFlowAdapterTests (14/14); prohibition greps clean. Evidence: .task-board/.resources/TASK-260720-9xy8yx/TASK-260720-9xy8yx_review.md.
- NOTE for TASK-260715-3o0co4: `PacketFlowAdapterBoundary.writePackets` has no post-shutdown gate (bridge pump must stop writing by construction), and after a cancelled committed read new reads return `readAlreadyPending` until the late NE callback retires the tombstone — expected during shutdown, not an error.

### 0420 — PacketFlow read gate retains late-callback tombstones (TASK-260720-9xy8yx)
- DECISION: iOS and macOS adapters share one locked `PacketFlowAdapterBoundary`; callback, task cancellation, and terminal adapter shutdown race for one continuation, while the callback registration remains a payload-free tombstone until NetworkExtension invokes it because `NEPacketTunnelFlow` exposes no deregistration API.
- DECISION: `PacketReadBatch` preserves callback order with typed valid/malformed results; cardinality mismatch rejects the whole batch as `PacketFlowError.packetProtocolCardinalityMismatch` instead of truncating it.
- FINDING: The callback slot must remain occupied through synchronous batch inspection, not merely until callback entry, or a concurrent caller can register the next read before the current batch has been fully validated.
- VERIFICATION: Swift Testing exercises both platform adapters, including 100 callback/cancellation and 100 callback/shutdown races per platform; normal and Thread Sanitizer test runs restore outstanding callback registrations to zero.

### 0407 — PacketFlowBridge contract accepted (TASK-260715-p89bdj)
- MILESTONE: Bridge concurrency/observability contract reviewed and accepted; unblocks TASK-260720-9xy8yx and TASK-260715-3o0co4 on the packet-plane critical path.
- DECISION: Endpoint B is an exclusive scoped borrow to HEV, never an ownership transfer; bridge closes B only after HEV blocking main returns (matches TASK-260715-uopycx pinned audit).
- DECISION: ENOBUFS/EAGAIN = counted packet drop, no retry, no side buffer; EMSGSIZE/EOF/persistent errno = fatal run failure. EWOULDBLOCK==EAGAIN (35) on Darwin, so one normalized wouldBlock counter per operation.
- FINDING: Both accepted adapters have real read-lifecycle defects — non-cancellable `withCheckedContinuation` and silent `zip` truncation at Sources/ReluxTunnelMacOSAdapter/MacOSProviderCompositionRoot.swift:19 and Sources/ReluxTunnelIOSAdapter/IOSProviderCompositionRoot.swift:21; gap-closure task TASK-260720-9xy8yx correctly blocks the bridge implementation.
- NOTE: Contract artifacts (design, lifecycle-state.puml, ownership-sequence.puml, validation log) live in .task-board/.resources/TASK-260715-p89bdj/. PlantUML renderer unavailable; .puml sources are authoritative.
