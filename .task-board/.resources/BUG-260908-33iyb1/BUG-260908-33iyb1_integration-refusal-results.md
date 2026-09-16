# Integration refusal — BUG-260908-33iyb1

Bound integration of accepted CR revision 2 was attempted from /Users/iv/Developer/relux-tunnel using the curator-installed task-board.

Command: task-board worktree integrate STORY-260908-h39ajh --cr BUG-260908-33iyb1 --revision 2 --commit-time (current UTC RFC3339).
Exit code: 1.
Typed refusal: integration_base_moved: the local integration checkout is not at the freshly observed protected authority OID.
head_oid: 87451b53960ceabe88a01c44c287fee7f9ebf386
protected_oid: b3422b05226253a17676b9b84c764071fe3dbe74
protected_ref: refs/heads/main

Transaction inspection: task-board worktree transaction show STORY-260908-h39ajh exited 0 and reported No integration transaction is recorded for STORY-260908-h39ajh.
Post-refusal refs: root HEAD and local main remain 87451b53960ceabe88a01c44c287fee7f9ebf386; origin/main remains b3422b05226253a17676b9b84c764071fe3dbe74; Story branch remains dc68c1584f7cc4ddcdf770acd8ace79790f0b404.
Task status confirmed integrating. No manual status transition or generic handoff was performed.

Accepted candidate from assignment: d6c873383db09c59cf5d6d437e0767615e5ae704, reviewer RUN-260908-353271. This run did not rerun behavioral tests, mutants or macOS builds: integration was refused before validation. No new AC coverage or hosted green claim is made; prior immutable review evidence is unchanged.

No repository code edits, manual commits, resets, integration bypass, publication, remote main advancement, tool edits, VPN operations or successors were performed. Existing pending PR6 commits and sibling checkpoint are preserved.

Evidence logs at control root:
.temp/BUG-260908-33iyb1-integrate-01.log
.temp/BUG-260908-33iyb1-transaction-01.log

Parent routing required per explicit delivery instruction: resolve delivery ordering/authority mismatch while preserving pending signed PR6. A permitted parent-owned PR6 landing could align authority after actual review/check gates, then the bound integration can be retried; this run is not authorized to land remote main. Do not rewind local main to bypass the refusal. No transaction exists to resume or roll back. Original hosted root-cause repair and green requirement remain BUG-260908-shki8p; not fixed by this run.
