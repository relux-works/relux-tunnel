# TASK-260715-12zaq5 recovery 01 — contract precedence

The prior run was cancelled before handoff because it did not consume the durable correction and incorrectly treated a newly attached precondition as authority to supersede an independently reviewed accepted contract.

Preserve the useful host-policy, libssh2 ordering, and test work already in the worktree, but make this focused correction before any handoff:

1. Restore `SSHProfileSnapshotV1` validation to the accepted invariant: at most one active `.approved` identity record. Do not weaken the accepted loader contract.
2. Remove simultaneous-multiple-approved fixtures and claims. Model deterministic sequential rotation with canonically ordered historical/revoked records and one current active approved identity in a complete new snapshot generation.
3. Remove the `CONTRACT PRECEDENCE` claim from LOGBOOK/evidence and state that `TASK-260715-29ws8l` remains authoritative.
4. Preserve all task-scoped security behavior: exact match only, first-use evidence without authentication, revoked/changed/unsupported/malformed/host-mismatch fail closed, raw key bytes contained, and zero credential/auth/channel activity before approval.
5. Run focused loader and host-policy/order regressions first, then the required full gates. Record unrelated HEV flakes honestly but do not modify HEV in this task.

Hand off to review only after the corrected scope and board AC both match the accepted contract.
