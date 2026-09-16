# TASK-260715-1pn983 review verdict — Change Request revision 2

Verdict: **accepted**.

Reviewed candidate: base `b3422b05226253a17676b9b84c764071fe3dbe74`,
candidate tree `fc4cf7e50c4221458822ca6eb82b1fad5b879f5f`, CR
`CR-TASK-260715-1pn983-2` revision 2. The supplied patch digest matched
`33145337f2c40411f0389af2a0863b7fa9f43626fa56b8995270bef922543b6c`.

## Findings

No blocking findings remain. Revision 2 closes all five revision-1 findings:

1. `B_untracked` is a permanent charged ledger row included exactly once in
   every headroom/admission path, with a narrowed negative-test obligation.
2. Total-capacity reservation and candidate charge delta are separately and
   consistently defined; KEX and reconnect inclusion is explicit.
3. Lane admission is a closed serialized predicate covering count, base, KEX,
   mandatory lane-A slices, ledger headroom, lifecycle/health/pressure, typed
   refusal, and cleanup without a side queue.
4. Reconnect ownership and permanent per-lane KEX reservation are orthogonal;
   KEX idle and active retain the same reservation.
5. The packet-plane target is the named Apple-silicon Mac; iPhone evidence is
   explicitly deferred and non-substitutable.

The binding text resolves pressure-entry overlap by choosing maximum severity
per observation and permits recovery by at most one state per evaluation, so
the state contract remains deterministic despite the diagram showing all
applicable severity edges.

## Acceptance and architecture review

- AC1: the task-scoped ledger covers packet, HEV, SSH, DNS, client/remote relay,
  lane, rekey, reconnect, metrics, and untracked process ownership with units,
  hard-ceiling fields, current/peak inputs, lifetimes, releases, and safe
  observability.
- AC2: 32 KiB, 64 KiB, capped-BDP, relay, channel-credit, and residual-DNS
  formulas are bounded under one global ledger without claiming eager SSH
  allocation. DNS recomputed to `3,686,706 B` and `7,635,554 B`; the hard
  candidate leaves `753,054 B` DNS slack and `8,110,080 B` after the accepted
  HEV/bridge input inside the lower engineering envelope.
- AC3: Soft, Pressure, and Critical use maximum-severity entry, one-step exit,
  hysteresis, dwell, acknowledgements, one 11-row cumulative action order, and
  typed stale/unavailable advisory behavior; no cached advisory value exists.
- AC4: channel/lane admission, `WINDOW_ADJUST` withholding, bounded reduction,
  refusal, old-release-before-critical-replacement, stop, rekey, cancellation,
  stale callbacks, and no-side-queue semantics are explicit.
- AC5: privacy-safe fixed-cardinality metrics, two task-scoped state diagrams,
  production-entry negative tests, and M0–M3 owner traceability are present.

The eight direct Story children match the eight atomic deliverables named by
the contract, and the board carries the required dependency links. The gap
record names each beyond-literal binding, its source gap, and out-of-scope
checks. No new research element is justified because final numeric selection
already belongs to existing tuning and physical-evidence tasks.

## Independent evidence

- All ten working-tree blobs match candidate-tree blob OIDs; `git diff --check`
  passed, exit 0.
- Both input SHA-256 digests and the CR patch digest matched exactly, exit 0.
- Fresh PlantUML `-checkonly`, SVG render/byte comparison, and original-resolution
  PNG visual inspection passed, exit 0.
- Formula, revision-1 counterexample closure, ordered-action, consumer-family,
  task-trace, resource-byte, and checklist/dependency checks passed, exit 0.
- Two reviewer harness attempts correctly failed, exit 1, because assertions
  targeted a Markdown-wrapped phrase and then the wrong artifact; the corrected
  source-scoped harness passed, exit 0. Red logs are retained rather than
  represented as successful evidence.
- `task-board validate` exited 0 while reporting three parent-status anomalies.
  The current Story mismatch reflects this reviewer child being in `reviewing`;
  the other two Stories are outside this task. None is evidence of an AC defect,
  and no foreign state was changed.
- No production build/runtime suite was rerun: this candidate changes only
  specifications, documentation, and diagrams. Task-scoped formula, syntax,
  rendering, artifact-integrity, and board gates are the relevant checks.

Validation logs:
`TASK-260715-1pn983_review-validation-rev2-01.log` (red, exit 1),
`TASK-260715-1pn983_review-validation-rev2-02.log` (red, exit 1), and
`TASK-260715-1pn983_review-validation-rev2-03.log` (green, exit 0).

Accepted handoff is recorded with `accept_cr`; the reviewer supplies no
`commit_ack`. The orchestrator owns checkpoint/integration and final `done`.
