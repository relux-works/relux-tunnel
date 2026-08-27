# Revision 3 independent review verdict

## Verdict

Changes requested. Do not accept CR-TASK-260715-gyg51r-3 revision 3. Route to focused rework.

## High finding: ancestor-directory swap still escapes containment

Independent reviewer RUN-260826-436586 attacked the built production CLI after parse by renaming an ancestor project directory and replacing it with a symlink. Revision 3 applies O_NOFOLLOW only when opening the final .temp/root component relative to a path-opened project directory, so traversal can already have crossed a symlinked ancestor. The command exited 0 and created an external matrix.json. The reviewer removed the task-scoped external file immediately. Exact command, source lines, candidate tree 6e06c24d993fb174182e9492718beb818181c555, and output are preserved in TASK-260715-gyg51r_spawn-log_-reviewer--reviewer--codex-_RUN-260826-436586.log.

Required rework: anchor traversal from a trusted directory descriptor opened before the attack surface (or perform no-follow openat traversal from filesystem root for every lexical component), and retain every directory FD through the atomic write. Add a production-entry regression that swaps an ancestor above .temp, not only the output parent or .temp itself. Assert nonzero exit and no external file.

## Accepted revision-3 evidence retained

The same independent reviewer verified both prior exploit variants were closed, a fresh 36-row matrix passed all invariants, the 64-packet floor passed 3/3 production runs, focused coverage passed, format/diff/privacy/safety scans were clean, and the candidate tree/hash matched CR revision 3. One unrelated ClientUDPAssociationRegistry concurrency cleanup flake appeared in a full-suite run and passed isolated rerun; it is not the verdict cause. The ancestor escape alone blocks acceptance.

This resource preserves the completed reviewer finding after the provider exited nonzero before its normal board handoff; no new review judgment is introduced by the orchestrator.