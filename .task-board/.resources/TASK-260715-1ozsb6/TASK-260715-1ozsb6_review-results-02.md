# TASK-260715-1ozsb6 reviewer result — round 2

Verdict: CHANGES REQUESTED. Route to `to-dev`.

The rework fixed the previously reported duplicate socket-write test, signer join, upload bound/deadline wiring, phase preservation, keepalive miss-budget reference, and metric fields. Packaging and all claimed build gates reproduce green. AC 2, AC 3, and AC 5 still fail.

## Blocking findings

1. Concurrent channel opens still interleave one libssh2 nonblocking state machine. `beginChannelOpen` only increments `pendingChannelOpens`; it does not serialize callers (`LibSSH2Transport.swift:282-294`, `345-357`, `867-927`). Both direct and exec opens may therefore enter `libssh2_channel_open_ex` while another open is suspended on EAGAIN. At the pinned libssh2 source, all opens share `session->open_state`, `session->open_channel`, `session->open_packet`, and `session->open_data` (`src/libssh2_priv.h:881`; `src/channel.c:129-319`). A second call resumes the first call's state with the second call's message arguments, so concurrent opens can be mis-associated or corrupted. This violates AC 2 and the mandatory concurrent-channel behavior in AC 3.

2. Timeout/cancellation still does not return all tasks and bridge state safely to baseline. `LibSSH2TimeoutRace.resolve` cancels losing tasks but never joins them (`LibSSH2Transport.swift:1656-1700`). A timed-out `network.service` may therefore remain suspended in an injected non-cooperative `waitForReadiness`, `writeSome`, or `readSome`. Teardown concurrently calls `context.network.discard()` (`LibSSH2Transport.swift:1445`) without draining `serviceTail`; if a late write completes afterward, `serviceExclusively` removes its reported byte count from the now-cleared outbound buffer (`LibSSH2Bridge.swift:121-127`, `158-164`), which can trap. The task is also still counted by `pendingServiceCount`. Existing lifecycle tests time out or cancel only in resolution, before bridge service starts, so they do not exercise this path. This violates deterministic teardown in AC 2 and the resource-baseline requirement in AC 5.

3. Mandatory positive adapter conformance remains unevidenced. The adapter suite has 11 tests, but none completes a successful Swift-adapter connection or proves host-before-auth ordering, external-signing auth, direct-tcpip, exec/upload, client rekey, server-rekey traffic survival, keepalive failure policy, concurrent open/cancel, or post-connect resource return. The lifecycle tests cover failed EOF handshakes, resolution timeout, and resolution cancellation only (`LibSSH2BridgeTests.swift:130-229`). The C rekey harness validates the pinned fork while bypassing `LibSSH2Transport`. AC 3 requires every M0-mandatory row to pass or remain explicitly red with reproducible evidence, and AC 5 explicitly requires repeated connect/cancel smoke runs; deferring this adapter evidence to downstream tasks does not satisfy this task's acceptance criteria.

## Required rework

- Add an adapter-owned nonblocking operation scheduler that serializes libssh2 session state machines, especially channel opens and reply-requiring global requests, while retaining bounded concurrent channel semantics.
- Make bridge service cancellation drain-safe: teardown must prevent late service completions from touching discarded buffers and must join/retire every owned service operation before reporting baseline.
- Add successful adapter-level fixtures and concurrency/lifecycle regressions covering the M0 rows and repeated successful connect/cancel/close cycles. If any mandatory row cannot be exercised or supported, record that row red with reproducible task-scoped evidence rather than claiming it green.

## Reviewer validation

- `swift-format lint --recursive --strict Package.swift Sources Tests`: exit 0.
- `git diff --check`: exit 0.
- `swift test --filter LibSSH2BridgeTests`: exit 0; 11 tests passed.
- `make validate-core`: exit 0; 349 tests in 30 suites passed and `swift build` passed.
- `make validate-libssh2`: exit 0.
- `make test-libssh2-source-gates`: exit 0.
- `make native-apple-matrix`: exit 0; dual-architecture macOS provider/harness and release linkage checks passed.
- `task-board validate`: exit 0 with the existing `PARENT_STATUS_MISMATCH` for `STORY-260715-lkshfz` while this child is under review.

Logs are under `.temp/TASK-260715-1ozsb6/` with `review-01`/`review-02` task-scoped names.
