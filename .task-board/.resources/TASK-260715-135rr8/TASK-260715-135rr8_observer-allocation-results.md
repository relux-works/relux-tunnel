# TASK-260715-135rr8 observer-allocation rework results

## Candidate and scope

- Repaired Story base: `89d9c6425dde28709aca492de32943407d9b67bb`.
- Exact candidate tree independently recomputed after all repository edits: `9bf19e4ea3afe61a30bdac875cad05cec28fabce`.
- Pinned HEV macOS archive SHA-256 independently verified by every production entry: `f6bdda3e182049877dc449c670f8a2300007461e3ac3e4c5d2c1b0394de91eee`.
- Patch SHA-256: `d1c0a9295fded9aae3c29c07814c212f3d6ee8c304fc17191084b3ba84253335`.
- Patch paths are exactly `LOGBOOK.md`, `README.md`, and `Tests/ReluxTunnelNativeAdapterTests/HEVBridgeIntegrationTests.swift`; no MTU path is present. `git apply --check` exits 0 against both repaired Story base `89d9c642` and main `d177ac7`.

## Observer fix and negative evidence

`measureRealHEVLifecycle` now reserves the exact bounded sample count before its initial process snapshot. The production-call-site regression proves capacity for 1000 retained samples. The diagnostic entry accepts only 100, 500, or 1000 cycles; absent, malformed, and 2000-cycle requests are rejected. Existing exact-tree and independently hashed HEV artifact gates remain fail closed.

The corrected 100/500/1000 probes all exited 0. Their post-warmup net changes were `+81,944 B`, `-212,992 B`, and `-32,768 B`; maximum drawups were `98,328 B`, `65,536 B`, and `65,536 B`; transitions were `3/85/1`, `4/479/6`, and `7/977/5` increase/equal/decrease. All owned session/read/queue residuals were zero. The earlier observer-capacity jumps above cycle 1000 disappeared; the last 1000-cycle increase was cycle 481.

A fresh 100-cycle production matrix attempt exited 1 on one `+65,536 B` increase with no release, proving 100 samples are not repeatable enough. The final gate therefore uses the next predeclared bounded row: 500 cycles, fixed 10-sample warmup, maximum drawup at most 256 KiB, and either no increase or at least one measured release. Pure tests reject rise-plus-plateau, plateau-then-late-growth, oversized high-water, and a released but over-ceiling sawtooth; bounded release/plateau cases pass. A well-formed forged tree production invocation exited 1 with the exact mismatch and emitted no raw artifact.

## Three exact-tree physical matrix runs

All rows ran on physical Mac15,9, arm64, macOS 26.5, through SwiftPM/loopback only. Each run admitted 100/250/500 live HEV sessions, recorded zero drops, stopped at the explicit 500-session ceiling, and did not request 1200.

| Run | Raw SHA-256 | 500-session footprint / peak | Incremental HEV/bridge | Remaining 30 MiB | Lifecycle net / max drawup | Transitions inc/eq/dec |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| 01 | `4b3016d5ed9b99cc27b18a98ae81ccaed8f0adc2f04766c96113f90fff03f8f2` | 21,578,376 B / 21,594,760 B | 9,502,720 B | 21,954,560 B | -98,280 B / 147,480 B | 7/479/3 |
| 02 | `f61b8aa00a8212ef8b7d82c00bd8e1c593f43e3fc0f2814d6295b503e724d7b1` | 21,693,040 B / 21,709,424 B | 9,633,792 B | 21,823,488 B | +98,304 B / 98,304 B | 7/481/1 |
| 03 | `10bf4ee5fd2b5aa3b721b2fe043e7c5a4b61fe7e49093cabf220b9db290d6813` | 21,512,840 B / 21,529,224 B | 9,650,224 B | 21,807,056 B | -655,360 B / 49,152 B | 3/484/2 |

Every run recorded bounded convergence, no monotonic growth, descriptors `9 -> 3`, threads ending at 7, and zero owned sessions, reads, and queues after every cleanup. Descriptors during staged rows were 211/511/about 1010, consistent with the process-owned flow resources. The provisional 25-30 MiB target is met only for the incremental HEV/bridge baseline; it is not a whole-extension or Apple guarantee. SSH, DNS, relay, caches, and reconnect overlap remain unmeasured. macOS available memory, HEV queued bytes, and process-wide Swift Task count are explicitly unavailable/unknown rather than proxy zero. Physical iPhone and sleep/wake remain named deferred gaps. Pressure ordering remains deferred until SSH admission integration; no global pressure mechanism was used.

## Validation and safety

- Focused HEV suite: exit 0, 26 tests.
- Focused lifecycle/cancellation/pressure suites: exit 0, 36 tests across 3 suites, including 7 startup and 7 cleanup cancellation cases.
- Full `swift test --enable-code-coverage`: exit 0, 491 tests in 40 suites, with 25 declared known ReluxNIOSSH candidate-unavailable issues.
- Affected coverage: 83.02% lines, 87.15% functions, 77.19% regions. The first report command incorrectly passed Swift's exported JSON to `llvm-cov` and exited 1 with `bad magic`; the corrected `default.profdata` rerun exited 0.
- `swift format lint --strict --recursive Sources Tests Package.swift`: exit 0.
- `git diff --check`: exit 0.
- Privacy diff scan: zero secret-pattern matches. Safety API scan found only the bounded `/usr/bin/env git` exact-tree resolver; no NetworkExtension/VPN, route, DNS, interface, packet-filter, Keychain, sudo, powermetrics, memory_pressure, launchctl, unrelated-process kill, SSH, or global-setting mutation ran.

This tester handoff is ready for independent review; it does not mark the task done.
