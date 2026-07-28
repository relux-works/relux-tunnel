# Independent review verdict — round 2

Review date: 2026-07-28.

Verdict: **CHANGES REQUESTED**. Route to `analysis` because the remaining
defects are in canonical planning, dependency semantics, and the generated
critical-path evidence. No tunnel implementation rework is requested.

## Gates that passed

- `task-board validate`: exit 0, board valid with no issues.
- `swift test`: exit 0, 332 tests in 29 suites passed.
- `git diff --check`: exit 0.
- Product-path status scan over `Sources`, `Tests`, `Protocol`, `relay`,
  `scripts`, `config`, `Package.swift`, and `Makefile`: exit 0 with empty
  output.
- Primary goal ledger is active and records libssh2-primary, macOS-first,
  iOS/A0/Linux deferral, and the retained security/release gates.
- `TASK-260715-1ozsb6` remains blocked by unfinished
  `TASK-260728-yx2fca`; `TASK-260728-3cveay` remains blocked by
  `TASK-260715-1gjxer`, `TASK-260715-3kimon`, and
  `TASK-260728-yx2fca`.
- NIOSSH, A0, and iOS branch roots sampled in review are explicitly `blocked`
  with retained evidence.
- Notary custody ordering is present:
  `TASK-260728-dveo1o` blocks `TASK-260715-3gkwn0`.
- Sparkle generation/integration ordering is present:
  `TASK-260728-3bj9bk` is blocked by `TASK-260717-ziprhs`,
  `TASK-260717-xempiv`, and `TASK-260717-1mt4e7`, and blocks publication and
  integrity tests.

## Required rework

1. **Make C1 one real up-front permission sitting in the live graph.** The
   generated plan has `HUMAN C1/D1`, then autonomous task completion and review,
   then a second `HUMAN C1`. Specifically, the first stop is at serial-plan
   lines 160–164, autonomous segment 2 is lines 166–171, and the second human
   C1 stop is lines 173–176. This repeats the defect the mandatory review focus
   required fixing. Reconcile the board dependencies/ceremony ownership so all
   up-front grants can occur in one sitting without waiting through a
   producer-reviewer cycle. Keep A1 as the separate later system-VPN approval.

2. **Do not schedule provider evidence before P0 exists.**
   `TASK-260715-1u2vpc` is in pre-C1 autonomous segment 1/W4, and its live scope
   still requires a Gate-P0 provider smoke on the physical Apple-silicon Mac.
   The task is no longer blocked by `TASK-260715-2ayxqn`, so the generated plan
   claims work is runnable before C1, the disposable provider, A1, and the P0
   disposition exist. Restore the P0 dependency, or split/re-scope the early
   matrix to harness-only evidence and keep the real provider row enforced by a
   correctly ordered physical-provider task. Regenerate the waves afterward.

3. **Make the zero-input claim evidence-based.** Segment 1 is labeled
   “runnable NOW, zero human input”, but `TASK-260715-39xz9g` requires access to
   a real Relux test host and the plan itself says that access is not evidenced
   (conditional hold X1). Either verify privacy-safe readiness, make the segment
   explicitly conditional, or introduce an honest hold. Do not count an
   unevidenced credential/access precondition as autonomous.

4. **Reconcile remaining canonical contradictions.**
   `.spec/architecture.md:121` still says Gate A0 must precede product
   implementation beyond a disposable spike, directly contradicting ADR-013
   and the macOS prototype path. `.spec/delivery.md:70` and
   `.spec/delivery.md:75` still make iOS/TestFlight and App Review completion
   part of M4 even though the same document defers them after the macOS path.
   `.spec/platform-distribution.md:48` still states that the baseline MUST use a
   physical iPhone without a goal-scope deferral qualifier. Preserve future iOS
   requirements, but make their deferred status unambiguous in every canonical
   statement that otherwise gates this goal.

5. **Audit the complete dependency delta, not only the second-round subset.**
   A diff-derived unique-edge scan found 75 removed links in the task's current
   board diff: 38 task-to-task links and 37 container/cross-container links.
   The current results report and justify only 17 removed edges as the board
   delta. Add a complete task-scoped edge ledger covering every removal, with
   the reason, the retained counterpart/gate where applicable, and the relevant
   invariant. This must explicitly cover cycle repair, unsupported container
   links, A0, iOS, Linux, NIOSSH, Sparkle, P0, and every safety/release edge.
   The omitted `TASK-260715-2ayxqn` → `TASK-260715-1u2vpc` removal demonstrates
   why the complete audit is necessary.

6. **Correct autonomy labels and counts.** The wave artifact lists human-owned
   task nodes under `HUMAN` headings and then counts the same nodes inside
   “Autonomous segment” waves (for example `intsjz`, `dveo1o`, `2gwfaw`,
   `35nc5m`, `3f4rhy`, `3mnqn8`, and `3gkwn0`). Distinguish human input,
   agent-side evidence/review work after that input, and genuinely autonomous
   tasks. Regenerate the totals and the longest safe serial path from the
   corrected live DAG.

Mechanical validity remains green, and the notary/Sparkle/M3 contract repairs
are materially improved. Acceptance is withheld because the current plan still
requires two C1 stops, schedules a known pre-P0 provider row too early, and
overstates autonomous readiness while the canonical specs and full edge audit
remain inconsistent.
