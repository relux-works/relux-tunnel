# TASK-260715-135rr8 CR rev4 independent review verdict

## Verdict

Accepted for orchestrator integration. This review is bound to CR `CR-TASK-260715-135rr8-4` revision 4, Story base `89d9c6425dde28709aca492de32943407d9b67bb`, current `main` `d177ac7dae6c10b7527c15f0a1ad31387890828e`, and candidate tree `c807a161cf619dd9cb8a99a2555114b9f28bf2f6`.

## Exact tree and patch

- An independent temporary Git index rebuilt the working tree as `c807a161cf619dd9cb8a99a2555114b9f28bf2f6` before and after validation.
- Both board patch resources and the independently generated base-to-candidate diff hash to `ec7380f36763a2901d93093188b3a577ccfbb776cedc2d5d19ff0439d3a288d0` and are byte-identical.
- The patch contains exactly `LOGBOOK.md`, `README.md`, and `Tests/ReluxTunnelNativeAdapterTests/HEVBridgeIntegrationTests.swift`; no MTU scope is present.
- Alternate-index `git apply --cached --check` passes against the Story base and current `main`; `git diff --check` passes.
- The pinned macOS HEV archive independently hashes to manifest SHA-256 `f6bdda3e182049877dc449c670f8a2300007461e3ac3e4c5d2c1b0394de91eee` at revision `ad7600497931205105b08367bd1b450048157e40`.

## Independent physical evidence

Three sequential, non-concurrent exact-tree production matrix invocations passed:

| Run | Stages | Drops | Lifecycle | Maximum drawup | Owned releases | Raw SHA-256 |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| reviewer-rev4-01 | 100 / 250 / 500 | 0 / 0 / 0 | 500 | 81,944 B | 500 / 500 | `f4544e0de480953f82556b8c0214aea8ec02af9b43f1c2d283051bf6e2048dfa` |
| reviewer-rev4-02 | 100 / 250 / 500 | 0 / 0 / 0 | 500 | 114,688 B | 500 / 500 | `ca28b7f307fbef102586459abb7a63fbd258b2184763ad28daf0a0ae585b850d` |
| reviewer-rev4-03 | 100 / 250 / 500 | 0 / 0 / 0 | 500 | 114,688 B | 500 / 500 | `c9d30a54559e02915d7100ee2026a9f132c2d5fcd7e30614fb17b36e4723e5f1` |

All runs stopped at the explicit 500-session ceiling and did not attempt 1200. Stage descriptor counts were 211 / 511 / 1010. Every lifecycle sample recorded zero live HEV channels, outstanding reads, queued batches, and cleanup errors; both descriptor-close stages and HEV main return were observed. Post-cleanup lifecycle descriptor range was 3...3. The unchanged 256 KiB maximum-drawup bound passed in every run.

Schema 2 preserves every per-cycle value and the production call site emits the exact-tree-bound report before returning a lifecycle verdict failure. The gate rejects 499 cycles, footprint overflow, and a missing release at cycle 499. A forged well-formed candidate OID independently exited 1 and emitted no raw artifact. A forged artifact hash is rejected by focused production-provenance coverage. No retry-until-green, arbitrary delay, threshold widening, synthetic ownership counter, or allocator page-return proxy was found.

Unavailable host available-memory, HEV queued-byte, and process-wide Swift Task fields remain `null` with explicit unavailable/unknown explanations. The budget claim remains incremental HEV/bridge only; SSH, DNS, relay, cache, reconnect overlap, physical iPhone, and sleep/wake remain named gaps. There is no Apple or whole-extension guarantee.

## Validation

- Focused HEV suite: 21/21 passed, including real 100-cycle lifecycle and provenance/gate negatives.
- Lifecycle cancellation suite: 8/8 passed. Pressure/fault suite: 20/20 passed.
- Three independent physical matrices: exit 0 each. One additional coverage-enabled physical matrix also passed.
- Full coverage rerun: 494 tests in 40 suites passed with 25 declared ReluxNIOSSH-unavailable known issues.
- Merged full-plus-physical affected coverage: 84.81% regions, 93.77% functions, 92.35% lines.
- Strict recursive Swift format, core-boundary verification, native-dependency verification, diff check, privacy scan, safety scan, and measurement-authenticity scan passed.
- No NetworkExtension/VPN, route, DNS, interface, packet-filter, Keychain, SSH-session, global-pressure, sudo, launchctl, powermetrics, or unrelated-process mutation occurred.

## Preserved anomaly

The first independent full coverage run exited 1 because the pre-existing libssh2 `channelOperationPressureIsBounded` race observed `.cancelled` instead of `.resourceLimitExceeded`; the candidate does not touch that code. The same known LOGBOOK anomaly reproduced in 1 of 5 focused repeats. A fresh full coverage rerun passed all 494 tests. Both results are preserved; acceptance does not claim this unrelated existing flake was fixed by CR rev4.

The reviewer supplies no `commit_ack`; the orchestrator owns signed landing and the final `done` transition.
