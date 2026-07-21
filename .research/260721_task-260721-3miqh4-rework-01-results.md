# TASK-260721-3miqh4 — rework 01 results

Status: superseded by bounded validator-assertion rework `BUG-260721-17f093`; production authorization remains false  
Date: 2026-07-21  
Task: `TASK-260721-3miqh4` — Establish evidence-gated DNS profile and runtime limits

## Key takeaways

- The second independent review found three remaining harness assertion defects.
  `BUG-260721-17f093` replaces the tautological timing rows, incomplete authority
  verifier, and broad reliability bounds with real fail-closed assertions.
- The injectable candidate policy remains deliberately non-authoritative.
  `productionAuthorization.permitted` is `false`; ADR-022 remains Proposed and
  downstream production/profile consumers remain gated.
- The candidate default ledger is 3,686,706 / 4,194,304 bytes; the candidate
  hard-envelope ledger is 7,635,554 / 8,388,608 bytes. These are internally
  accounted local candidates, not an accepted extension allocation.
- Production selection still requires accepted selected-engine SSH
  `direct-tcpip` evidence and an accepted ADR-009 residual DNS budget. Physical
  provider startup/footprint evidence is a later physical gate and is not
  represented by local Python/RSS measurements.

## Reviewer findings and corrections

| Changes-requested finding | Correction | Evidence |
| --- | --- | --- |
| Maximum DNS/TCP wire accounting was one byte short and lacked a maximum-wire boundary fixture. | Read and write buffers are each 65,537 bytes: 65,535 message bytes plus the two-byte TCP length prefix. The validator accepts the exact maximum and rejects a 65,536-byte message. | Policy `accountingConstants`, `wireBoundaryVectors`, nine self-test vectors, maximum request/response, split-prefix, split-body, bytewise partial-write, and coalesced-frame fixture rows. |
| M2 timing omitted relay/UDP and dispatch work and did not distinguish ready/cold TCP states. | Added explicit relay/UDP and dispatch fields plus startup, M1-ready, M1-cold, M2-ready, and M2-cold equations under one non-resetting logical deadline. The bug rework now exercises all five relationships at default and hard envelopes through the real validator. | Twenty equality/one-millisecond-under mutations assert the relationship-specific error tag; startup and governing M2-cold equality leave the whole policy valid. |
| Reliability results were labelled or tautological rather than exercised. | Replaced them with an explicit transaction-owner/event-trace simulation. The bug rework freezes and checks the exact projection for every scenario. | All 14 scenarios assert UDP/TCP attempts and endpoint order, terminal identities/outcomes, duplicate/late/cancellation/tombstone counts, epochs/retry batches, full trace signatures, and zero cleanup. |
| Cleanup zero was assigned rather than observed. | Added live ownership counters for transactions, queued bytes, reservations, tombstones, connections, connection buffers, and fixed bytes. | Every scenario and all nine raw trials end with zero ownership. Six isolated memory trials also record zero file-descriptor delta. |
| Local Python/RSS results did not authorize production memory or timing values. | The report and policy now stop the line instead of authorizing the candidates. | `productionAuthorization.permitted=false`; the policy, report, summary, downstream handoff, ADR/spec/README/logbook, and downstream precondition copies identify the same missing evidence gates. |

## Candidate policy packet

The machine-readable source is
`.research/fixtures/TASK-260721-3miqh4_dns-runtime-policy-v1.json`.

| Field | Candidate default | Candidate hard ceiling |
| --- | ---: | ---: |
| Configured endpoints | 4 | 8 |
| DNS message bytes | 65,535 | 65,535 |
| In-flight owners | 16 | 32 |
| Queued wire bytes | 262,144 | 1,048,576 |
| Aggregate DNS bytes | 4,194,304 | 8,388,608 |
| Channel-open timeout | 2,000 ms | 5,000 ms |
| Complete-response timeout | 5,000 ms | 10,000 ms |
| Relay/UDP phase timeout | 5,000 ms | 10,000 ms |
| Dispatch allowance | 1,000 ms | 2,000 ms |
| Logical-query timeout | 35,000 ms | 135,000 ms |
| Startup-readiness timeout | 10,000 ms | 45,000 ms |
| Reusable-idle close | 10,000 ms | 30,000 ms |

These values remain injectable candidates. They must not be copied into
production composition or stored in the user profile.

## Compact validation rerun

Commands run from the repository root:

```bash
python3 -m py_compile scripts/dns-policy-evidence.py
python3 scripts/dns-policy-evidence.py --self-test-only
python3 scripts/dns-policy-evidence.py \
  --verify-policy .research/fixtures/TASK-260721-3miqh4_dns-runtime-policy-v1.json
cmp -s scripts/dns-policy-evidence.py \
  .task-board/.resources/TASK-260721-3miqh4/TASK-260721-3miqh4_dns-policy-evidence.py
cmp -s .research/fixtures/TASK-260721-3miqh4_dns-runtime-policy-v1.json \
  .task-board/.resources/TASK-260721-3miqh4/TASK-260721-3miqh4_dns-runtime-policy-v1.json
cmp -s .research/raw/TASK-260721-3miqh4_measurement-summary.json \
  .task-board/.resources/TASK-260721-3miqh4/TASK-260721-3miqh4_measurement-summary.json
cmp -s .research/260721_task-260721-3miqh4-dns-runtime-policy-v1.md \
  .task-board/.resources/TASK-260721-3miqh4/TASK-260721-3miqh4_research.md
git diff --check
task-board validate
```

A read-only Python consistency/privacy scan additionally:

- reproduced all nine recorded raw SHA-256 hashes;
- asserted three fixture runs, three default plus three hard memory trials,
  zero cleanup ownership, zero resolver-sentinel calls, and
  `productionAuthorization=false` in both policy and summary;
- scanned 53 task/versionable files and all 30 evidence-archive members for
  absolute user paths, current hostname/account markers, UUIDs, private-key
  markers, token-like values, and provisioning/serial identifiers.

Results after `BUG-260721-17f093`: 35/35 self-tests passed; canonical policy comparisons passed; all copy comparisons
passed; 9/9 raw hashes reproduced; board and diff validation passed; privacy
scan passed. No automatic raw spawn log is part of this handoff outcome.

## Remaining accountable blockers

1. `TASK-260715-1gjxer` — Record M0 SSH engine selection — must publish an
   accepted engine decision and controlled selected-engine `direct-tcpip`
   channel-open, response, concurrent-failure, cancellation, retry-batch,
   idle-close, buffer/window, and cleanup evidence.
2. `TASK-260715-1pn983` — Record memory, window, and rekey contract — must
   publish the accepted ADR-009 whole-extension ledger and assign the residual
   DNS component budget after HEV, SSH, relay, cache, diagnostics, rekey, and
   reconnect overlap.
3. Physical baseline-provider startup and footprint rows must later validate
   the selected policy on the baseline Mac and physical iPhone. This is a
   physical evidence gate, not a value to infer from the disposable local
   harness. `TASK-260715-2kchi0` may supply the measurement protocol but does
   not itself authorize the values.

Until those inputs are accepted and independently reviewed, ADR-022 cannot
advance to Accepted and downstream production consumers remain gated.

## References

- `.research/260721_task-260721-3miqh4-dns-runtime-policy-v1.md`
- `.research/fixtures/TASK-260721-3miqh4_dns-runtime-policy-v1.json`
- `.research/raw/TASK-260721-3miqh4_measurement-summary.json`
- `scripts/dns-policy-evidence.py`
- `TASK-260721-3miqh4_review-verdict.md`
- `TASK-260721-3miqh4_rework-01.md`
