# Flight Logbook

> Institutional memory. Concise, factual, high-signal.
> Newest entries first. One block per insight.

## 2026-07-20

### 0539 — Relay toolchain decision accepted (TASK-260715-3bdplx)
- MILESTONE: Go 1.26.5 relay toolchain decision reviewed and accepted; unblocks TASK-260715-1ccx3l, 1g9cyt, 32umrc and the M2 relay build with no open language/tooling question.
- VERIFICATION: Reviewer independently confirmed both `.temp/TASK-260715-3bdplx/go1265-{a,b}` trees byte-identical with SHA-256 matching the decision table; Linux outputs are static stripped ELF with no dynamic section; Darwin outputs link only `libSystem`+`libresolv` with `minos 12.0`; embedded build info shows go1.26.5, CGO_ENABLED=0, correct GOOS/GOARCH/GOAMD64/GOARM64, trimpath. Reviewer reran the stdio+UDP proof: native arm64 PASS, Rosetta amd64 PASS.
- VERIFICATION: External claims fact-checked live — all four Go 1.26.5 archive SHA-256 match go.dev; Syft archive SHA-256 matches its checksums file and the binary reports v1.48.0 commit `3e2bc6e`; SPDX 2.3 SBOMs contain `stdlib@go1.26.5` with declared BSD-3-Clause. Evidence: .task-board/.resources/TASK-260715-3bdplx/TASK-260715-3bdplx_review.md.
- NOTE: Native Linux amd64/arm64 and Intel-Mac execution remain mandatory release stop-line gates, correctly recorded as release CI scope, not a cross-build blocker.

### 0533 — Relay toolchain selects cgo-free Go 1.26.5 (TASK-260715-3bdplx)
- DECISION: Implement `relux-relay` as a standard-library-only Go module pinned to official Go 1.26.5; build `linux/{amd64,arm64}` and `darwin/{amd64,arm64}` with `CGO_ENABLED=0`, exact output names, SPDX SBOMs, and a versioned JSON SHA-256 manifest.
- FINDING: cgo-free Linux outputs are fully static without musl or glibc; Darwin outputs necessarily retain `libSystem` and `libresolv`. The selected Go toolchain raises the remote macOS floor to 12.0; the project sets a conservative Linux 4.4 floor.
- VERIFICATION: A hello-stdio + UDP proof cross-built all four targets twice byte-identically with Go 1.26.5; macOS arm64 ran natively and amd64 under Rosetta 2. Native Linux and Intel-Mac release smoke remain mandatory stop-line CI gates because this host had no Linux runtime or Intel hardware. Evidence: `.research/260720_task-260715-3bdplx-relay-language-cross-build-toolchain.md`.
- ANOMALY: The initially installed Go 1.25.5 was behind security patch releases; the proof was repeated with current Go 1.26.5. Toolchain patch freshness is now an explicit 48-hour security-update policy.

### 0517 — PacketFlowBridge implementation accepted (TASK-260715-3o0co4)
- MILESTONE: Public socket-pair PacketFlowBridge reviewed and accepted; the p89bdj contract's ownership ordering, first-error-wins termination, exact 30-counter/12-gauge schema, bounded slices, and prohibitions are all verified in `Sources/ReluxTunnelCore/PacketFlowBridge.swift`.
- VERIFICATION: Reviewer independently reran swift build, swift test (39/39 in 5 suites), swift test --sanitize=thread --filter PacketFlowBridge (13/13, zero TSan reports), swift format lint --strict, make check-core-boundaries, and prohibition greps. Evidence: .task-board/.resources/TASK-260715-3o0co4/TASK-260715-3o0co4_review.md.
- NOTE for TASK-260715-3dn813: rows not yet exercised at bridge level — pre-send synthetic 4+MTU ceiling fatal, reverse truncation→fatal, readiness `peerClosed` and unexpected-HEV-return, cancellation at every startup barrier stage, drop-summary window suppression, saturation logging. `PacketFlowBridge.runEnded` also carries a cosmetic dead `reachedRunning` branch (both arms set `.failed`).

### 0510 — Public socket-pair PacketFlowBridge implemented (TASK-260715-3o0co4)
- DECISION: `PacketFlowBridge` stores one supervisor plus forward, reverse, and HEV-return child tasks; a first-event control owns fatal/stop selection and cleanup always shuts down reads, cancels readiness, joins both pumps, requests and joins the HEV borrow, then closes B before A exactly once.
- DECISION: Both descriptors preserve existing flags while adding `FD_CLOEXEC`/`O_NONBLOCK`; requested and effective endpoint-specific socket buffers, framing maxima, traffic, drops, lifecycle, and fatal reasons use the contract's run-scoped metric schema.
- FINDING: Darwin `recvmsg` reports copied bytes while `MSG_TRUNC` marks truncation; the public `SO_NREAD` option is explicitly the first-packet byte count, so the production receiver combines `SO_NREAD` with one consuming `recvmsg` to record the exact observed datagram size without allocating from it.
- VERIFICATION: Swift Testing covers byte-exact SDK-derived IPv4/IPv6 framing, zero/undersized/unknown/mismatched reverse frames, bounded count/time slices, queue-pressure loss, EMSGSIZE, PacketFlow rejection, first-error-wins, startup cancellation/failure, privacy-safe logging, and 100 restart cycles.

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
