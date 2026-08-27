# TASK-260715-135rr8 rev2 tester outcome

## Exact candidate

- Candidate tree OID: `24a9d147e2464f1157ef10eb6ef3ed51dae2b5e5`.
- Repaired Story baseline: `89d9c6425dde28709aca492de32943407d9b67bb`.
- Current main checked: `d177ac7dae6c10b7527c15f0a1ad31387890828e`.
- Repository delta is exactly `LOGBOOK.md`, `README.md`, and `Tests/ReluxTunnelNativeAdapterTests/HEVBridgeIntegrationTests.swift`.
- The rev2 binary patch applies cleanly to both the repaired Story baseline and current main (`git apply --check`, exit 0).
- HEV provenance is read from the pinned native manifest: revision `ad7600497931205105b08367bd1b450048157e40`, source SHA-256 `1d48d9b8a4dd5befc3460fda3ac4684149ace458c1630ca5f5692c9dc8dd154f`.

## Three independent physical-Mac runs

All three runs executed on physical `Mac15,9`, arm64, macOS 26.5. Each separate Swift Testing process performed its own measured 100-cycle HEV lifecycle before staging 100, 250, and 500 live loopback UDP-in-TCP sessions. All processes exited 0 and all raw reports carry the exact candidate tree OID above.

| Run | Duration | 100-session footprint | 250-session footprint | 500-session footprint / peak | Incremental 500-session cost | Remaining 30 MiB envelope |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| rev2-run-01 | 5.700s | 12,944,008 B | 15,762,056 B | 20,497,032 B / 20,513,416 B | 9,453,568 B | 22,003,712 B |
| rev2-run-02 | 5.426s | 12,763,784 B | 15,565,448 B | 20,349,576 B / 20,365,960 B | 9,519,104 B | 21,938,176 B |
| rev2-run-03 | 5.754s | 12,878,448 B | 15,696,496 B | 20,578,952 B / 20,595,336 B | 9,650,224 B | 21,807,056 B |

Every row reported the requested live HEV session count, zero bridge drops, 8-9 process threads, and descriptor counts 211 / 511 / 1010. The configuration stopped at the explicitly narrowed 500-session limit and did not attempt 1200. Configured resource facts were 24,576 B HEV task stack/session, 4,096 B HEV TCP buffer/session, and 16,384 B bridge socket buffer. HEV queued bytes, process-wide Swift Task count, and macOS `os_proc_available_memory` remain explicitly unavailable/unknown rather than proxy zeros.

The incremental HEV/bridge baseline meets the provisional 25-30 MiB target in all three runs. The 20.80-20.98 MiB remainder is not a production-extension guarantee: SSH, DNS, relay, caches, and reconnect overlap remain unmeasured and unallocated.

## Lifecycle, traffic, pressure, and safety

- Each raw report contains 100 per-cycle samples. Descriptors returned 3 -> 3; threads returned 7 -> 7 or 8 -> 8; live HEV sessions, outstanding reads, and queued batches were zero after every cleanup. Physical footprint was derived from captured samples and was not monotonic in any run.
- The standalone 100-cycle lifecycle test passed in 3.911s. Startup cancellation at seven stages and cleanup cancellation at seven stages passed. Focused production HEV mixed IPv4/IPv6 bidirectional TCP, UDP-in-TCP, bounded stall, bridge-fault teardown, host-owned cleanup, and zero-session refusal tests passed.
- Harness pressure rows and negative pressure-accounting gates passed. Soft -> pressure -> critical SSH admission ordering remains explicitly deferred until SSH integration; the run did not fabricate a policy consumer.
- Physical iPhone and sleep/wake are named deferred gaps. No NetworkExtension/VPN was installed or started; no route, DNS, interface, packet-filter, Keychain, SSH session, global pressure tool, `sudo`, `launchctl`, or unrelated process was touched.
- The original signal 6 came from the retired `proc_pid_rusage` importer. Three final runs exercised the public `task_info(TASK_VM_INFO)` plus `proc_pidinfo(PROC_PIDTASKINFO)` sampler without a crash.

## Validation

- Negative provenance gate: exit 0; missing/malformed run ID, candidate OID, and HEV manifest provenance are refused through the same emitter call path.
- Focused lifecycle/cancellation suite: 8 tests, exit 0.
- Focused harness pressure/termination suite: 29 tests, exit 0.
- Focused HEV suite: 16 tests, exit 0.
- Full Swift coverage suite: 481 tests in 40 suites, exit 0, with 25 declared ReluxNIOSSH adapter-unavailable known issues.
- Affected test file coverage: 85.03% lines, 89.45% functions, 78.71% regions.
- Strict Swift format, `git diff --check`, three-run JSON invariants, exact-tree recheck, privacy scan, safety scan, and both patch-apply checks passed.

## Evidence files

- `TASK-260715-135rr8_raw-memory-matrix-rev2-run-01.json`
- `TASK-260715-135rr8_raw-memory-matrix-rev2-run-02.json`
- `TASK-260715-135rr8_raw-memory-matrix-rev2-run-03.json`
- `swift-physical-matrix-rev2-run-01.log`
- `swift-physical-matrix-rev2-run-02.log`
- `swift-physical-matrix-rev2-run-03.log`
- `swift-full-coverage-rev2.log`
- `llvm-cov-affected-rev2.log`
- `repeatability-summary.json`
- `TASK-260715-135rr8-change-request-rev2.patch`
