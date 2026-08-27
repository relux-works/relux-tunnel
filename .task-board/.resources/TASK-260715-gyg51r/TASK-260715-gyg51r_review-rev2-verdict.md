# TASK-260715-gyg51r — revision 2 independent review verdict

## Verdict

Changes requested. Route `TASK-260715-gyg51r` to `to-dev`; do not accept `CR-TASK-260715-gyg51r-2` revision 2.

The 36-row matrix, pressure accounting, owned-descriptor ledger, task-unavailable field, derived logical batch field, tests, coverage, lint, and safety scans reproduce. Output containment remains bypassable at the production entry point, so the prior high-severity finding is not closed.

## F1 — High: resolved output containment has a post-parse symlink-swap bypass

Production call site: `MTUMatrixHarnessCommand.run(context:)` parses and resolves the output at `MTUMatrixCommand.swift:53-104`, then runs all 36 socket rows, creates the parent, and writes with Foundation at `MTUMatrixCommand.swift:293-297`. The resolved path is not bound to a no-follow directory descriptor and is not safely re-established at write time.

Independent negative probe through the built production executable:

1. Configured `.temp/TASK-260715-gyg51r/review-rev2-race/parent/race.json` with a real parent directory.
2. Started `.build/debug/ReluxTunnelHarness mtu-matrix --configuration .temp/TASK-260715-gyg51r/review-rev2-race-config.json` and kept the shell attached until the process terminated.
3. After parse, while the 36 rows ran, renamed the real parent and replaced it with a symlink to `/Users/Shared/TASK-260715-gyg51r-review-rev2-race`.
4. The command exited `0` and created `/Users/Shared/TASK-260715-gyg51r-review-rev2-race/race.json`, outside both authorized `.temp` and `/tmp` roots.
5. All probe files, the symlink, and both task-scoped directories were removed after observation.

A second production-CLI probe also confirmed that a lexical project `.temp` path symlinked to `/tmp` is accepted and written outside the project task subtree (`COMMAND_EXIT=0`, `EXTERNAL_WRITTEN=yes`). The new test at `HarnessTests.swift:317-346` covers an already-present symlink resolving outside both allowed roots, but not the exact cross-root prior exploit or the post-parse swap. Positive containment evidence therefore does not prove the gate.

Required rework: anchor creation and the atomic write to a validated directory descriptor with no-follow traversal (or an equivalently race-safe mechanism); a preflight `resolvingSymlinksInPath()` check alone is insufficient. Preserve direct `/tmp` support only if intended, but require a lexical project `.temp` path to remain in that root after resolution. Add production-entry negative tests for both `.temp -> /tmp` cross-root escape and post-parse parent replacement, asserting nonzero exit and no external file.

## Independent matrix and validation

- Production matrix: exit `0`; physical Apple M3 Max (`Mac15,9`), arm64, macOS 26.5 build 25F71; 36 unique rows from MTU `1500/4096/8500` × `ipv4/ipv6/dual-stack` × four pressure modes, 512 attempts per row.
- Raw review matrix: `TASK-260715-gyg51r_review-rev2-raw-matrix.json`, SHA-256 `6abd0797b855f5b0ce8e5de0deff0012667a230b8b08ddb68d905bd143593729`.
- Matrix invariants: nominal/mixed drops `0`; 18/18 pressure rows had nonzero but non-total loss; accounting, reason, recovery, owned-descriptor, task-honesty, and `logicalBatchGroups == ceil(sent/32)` violations all `0`.
- Requested/effective buffer pairs reproduced exactly at `4096`, `32768`, and `262144` bytes. Native IPv6 ran; NAT64 and energy are explicitly unavailable; iPhone remains ADR-024 `deferred-unavailable`.
- Focused tests with coverage: 25 tests, exit `0`. Affected file coverage: 87.10% regions, 88.17% functions, 96.14% lines.
- Full suite: 474 tests in 40 suites, exit `0`, with 25 declared known ReluxNIOSSH-unavailable issues. The first shell call ended without a terminal exit at its 30-second yield; the preserved session was polled to the real exit `0` and is the result reported here.
- `swift format lint` on all affected Swift files: exit `0`; `git diff --check`: exit `0`.
- Candidate worktree paths match candidate tree `75d5f42ce8bb35059a86a8983a06420ef5ebff4b`. CR patch SHA-256 matches `7a3a067ddf9d4c657808130bb44f5005b288a108bc8b37bdef98d15a7be50bbb`.
- Source safety scan found only numeric IPv4 loopback and `in6addr_loopback` socket bindings; no NetworkExtension/VPN/route/DNS/interface/filter/SSH/Keychain action is present. Raw privacy sentinel scan was clean.
- `task-board validate`: exit `0` before verdict routing.

## Additional anomaly

One independent 64-packet production run was correctly rejected because `dual-stack-mtu1500-receiver-stall` induced no drop. This is not the verdict cause, but the advertised `64...2048` range does not guarantee a successful matrix at its lower bound and should be documented or made deterministic during rework.
