# TASK-260715-ypo7yo — r12 handoff evidence

Reviewer verdict 10 (F1, changes requested) is closed. Revision **2026-07-28.r12**.
Ready for review.

## The finding, re-verified before it was accepted

Reproduced against the *unmodified* r11 artifact: `X1-C1.reviewedIn` moved from
`2026-07-28.r10` to `2026-07-28.r2` — a revision predating the conditional register
entirely — and `validate-matrix.py` printed `PASS — every rule holds` over 2805 checks and
exited **0**, where a negative control must exit 1. **CONFIRMED.**

The class was then swept across **both** of rule X1's registers rather than patched on the
entry the verdict named, and the ACTIVE register turned out to be worse: `R26` required
`reviewedExceptions[].reviewedIn` to be *non-empty and nothing else*, so it accepted
`2026-07-28.r99`, a revision this contract has never issued — the exact case the conditional
register had rejected since r11. That register is the one whose entry authorises an
exception that **is** present in a signed bundle. No verdict had reported it.

## What changed

New rule **X1-P** (`exceptionEntitlementRule.exceptionReviewProvenance`) derives the
revision each register entry first entered this contract in, from evidence older than the
claim:

- **snapshot-proven** — the per-revision baselines attached to this task, pinned by a
  content digest. `X1-C1` is absent from `r8` and `r9` and present in `r10`, so its
  introducing revision is computed from files no edit to the contract can reach.
- **summary-attested** — the fallback for an entry older than the oldest baseline: the
  oldest `revisionLog` summary naming the exception key verbatim. `X1-A1` → `r3`. The gate
  **refuses** this class wherever the chain can decide.
- both cross-checked against `revisionLog[].introduces`, a new per-revision record.

The chain cannot be tampered with (digests, declared revision) or narrowed (contiguous to
`supersedes`, no undeclared baseline left on disk). `known-revision` is **removed** from the
implemented bound vocabulary, so r11's bound cannot return as a declaration. Verdict 10's
control now fails under **R39**, as required; the active register's under **R26**.

Rework items: 1 ✔ (derived, from a pinned chain), 2 ✔ (`reviewedIn` r10→r2 and r10→r3
negative mutations, both exit 1 naming R39), 3 ✔ (derivation prose, §4.5 *Stated bound*
paragraph, and the independent `reviewer-gates.sh` all rewritten — the script used to check
exactly what r11's gate checked, so the control passed there too), 4 ✔ (`preserve-r12.py`,
245 assertions).

## Gates — real exit codes, run in place from the board resource layout

| gate | result | exit |
| --- | --- | --- |
| `validate-matrix.py` | 2862 checks | 0 |
| `mutate.py` | 285/285 negative gates | 0 |
| `check-portal-consumer.py --repo .` | A1 28, P1 20, D1 41 | 0 |
| `preserve.py` r8→r9 | 122 assertions | 0 |
| `preserve-r10.py` r9→r10 | 201 assertions | 0 |
| `preserve-r11.py` r10→r11 | 143 assertions | 0 |
| `preserve-r12.py` r11→r12 | 245 assertions | 0 |
| `reviewer-gates.sh` | gates plus 8 negative controls hold | 0 |
| `scripts/check-legacy-preservation.sh` | legacy identity preserved | 0 |
| `task-board validate` | no issues | 0 |
| `swift test` | 335 tests, 29 suites — 21 of 24 runs | 0 |

Verdict 10's own control, replayed against r12: `R39` exit **1**, naming the derived
revision. The four verdict-09 controls still hold.

## Board changes

- `TASK-260728-q5kjta` scope re-pointed `r11 → r12` (rule A1 / `amendmentRule`; the
  verdict-06 discipline). The revision label is the **only** edit — the authorized mutation
  set is byte-for-byte what it was, which `check-portal-consumer.py` verifies.
- Board-wide sweep for a stale matrix revision label found exactly that one live record.

## Reported, not actioned

`swift test` flakes on this tree, unrelated to r12: 3 failures in 24 full runs, all
`snapshot.activeConnections → 1) == 0` in `HEVUDPDatagramAdapterTests` at :646 (×2) and
:333 (×1). Both read `await adapter.snapshot()` immediately after `receiveEOF` returns while
the adapter decrements the counter in its own task. `git status` over `Sources`, `Tests`,
`Package.swift`, `Protocol`, `relay`, `scripts` and `.spec` was empty for the entire
session — r12 touches board resources only. Raised as **BUG-260728-2j25tu** under
`STORY-260715-1nsw9p` rather than fixed here.

A duplicated `r7's gates:` heading in §9.2 of the rationale document was removed — a typo
in this task's own artifact, noted so it is not mistaken for a content change.

No entitlement decision, identifier, target row, profile row, record, assertion, assertion
scope, open constraint, dependency edge or Ceremony C1 mutation set changed. No product
source, spec or generated project was modified. No board element was created beyond the
bug above, and none was deleted or re-parented.
