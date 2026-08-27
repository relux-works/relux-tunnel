# TASK-260715-135rr8 CR rev4 tester outcome

## Verdict

Ready for independent review. CR rev4 separates deterministic harness-owned resource release from Darwin allocator page-return timing without weakening the 500-cycle or 256 KiB resident-footprint bounds.

## Exact candidate and integration

- Story base: `89d9c6425dde28709aca492de32943407d9b67bb`
- Current main: `d177ac7dae6c10b7527c15f0a1ad31387890828e`
- Exact candidate tree: `c807a161cf619dd9cb8a99a2555114b9f28bf2f6`
- Pinned HEV revision: `ad7600497931205105b08367bd1b450048157e40`
- Pinned macOS HEV artifact SHA-256: `f6bdda3e182049877dc449c670f8a2300007461e3ac3e4c5d2c1b0394de91eee`
- Patch SHA-256: `ec7380f36763a2901d93093188b3a577ccfbb776cedc2d5d19ff0439d3a288d0`
- Changed paths are exactly `LOGBOOK.md`, `README.md`, and `Tests/ReluxTunnelNativeAdapterTests/HEVBridgeIntegrationTests.swift`; no MTU paths are present.
- The patch applies through temporary alternate indexes to both the Story base and current main. The managed worktree index and branch were not switched, staged, rebased, merged, or committed.

## Physical matrix

Device: physical Apple-silicon Mac15,9, arm64, macOS 26.5 build 25F71. All execution used SwiftPM, numeric loopback, and process-owned HEV resources only.

| Run | 100 / 250 / 500 sessions | 500 physical / peak | Incremental HEV/bridge | 500-cycle max drawup | Owned releases | Drops |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| rev4-final-01 | 100 / 250 / 500 | 21,824,136 B / 21,840,520 B | 9,551,872 B | 180,248 B | 500 / 500 | 0 / 0 / 0 |
| rev4-final-02 | 100 / 250 / 500 | 20,595,336 B / 20,611,720 B | 9,715,712 B | 131,096 B | 500 / 500 | 0 / 0 / 0 |
| rev4-final-03 | 100 / 250 / 500 | 20,415,112 B / 20,431,496 B | 9,469,952 B | 81,920 B | 500 / 500 | 0 / 0 / 0 |

Every run stopped at the explicit 500-session configuration limit and did not attempt 1200. Stage descriptor counts were 211 / 511 / 1010. Lifecycle cleanup returned process descriptors from 9 to 3 and threads to 7-9; every per-cycle sample recorded boundary start/stop 1/1, HEV start/main-return 1/1, zero live channels/queued batches/outstanding reads/cleanup errors, and both descriptor-close stages.

The provisional 25-30 MiB target is met for incremental HEV/bridge cost only: the worst measured delta was 9,715,712 B, leaving 16,498,688 B in a 25 MiB envelope and 21,741,568 B in a 30 MiB envelope. This is not a whole-extension or Apple memory guarantee. SSH, DNS, relay, caches, and reconnect overlap remain unmeasured and must fit the residual budget.

`os_proc_available_memory` is recorded as unavailable on macOS; HEV queued bytes and process-wide Swift Task count are unknown. No proxy zeros are used. Physical iPhone and sleep/wake remain named deferred gaps. Soft/pressure admission ordering remains deferred until SSH integration; critical bridge teardown and bounded pressure/fault behavior are covered.

## Rev4 gate and negative evidence

- Schema 2 preserves each lifecycle sample and writes the exact-tree-bound raw matrix atomically before a failing lifecycle verdict is returned.
- The production gate requires at least 500 samples, maximum post-warmup resident drawup <= 256 KiB, and zero owned-resource-release failure cycles.
- Pure negative tests reject 499 cycles, footprint overflow, and a missing release at cycle 499.
- The production emission-order negative test proves the evidence closure runs before refusal.
- A real production-entry invocation with a forged well-formed 40-hex tree OID failed with exit 1 before HEV/matrix work and emitted no raw artifact.
- The original `proc_pid_rusage` signal-6 path remains retired; measurements use public `task_info(TASK_VM_INFO)` and `proc_pidinfo(PROC_PIDTASKINFO)`.

## Validation

- Three sequential exact-tree matrix runs: exit 0 each.
- Full Swift coverage suite: 494 tests in 40 suites passed, exit 0; 25 predeclared ReluxNIOSSH-candidate-unavailable known issues.
- Merged full-suite + physical-matrix affected coverage: 84.81% regions, 93.77% functions, 92.35% lines.
- Focused lifecycle gates: 11 tests passed; production emission-order test passed.
- Real 100-cycle lifecycle: passed; startup/cleanup cancellation suite 8 tests passed; pressure/fault suite 20 tests passed; the full suite includes 50 terminate-cancellation harness iterations.
- `make validate-core`: exit 0 (core boundaries, native dependencies, full Swift tests, build).
- `swift-format lint --strict --recursive Package.swift Sources Tests`: exit 0.
- `git diff --check`, safety scan, privacy scan, measurement-authenticity scan, and patch apply checks: pass.

## Raw artifacts

- `TASK-260715-135rr8_raw-memory-matrix-rev4-final-01.json` SHA-256 `1c0fb51bd91a5cc521a33326b688014ab88d1305900904c1052734823eb1ee9c`
- `TASK-260715-135rr8_raw-memory-matrix-rev4-final-02.json` SHA-256 `ae0eddd0cec570c8d61650cc81190faef0ac55e855a6f977eb1d58f8edad0083`
- `TASK-260715-135rr8_raw-memory-matrix-rev4-final-03.json` SHA-256 `22d7af4102110a793b7bcd1ff8f7119c9964b3ec011c4bc40e6a4c9510b889c1`
- Matrix logs SHA-256: `c491db4930cdd2d9da3ba9c0e888788f3b66506972e430c1f93c2c03f15afa26`, `fb21f844cab44c9664c4dca0e8b39e59e9613a743fea9c33e231ee646e1fc15b`, `3a14ad1e6302f0362842b0db3ba6ce9aefa58d4e16a5f9c56990367b5c0c28f5`.
- Full coverage log SHA-256: `648f7d8b5c9b75625acbaa7a83c44212dfb19872d3688bb672799fe89737c38f`.
- Affected coverage report SHA-256: `226cccdb5a19c77a555637da2a36124bd381962527f9b78f6672a89e8ac89c28`.

## Safety

No NetworkExtension or VPN was installed, signed, loaded, enabled, or configured. No route, DNS, interface, packet filter, Keychain, SSH session, global memory pressure, sudo, launchctl, powermetrics, unrelated process, or global system setting was modified.
