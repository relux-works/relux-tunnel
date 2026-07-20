# TASK-260715-1vv52g review verdict: changes requested (to-dev)

## Verdict

One blocking correctness defect in the quit/join seam this task owns. Everything
else — all five ACs, pinned-source integrity, packaging, notices, tests, lint —
independently verified and solid.

## Blocking finding: reachable permanent shutdown deadlock

`HEVDescriptorBorrowHandle.requestStop()` (Sources/ReluxTunnelNativeAdapter/HEVIntegration.swift:374-384)
calls `runtime.requestStop()` -> `hev_socks5_tunnel_quit()` unconditionally.

Pinned upstream behavior (verified in the clean ad760049 checkout):

- `hev_socks5_tunnel_stop` (src/hev-socks5-tunnel.c:695) busy-waits in an
  infinite `for(;;) { READ_ONCE(event_fds[1]); usleep(100ms); }` loop until
  `event_fds[1] >= 0`, then writes the quit byte.
- `event_fds` starts `{-1,-1}`; `event_task_fini` closes both and resets them
  to `-1` when main returns; every init-failure return (-1..-5 in
  src/hev-main.c) exits before the socketpair exists.

Therefore any ordering where HEV main returns BEFORE `requestStop()` turns the
quit call into an infinite usleep loop on a Swift cooperative executor thread:

1. HEV init fails (fd/resource exhaustion — realistic on iOS) or HEV main exits
   unexpectedly while active — a path the p89bdj contract explicitly models
   ("Unexpected HEV main return while active -> treat as peer EOF and fail").
2. The bridge's hevTask observes `waitForReturn()` completing and signals the
   peer-EOF fatal (Sources/ReluxTunnelCore/PacketFlowBridge.swift:682-688).
3. `supervisedCleanup` unconditionally calls `borrowHandle?.requestStop()`
   (PacketFlowBridge.swift:1017) -> `hev_socks5_tunnel_quit()` after fini ->
   hangs forever. Cleanup never reaches descriptor close; provider `stop()`
   never returns. AC4's resource-release guarantee is defeated on this
   designed-for failure path. An explicit `stop()` racing a just-died HEV hits
   the same deadlock via `cleanupBeforeSupervision` (line 1029).

Why tests are green anyway: every lifecycle test stops the fake runtime before
its `run` returns, and fake `requestStop` never blocks. The reachable ordering
(main returns first, then requestStop) has no coverage.

### Required fix

- In `HEVDescriptorBorrowHandle.requestStop()`, skip `runtime.requestStop()`
  when HEV main has already returned (e.g. `context.returnCode != nil`). In the
  reachable bridge path this guard is deterministic: the pthread was joined
  before hevTask completed, so `returnCode` is already set when cleanup calls
  `requestStop()`. Keep `boundary.stop()` and the stop metrics as they are.
- Add a test with a fake runtime whose `run` returns immediately and which
  records/fails if `requestStop` is invoked after `run` returned; drive
  `waitForReturn()` first, then `requestStop()` (and the reverse order), and
  assert no quit call lands after main return.
- Record the residual inherent race in code docs or the task notes: quit
  concurrent with a spontaneous main return can still hit HEV's
  write-after-close/assert window. That race is upstream-inherent (hev-jni.c
  has the same exposure) and not fixable without patching HEV; the guard
  narrows it to that window. No HEV patch is requested.

## Secondary (should-fix with the rework)

`HEVLoopbackSOCKSBoundary.stop()` closes the listener fd on the caller's
executor while `acceptAvailableConnections()` may be mid-loop on
`listenerQueue` with the cached fd (HEVSOCKSBoundary.swift:211-235 vs 237-287).
Closed-fd accept is benign, but an fd-reuse window exists. Close the listener
from the dispatch source's cancel handler (or hop the close onto
`listenerQueue` after `cancel()`), keeping exactly-once semantics.

## Independently verified (all pass, reviewer-rerun)

- AC1: `make validate-native` exit 0 (reviewer rerun,
  .temp/TASK-260715-1vv52g/review-validate-native-01.log): boundary guard,
  fixture + HEV artifact-lock verify, iOS device/simulator + macOS provider
  xcodebuild matrix, stripped SwiftPM harness audit requiring
  hev_socks5_tunnel_main_from_str/quit/stats, 47 tests, final build.
- AC2: generator emits exact ADR-020 YAML (MTU injected, udp: tcp, task stack
  24576, tcp buffer 4096, udp-copy-buffer-nums 2, max sessions 1200), all
  values caller-injected via InternalSOCKSConfiguration; fail-closed rejection
  of any stack the pinned parser would silently raise, with the formula
  cross-checked against upstream hev-config.c. Descriptor pass-through and
  no-close verified by tests.
- AC3: IPv4-loopback listener, per-run random RFC 1929 credentials
  (YAML-safe charset enforced), constant-time compare, external no-auth ingress
  rejected with [5, 0xFF] before the adapter seam; authenticated owned channel
  is the only path through.
- AC4: startup-failure cleanup, idempotent stop/join, no double close — correct
  on all tested paths; the blocking finding above is the one uncovered ordering.
- AC5: embedded HEVNoticeBundle byte-identical to generated notices, both
  traced to the pinned manifest revisions; `verify --dependency hev-lwip`
  enforces equality and passes (reviewer rerun).
- HEV unmodified: pinned checkout clean at ad760049 with all four submodules at
  manifest revisions; source + archive checksums verified.
- `swift test` 47/47 green; TSan-filtered HEV suite clean;
  `swift-format lint --strict` clean (reviewer reruns).
- ADR-020 recorded in .spec/decisions.md; logbook entries present.

## Routing

Status -> to-dev for the implementer. Scope of rework: the requestStop guard +
ordering test (+ optional listener-close hop). No architectural or product
decision is needed; ADR-020 and the unmodified-HEV constraint stand.
