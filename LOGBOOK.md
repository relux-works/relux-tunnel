# Flight Logbook

> Institutional memory. Concise, factual, high-signal.
> Newest entries first. One block per insight.

## 2026-07-20

### 0748 — Review: reachable shutdown deadlock in HEV quit path (TASK-260715-1vv52g)
- FINDING: `HEVDescriptorBorrowHandle.requestStop()` (`Sources/ReluxTunnelNativeAdapter/HEVIntegration.swift:374`) calls `hev_socks5_tunnel_quit()` unconditionally. Pinned upstream `hev_socks5_tunnel_stop` (`src/hev-socks5-tunnel.c:695`) busy-waits forever for `event_fds[1] >= 0`; `event_task_fini` resets both fds to `-1` when main returns, and init-failure returns (-1…-5) never create them.
- ROOT CAUSE: Any ordering where HEV main returns before `requestStop()` — init failure, or the contract-modeled "unexpected HEV main return while active" — makes `supervisedCleanup` (`Sources/ReluxTunnelCore/PacketFlowBridge.swift:1017`) invoke quit after fini: infinite 100 ms `usleep` loop on a cooperative executor thread; provider `stop()` never returns, descriptors never close. Plain `stop()` racing a just-died HEV hits the same path.
- FINDING: Masked in tests because fake runtimes' `requestStop` never blocks and every lifecycle test stops HEV before its main returns.
- NOTE: A residual quit-vs-spontaneous-return race (write-after-close/assert inside HEV) is inherent upstream — its own `hev-jni.c` shares it — and is out of fixable scope without patching; the guard narrows the window to that inherent case.
- REWORK: `requestStop()` now skips upstream quit after the joined main call has returned while preserving listener shutdown and stop metrics. Tests cover both main-return-first and stop-first orderings and fail if quit lands after return.
- REWORK: The loopback listener fd is closed exactly once by its dispatch-source cancel handler on `listenerQueue`; `stop()` waits for cancellation before returning, eliminating the accept-loop fd-reuse window.
- VERIFICATION: Strict swift-format, 49 Swift tests, `swift build`, 8 HEV tests under ThreadSanitizer, and `make validate-native` all pass. The residual quit-vs-spontaneous-return race remains upstream-inherent and would require a forbidden HEV patch; the return guard narrows exposure to that concurrent window.

### 0702 — Unmodified HEV/lwIP bridge integration (TASK-260715-1vv52g)
- DECISION: The real `DescriptorBorrowConsumer` runs pinned HEV `ad760049` on exactly one dedicated pthread, calls the public quit API once, joins before return, and never closes or duplicates bridge endpoint B. A process-wide lease protects HEV's global C state.
- DECISION: HEV's upstream SOCKS connection is restricted to an IPv4-loopback listener with fresh per-run RFC 1929 credentials. Only an authenticated owned channel reaches the injected adapter; pending-authentication count and timeout are caller inputs, and an external no-auth ingress test is rejected before the seam.
- VERIFICATION: The emitted in-memory YAML records caller MTU, `udp: tcp`, task stack 24576, TCP buffer 4096, `udp-copy-buffer-nums: 2`, and max sessions 1200. The generator rejects any stack input the pinned parser would silently raise.
- VERIFICATION: The checksum-locked static XCFramework is a SwiftPM binary target for the shared native adapter and all provider/harness graphs. Generated and statically embedded HEV/core/task-system/lwIP notices are byte-identical and trace every manifest revision; the stripped harness audit requires HEV main/quit/stats symbols.
- ANOMALY: Darwin accepted sockets inherited nonblocking behavior during the split RFC 1929 exchange; explicitly restoring blocking mode fixed a deterministic transient-`EAGAIN` authentication rejection without retries or sleeps.

### 0634 — HEV low-memory baseline is not effective as recorded (TASK-260715-1vv52g)
- BLOCKER: Pinned unmodified HEV `ad760049` silently raises the requested `task-stack-size: 24576` to `35480`: `hev-config.c` computes `TASK_STACK_SIZE (20480) + max(tcp-buffer-size (4096), UDP_BUF_SIZE (1500) * udp-copy-buffer-nums (default 10))` for every UDP mode, including `socks5.udp: tcp`.
- VERIFICATION: A native probe linked directly against the checksum-verified rebuilt XCFramework reports `task-stack-size=35480`, `tcp-buffer-size=4096`, `udp-copy-buffer-nums=10`, and `max-session-count=1200`; evidence is `.temp/TASK-260715-1vv52g/hev-effective-config-probe-01.log`.
- DECISION NEEDED: Either approve an additional injectable `udp-copy-buffer-nums` baseline of `1` or `2` so the effective stack remains 24576, explicitly accept 35480 as the effective stack while retaining 24576 only as an input, or revise the no-patch constraint. Recommendation: approve `2` as an explicit M0 measurement input; do not patch HEV or claim that 24576 is effective while the parser overrides it.

### 0619 — Native packaging seam accepted (TASK-260715-1g9cyt)
- MILESTONE: ADR-019 static XCFramework `binaryTarget` seam reviewed and accepted; unblocks TASK-260715-sbrrp7, 1vv52g, 1af33i, 1ozsb6 with the HEV/lwIP and SSH candidate plug-in path documented in docs/native-dependency-packaging.md.
- VERIFICATION: Reviewer independently reran `make validate-native` (exit 0): boundary guard, fixture source/artifact-lock verify, byte-identical rebuild, negative gates (tampered source, missing arch, dylib substitution, absolute path, hash drift), full Xcode 26.5 Apple matrix with `APPLICATION_EXTENSION_API_ONLY=YES`, stripped SwiftPM release harness link audit, 41 tests in 6 suites. Strict swift-format lint, py_compile, sh -n, and manifest JSON checks also pass.
- VERIFICATION: Reviewer re-inspected the rebuilt `.temp/TASK-260715-1g9cyt/HevSocks5Tunnel.xcframework` — static and extension-safe; outcome log/notice SHA-256 match the values claimed in TASK-260715-1g9cyt_results.md; manifest HEV pins match the TASK-260715-uopycx audit exactly.
- NOTE: `check-core-boundaries` now pins adapters/harness-support to exactly {Core, NativeAdapter}; intentional tightening, keeps native-graph drift visible in review.

### 0610 — Static native packaging seam and HEV rebuild gate (TASK-260715-1g9cyt)
- DECISION: ADR-019 uses locally source-rebuilt static XCFramework SwiftPM `binaryTarget`s for custom-build C graphs behind named native adapter modules; source-reviewable ReluxNIOSSH stays a pinned source package. `ReluxTunnelCore` retains no native dependency.
- VERIFICATION: The harmless binary fixture rebuilds byte-identically for iOS arm64, iOS Simulator arm64/x86_64, and macOS arm64/x86_64. Negative gates reject source tampering, dylib substitution, missing architecture, and absolute build paths. Xcode 26.5 Release builds passed for the native consumer, both providers, and harness with `APPLICATION_EXTENSION_API_ONLY=YES`; 41 Swift tests pass.
- VERIFICATION: The new HEV command verified clean root `ad760049` plus core `c234519`, task-system `b1afa0e`, lwIP `2a11c14`, and yaml `efa3611` archive hashes before rebuilding the full Apple XCFramework. Static/module-map/slice/extension checks pass and notices are regenerated from those exact sources.
- ANOMALY: Xcode's generated Swift-package scheme instruments ordinary build actions for test coverage and embeds coverage source paths. The universal Xcode scheme remains the compile/link matrix; absolute-path/dylib inspection runs on the non-instrumented, release-stripped SwiftPM harness, matching the production harness packaging path.

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
