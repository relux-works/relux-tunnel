# TASK-260715-135rr8 CR rev3 independent review verdict

## Verdict

Changes requested. CR `CR-TASK-260715-135rr8-3` revision 3 is not accepted because the mandatory independent physical matrix repeatability gate is flaky on the exact reviewed candidate tree.

Reviewed candidate tree: `9bf19e4ea3afe61a30bdac875cad05cec28fabce`.
Story base: `89d9c6425dde28709aca492de32943407d9b67bb`.
Current main: `d177ac7dae6c10b7527c15f0a1ad31387890828e`.
CR patch SHA-256: `d1c0a9295fded9aae3c29c07814c212f3d6ee8c304fc17191084b3ba84253335`.
Pinned HEV macOS archive SHA-256: `f6bdda3e182049877dc449c670f8a2300007461e3ac3e4c5d2c1b0394de91eee`.

## Blocking finding F1 — exact-tree matrix is not repeatable

Three sequential, non-concurrent, physical Mac SwiftPM/loopback production-entry runs were executed with distinct run IDs and the exact candidate OID:

| Run | Exit | Result |
| --- | ---: | --- |
| reviewer-rev3-01 | 1 | Fail-closed before matrix emission: 490 analyzed post-warmup samples, net/max drawup `+180224/+180224 B`, at least one increase and zero decreases. Error: `physical footprint did not prove bounded convergence`. No raw JSON was emitted. Log SHA-256 `b08a01bf6a83d7e3a79d7b52d65cc866cf644b24486619dce05ae8c8fb714a5f`. |
| reviewer-rev3-02 | 0 | Passed; 100/250/500 sessions, zero drops, hard stop at 500. Lifecycle net/drawup `+24/+213016 B`, transitions `7/480/2`, 500 samples, zero cleanup violations. Raw SHA-256 `0c788e4e6e7a7847efbffbb0a12301be24add196e2352ceeb67172f8cd40d71f`. |
| reviewer-rev3-03 | 0 | Passed; 100/250/500 sessions, zero drops, hard stop at 500. Lifecycle net/drawup `-1310696/+114712 B`, transitions `5/483/1`, 500 samples, zero cleanup violations. Raw SHA-256 `05fde803ed227e3a1ac01e555813318afd96a6715ec6e5138701945a768b1c16`. |

The classifier correctly refused the first run; this is evidence that the gate is active, not evidence that the matrix is repeatable. The review contract explicitly requires multiple independently passing exact-tree runs and requires changes for a flaky matrix. Independent result is `2 pass / 1 fail`; therefore the CR cannot be accepted.

Required rework: preserve the fail-closed rule and the 500-cycle/256 KiB bounds. Do not weaken the release requirement or widen the ceiling to make this sample pass. Capture a cryptographically exact-tree-bound raw lifecycle artifact for a failed production-entry attempt before returning the failure, then investigate why a bounded `180224 B` rise sometimes has no observed release within 500 cycles. Re-run enough bounded sequential 500-cycle probes to demonstrate repeatability and regenerate three passing exact-tree matrix artifacts. If the non-release remains real, keep the gate failing and report the unresolved lifecycle behavior rather than tuning around it.

## Gates that passed

- Actual working tree independently rebuilt through a temporary Git index: `9bf19e4ea3afe61a30bdac875cad05cec28fabce`.
- Board CR patch bytes equal the exact base-to-candidate diff; the patch applies cleanly to both Story base and current main. Paths are exactly `LOGBOOK.md`, `README.md`, and `Tests/ReluxTunnelNativeAdapterTests/HEVBridgeIntegrationTests.swift`; no MTU duplicate scope.
- HEV artifact hash independently recomputed and equals the manifest pin.
- Forged well-formed candidate OID production invocation: underlying Swift test exit 1 with exact mismatch, wrapper negative gate exit 0, and no raw artifact emitted. Log SHA-256 `09caed0855d7f48111476add1fdc4ce557e36acd980a6f0f70920ba60ed3f7c9`.
- Retained lifecycle samples are reserved before the initial process snapshot. Pure tests cover rise-plus-plateau, fixed warmup stabilization, late rise after plateau, excessive maximum drawup, bounded release, observer capacity, and rejection of 2000/malformed diagnostic rows.
- Focused HEV suite: exit 0, 26 tests. SHA-256 `f40070bebe953cc061f3edcc3cc12942009296978eed6ba8605e72610079e7c9`.
- Lifecycle/cancellation/pressure-focused filter: exit 0, 47 tests in 5 suites, including 100 restart cycles and 7 startup plus 7 cleanup cancellation points. SHA-256 `5dee9d615a3423a808a0550907e629d9199066063e01dc3326ce7806780fc7ad`.
- Full `swift test --enable-code-coverage`: exit 0, 491 tests in 40 suites with 25 declared known ReluxNIOSSH-unavailable issues. SHA-256 `2d41b1840fbd07071eb0f42a1efd67210231eb930ed96972c8f27d7473f1bf57`.
- Affected coverage: 83.02% lines and 87.15% functions (77.19% regions), exit 0. SHA-256 `903cf86f7d1eea4120f7ed71bc6d49948dee1491fc1897fb3eaec5be0097e992`.
- Strict recursive Swift format: exit 0. `git diff --check`: exit 0.
- Privacy scan found no credential/key patterns. Safety review found only the task-local `/usr/bin/env git` actual-tree resolver (`read-tree`, `add -A`, `write-tree`); no VPN/NetworkExtension, route, DNS, interface, packet-filter, SSH, Keychain, sudo, powermetrics, global memory pressure, launchctl, or unrelated-process operation was added or run.
- Successful reviewer raw reports are exact-tree/artifact bound and honestly keep macOS available memory, HEV queued bytes, and process-wide Swift Task count unavailable/unknown. They state the incremental-only 30 MiB budget and keep SSH/DNS/relay/cache/reconnect, iPhone, and sleep/wake as unmeasured/deferred gaps.

## Reviewer evidence locations

Local task-scoped logs and raw JSON are under `.temp/TASK-260715-135rr8/`. Operational probe mistakes are explicitly recorded in `tool-failures-01.log`; their results were discarded and clean reruns were used. This verdict is the board-owned handoff evidence. Reviewer did not stage, commit, mutate VPN/network state, or supply `commit_ack`.
