# BUG-260728-3jfjkh — stabilize-provider-failure-first-callback-ordering

## Diagnosis

`TunnelProviderAdapter.providerDidFail` (`Sources/ReluxTunnelCore/ProviderLifecycle.swift`) was
`nonisolated` and did all of its admission work inside a freshly spawned unstructured `Task`:

```swift
public nonisolated func providerDidFail(_ errorCode:, cancelTunnelWithError:) {
  Task { [weak self] in await self?.handleProviderFailure(...) }
}
```

Two `providerDidFail` calls therefore produced two independent tasks. Swift gives no ordering
guarantee between unstructured tasks contending for the same actor, so the *second* task could
enter `handleProviderFailure` first. Whichever task arrived first claimed
`cancelTunnelIssuedGeneration` for the active generation and invoked `cancelTunnelWithError`;
the loser was suppressed. The generation ledger enforced exactly-once but not *which* call won,
so the second error (`internalInvariant` 1009) intermittently beat the first
(`runtimeStartupFailed` 1007).

Both platform seams are affected identically: `IOSProviderCompositionRoot.providerDidFail` and
`MacOSProviderCompositionRoot.providerDidFail` forward straight to the shared adapter
(`Sources/ReluxTunnel{IOS,MacOS}Adapter/*ProviderCompositionRoot.swift:146`).

### Reproduction (pre-fix)

```
for i in $(seq 1 40); do swift test --filter 'providerFailureHandoff'; done
```

**10 of 40 runs failed** (runs 3, 6, 7, 12, 16, 27, 31, 32, 34, 36) — ~25% flake rate:

```
ProviderAdapterContractTests.swift:326:5: Expectation failed:
  (error.code → 1009) == (ProviderNSErrorCode.runtimeStartupFailed.rawValue → 1007)
```

Logs: `.temp/BUG-260728-3jfjkh/repro-*.log`.

## Fix

Move admission off the unordered task hop and onto the caller's thread, so program order decides
the winner instead of actor scheduling.

- New file-private `ProviderFailureAdmission` (`NSLock`-guarded claim flag) in
  `Sources/ReluxTunnelCore/ProviderLifecycle.swift`.
- `providerDidFail` now does `guard failureAdmission.claim() else { return }` **synchronously**
  before spawning the task. The first caller wins deterministically; later and concurrent callers
  are dropped before they can reach the actor.
- `startGeneration` calls `failureAdmission.releaseForNewGeneration()` when it bumps
  `latestGeneration`, keeping admission scoped per generation exactly as the old ledger was.
- Removed the now-redundant `cancelTunnelIssuedGeneration` var so admission has a single
  authority. `handleProviderFailure` calls `cancelTunnelWithError` unconditionally — it is only
  reachable once per generation.

Stop/join semantics are untouched: `awaitingSystemStopAfterProviderFailure`,
`stopAndJoin(reason: .providerFailure, keepStoppingAfterCleanup: true)`, cleanup-registry
cancel/force-close, and the `pendingStartGate` completion are unchanged. NSError codes are
unchanged, the assertion was not relaxed. Diff is +26/-6 lines in one source file.

Deadlock/reentrancy: the lock is never held across the `cancelTunnelWithError` invocation, so a
reentrant `providerDidFail` from inside the cancel handler just fails its claim and returns.

## Regression coverage

`Tests/ReluxTunnelCoreTests/ProviderAdapterContractTests.swift`, all parameterized over both
`AdapterSeam` cases (iOS + macOS):

1. `providerFailureFirstCallOrdering` — 50 sequential double-failure cycles per seam; asserts the
   first call's 1007 always wins, exactly one cancellation, adapter back to `.idle`.
2. `providerFailureConcurrentAdmission` — 16 concurrent `providerDidFail` calls, each cancel
   handler reentrantly calling `providerDidFail` again; asserts exactly-once cancellation, no
   deadlock, `stopReason() == .providerFailure`, adapter back to `.idle`.
3. `providerFailureAdmissionResetsPerGeneration` — two start/fail/stop cycles on one adapter;
   proves a fresh generation readmits a new failure (guards against the claim latching forever).

### The new ordering test catches the bug

With the source fix stashed and only the tests applied,
`providerFailureFirstCallOrdering` fails on **both** seams with 5 issues (all `1009 != 1007`),
while `providerFailureConcurrentAdmission` still passes — confirming test 1 is the targeted
regression guard and test 2 pins the exactly-once/no-deadlock invariant preserved by removing
`cancelTunnelIssuedGeneration`.

## Verification (post-fix, real exit codes)

| Gate | Command | Result |
| --- | --- | --- |
| Focused repeatability | `for i in $(seq 1 30); do swift test --filter 'providerFailureHandoff'; done` | **0/30 failures** (`.temp/BUG-260728-3jfjkh/verify-*.log`) |
| Full Swift suite | `swift test` | **exit 0** — 335 tests in 29 suites passed (`.temp/BUG-260728-3jfjkh/full-suite-01.log`) |
| Boundary lint | `make check-core-boundaries` | exit 0 — "ReluxTunnelCore dependency and import boundaries are valid" |
| Format lint | `swift-format lint --strict <both changed files>` | exit 0 |
| Full validation | `make validate-core` | **exit 0** — boundaries + native deps + `swift test` (335 passed) + `swift build` (`.temp/BUG-260728-3jfjkh/validate-core-01.log`) |

## Acceptance criteria

1. Two sequential `providerDidFail` calls deliver the first error exactly once on both seams —
   met, deterministic via synchronous claim; proven by `providerFailureFirstCallOrdering`
   (50 cycles × 2 seams) and the 30/30 clean `providerFailureHandoff` runs.
2. Concurrent/reentrant calls stay exactly-once with no deadlock or cleanup leak — met, proven by
   `providerFailureConcurrentAdmission`.
3. Focused test passes ≥ 30 consecutive runs — met, 30/30.
4. Complete `swift test` passes with real exit 0 — met, 335 tests, exit 0.
5. Fix is minimal and preserves stop/join semantics — met (single source file, +26/-6, no change
   to cleanup, stop reasons, or NSError codes). Independent review is the pending reviewer step.

## Changed files

- `Sources/ReluxTunnelCore/ProviderLifecycle.swift`
- `Tests/ReluxTunnelCoreTests/ProviderAdapterContractTests.swift`
