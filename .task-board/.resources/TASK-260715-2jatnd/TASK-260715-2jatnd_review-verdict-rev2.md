# TASK-260715-2jatnd review verdict — CR revision 2

Verdict: ACCEPTED. Record acceptance with `accept_cr` and park the task at
`to-review` for orchestrator-owned checkpoint/integration. The reviewer supplies
no `commit_ack`.

## Scope and exact candidate

- Change Request: `CR-TASK-260715-2jatnd-2`, revision 2.
- Base OID: `489c924a16e775d8012db806717815e4e7eb92ad`.
- Candidate tree OID: `d834a004e9f062e899ddcbc2aab6b797afb32bc3`.
- The independently generated five-path base-to-candidate diff is byte-identical
  to `TASK-260715-2jatnd_change-request_rev2.patch`; both SHA-256 values are
  `0faf64a76c31813128ce22533ca652267880766cc28c5b5bf80e2593364a8c0d`.
- The repository ADR is byte-identical to the attached task-scoped ADR outcome.
- `git diff --check` exited 0.

## Acceptance findings

1. All required M0 Bridge rows carry an explicit PASS, FAIL, BLOCKED, or
   BLOCKED/DEFERRED result and cite concrete board-owned evidence. An automated
   name audit found 23 cited resource names and zero missing declarations.
2. Revision-1 findings are resolved. The traceability table covers all 12 direct
   Story children, including the justified-gap record and out-of-scope checks for
   `BUG-260720-2zh86a`. The bounded-backpressure row preserves the original
   `TASK-260715-35wctc` red counter evidence and separately names the accepted
   `BUG-260720-2p4fln` resolution.
3. The selected baseline is evidence-backed: MTU 1500; requested 32768-byte
   send/receive buffers with effective-value readback; 64-packet/5-ms pump
   budgets; HEV task-stack/TCP/UDP-copy values 24576/4096/2; and an initial
   measured 500-session ceiling. The record keeps later physical tuning
   injectable and does not reuse 4096-byte fault-injection buffers as a normal
   baseline.
4. The raw physical MTU artifact contains 36 rows across IPv4, native IPv6, and
   dual stack. Independent review recomputation found zero nominal/mixed loss,
   zero send failures for MTU 1500 and 4096, and exactly 768 MTU-8500 send
   failures in the constrained-buffer family rows. Therefore 8500 remains a red
   default candidate and is not averaged with green rows.
5. Physical Mac memory evidence is limited correctly to incremental HEV/bridge
   cost. The worst accepted 500-session delta is 9,715,712 bytes; host available
   memory, HEV queued bytes, process-wide Swift task count, SSH/DNS/relay/cache/
   reconnect overlap, physical iPhone, and sleep/wake remain unavailable,
   unknown, or deferred rather than inferred from proxy signals.
6. Public API, IPv4/IPv6 framing, deterministic error/drop behavior, bounded
   backpressure, count/time yielding, hostile-frame fuzzing, lifecycle cleanup,
   packaging, pins, and notices trace to completed source tasks and independent
   accepted verdicts. Production bridge call sites are the platform
   `PacketFlowAdapterBoundary` implementations and `PacketFlowBridge.start`.
7. The unmodified HEV graph remains pinned. Fork authorization is rejected
   because no target Instruments bridge-copy/syscall bottleneck evidence and no
   measured improving callback prototype exist. The ADR states the full future
   evidence, regression, notice, upstreaming, and rebase requirements.
8. Physical iPhone, NAT64, sleep/wake, whole-extension memory, and global
   pressure ordering remain named deferred/blocked rows under ADR-024. Exact
   device/OS/toolchain/bridge/HEV/composition revalidation triggers are explicit.
   Downstream dependencies on this task are present for the five named M1/M3
   consumers; their other blockers remain intact.

## Reviewer validation and negative evidence

- Reviewer self-check over exact paths, ADR/resource bytes, patch hash, all 12
  trace rows, selected values, red/deferred statuses, links, and raw-matrix
  invariants: corrected run exit 0.
- The first wrapper invocation returned exit 1 only after every assertion had
  printed pass, because it attempted to assign zsh's read-only special variable
  `status`. The same assertions were rerun unchanged with a task-scoped variable
  and exited 0; both logs are preserved.
- Narrowing mutants changed MTU 8500 from FAIL to PASS, physical iPhone from
  BLOCKED/DEFERRED to PASS, and HEV fork authorization from FAIL/REJECTED to
  PASS/AUTHORIZED. Each mutant was rejected with checker exit 1; the baseline
  exited 0 and the aggregate negative-mutant gate exited 0.
- `task-board validate` returned process exit 0 but reported one
  `PARENT_STATUS_MISMATCH`: the Story remains `analysis` while this leaf is in
  `reviewing`. The Story is hard-blocked by `STORY-260715-l2i2oo`, and the board
  contract intentionally leaves blocked ancestors unchanged during child status
  aggregation. This is a board-state/validator anomaly created by the mandatory
  reviewer state, not a repository candidate defect; it is not represented as a
  clean validation result.
- Attached source-task Swift, TSan, fuzz, physical MTU, pressure, lifecycle,
  memory, packaging, and notice evidence was inspected and accepted as existing
  evidence. This documentation-only review did not rerun those source-task
  workloads and did not claim that it did.

No Network Extension VPN was run, installed, signed, enabled, configured, or
connected. No route, DNS, interface, packet filter, SSH session, global pressure,
staging, commit, rebase, merge, or branch switch was performed.
