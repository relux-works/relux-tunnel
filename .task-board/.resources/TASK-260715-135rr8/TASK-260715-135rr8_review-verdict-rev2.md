# TASK-260715-135rr8 CR rev2 review verdict

## Verdict

Changes requested. CR `CR-TASK-260715-135rr8-2` revision 2 is not accepted.
The exact candidate tree is `24a9d147e2464f1157ef10eb6ef3ed51dae2b5e5` on base
`89d9c6425dde28709aca492de32943407d9b67bb`; the three-file patch is clean and
applies to current main `d177ac7dae6c10b7527c15f0a1ad31387890828e`.

## Blocking findings

### F1 — exact-tree provenance can be forged by the caller

The production emitter calls `physicalMatrixProvenance` from
`physicalMemoryAndConcurrencyMatrix`, but the helper only checks that
`RELUX_CANDIDATE_TREE_OID` is 40 lowercase hex characters. It never establishes
that the value equals the actual candidate tree. The existing negative test
rejects missing and malformed values, but does not reject a well-formed wrong
OID.

Reviewer defeat command:

```bash
RELUX_RUN_PHYSICAL_MEMORY_MATRIX=1 \
RELUX_MATRIX_RUN_ID=reviewer-forged-oid \
RELUX_CANDIDATE_TREE_OID=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
swift test --filter HEVIntegrationTests.physicalMemoryAndConcurrencyMatrix
```

Unexpected result: exit 0. The production emitter completed 100 lifecycle
cycles plus 100/250/500 live-session rows and wrote a report whose
`sourceRevision` and `ReluxTunnelNativeAdapter.tree` both falsely claim
`aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa`. This violates the exact-tree gate
and the forged/self-minted evidence negative shape.

Required rework: bind provenance to the actual reviewed tree rather than trust
a caller-minted string. Add a production-entry negative test that supplies a
well-formed wrong OID and requires refusal; a helper-only malformed-input test
is insufficient.

### F2 — lifecycle monotonic-growth gate is narrowed to strict growth

The emitter derives `monotonicGrowthObserved` with
`zip(samples, samples.dropFirst()).allSatisfy(<)`. That detects only a strictly
larger footprint on every cycle and treats plateaus as proof that growth is not
monotonic.

Independent reviewer evidence exposed the defect:

| Run | Increases | Equal transitions | Decreases | First sample | Last sample | Reported |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| reviewer-run-01 | 13 | 86 | 0 | 10,551,920 B | 11,223,688 B | `false` |
| reviewer-run-03 | 13 | 86 | 0 | 10,306,160 B | 10,863,240 B | `false` |

Both sequences are non-decreasing and end higher, yet the report attests no
monotonic growth. Required rework: define the intended trend explicitly and
flag non-decreasing growth with plateaus (or use another justified trend rule).
Add a negative test with rises plus equal samples that must fail the attestation.
Regenerate the three raw runs and correct README/LOGBOOK claims after the gate
is fixed.

## Passing independent gates

- Exact delta: 3 paths only; no MTU duplicate scope; resource patch SHA-256
  `c8801a48db35d2310ea6018dda518e3f19b6517336722bdcaf13f71457c2f275`;
  byte-for-byte equal to the exact Git diff.
- Patch applies to current main: exit 0. `git diff --check`: exit 0.
- Three reviewer matrix runs on the exact candidate: all exit 0. Every run
  measured 100 lifecycle samples, then 100/250/500 live HEV sessions, zero
  drops, descriptor counts 211/511/1010, and stopped at 500 without 1200.
- Authentic sampler: final code uses public `task_info(TASK_VM_INFO)` plus
  `proc_pidinfo(PROC_PIDTASKINFO)`; all reviewer runs and the deliberate defeat
  run completed without the retired `proc_pid_rusage` crash.
- Unavailable fields are honest: host available memory, HEV queued bytes, and
  process-wide Swift Task count are null with explicit explanations.
- Focused HEV suite: 16 tests, exit 0. Focused bridge lifecycle/fault/bounded
  suite: 36 tests, exit 0.
- Full coverage suite: 481 tests in 40 suites, exit 0, with 25 declared known
  ReluxNIOSSH adapter-unavailable issues.
- Affected file coverage: 85.03% lines, 89.45% functions, 78.71% regions.
- Strict Swift format, privacy scan, safety scan, exact-tree recheck, and
  patch-apply check: exit 0. No VPN/NetworkExtension, route, DNS, interface,
  packet-filter, Keychain, SSH-session, sudo, launchctl, or global-pressure
  mutation was used.

## Reviewer evidence

The board also carries three task-scoped reviewer raw matrix reports and the
forged-OID negative report/log. Local validation logs were produced under
`.temp/TASK-260715-135rr8-review/` before this verdict.
