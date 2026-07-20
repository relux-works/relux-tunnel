## Status
done

## Assigned To
[reviewer] reviewer (claude)

## Created
2026-07-20T07:21:54Z

## Last Update
2026-07-20T08:02:24Z

## Blocked By
- TASK-260720-3vwls7
- TASK-260715-1g9cyt

## Blocks
- TASK-260715-1ozsb6

## Checklist
- [x] Public server-KEX observation (start/success/failure + generation) tested
- [x] Public reply-correlated keepalive/global-request with RTT + timeout tested
- [x] Minimal allowlisted patch, rebuilt XCFramework, notices preserved
- [x] Code written per task description and AC
- [x] Relevant tests written for new or changed behavior and passing
- [x] Lint clean
- [x] Relevant build/validation commands run after changes and build not broken
- [x] New outcome artifact attached on the board with a task-scoped name when the work produces notes, logs, screenshots, or other deliverables
- [x] Important findings, decisions, anomalies, or regressions recorded in logbook when relevant
- [x] Implementation matches AC
- [x] Solution fits project architecture
- [x] Tests green
- [ ] If review does not accept the work — verdict evidence added and status routed by the explicit verdict branches

## Notes
spawn queued: [implementer] developer (codex) (run=RUN-260720-3fe7fd, max_parallel=1)
spawn run started: [implementer] developer (codex) (run=RUN-260720-3fe7fd)
Implemented one six-file allowlisted libssh2 patch with typed server-KEX observation and a bounded reply-correlated global-request API. Timed-out requests deliberately retain correlation until the late reply is drained. Two rebuild locks match; fork, source-tamper, static/extension-safe, C warning, Swift format, 64-test core, and swift build gates pass. Broader validate-native stops before Xcode builds on the pre-existing HEV macOS 10.14/11.0 minimum mismatch; task-specific static inspection and required validate-core pass.
agent completed: [implementer] developer (codex) (exit=0)
spawn run completed: codex (run=RUN-260720-3fe7fd, pid=28640, exit=0)
spawn queued: [reviewer] reviewer (claude) (run=RUN-260720-1309c4, max_parallel=1)
spawn run started: [reviewer] reviewer (claude) (run=RUN-260720-1309c4)
REVIEW ACCEPTED. Reviewer independently re-ran make check-libssh2, make test-libssh2 (live sshd: RTT=33ms, 1 deterministic timeout/miss, 14 server-KEX transitions incl. deliberate failure), make validate-core (64 tests + swift build), and swift format lint — all green. Verified hook placement against pristine pinned source: packet.c hook fires only for server-initiated KEXINIT; kex.c completion hook unreachable on EAGAIN and correct on both early-failure returns. Patch is observation-only (222 insertions, 6 allowlisted files), manifests/delta/notices updated, byte-identical rebuild locks, priv header excluded. Non-blocking notes in TASK-260720-2sltje_review.md, incl. adapter caveat: never mix builtin want-reply keepalive with libssh2_session_global_request (unnumbered SSH global replies). Pre-existing HEV matrix issue tracked as BUG-260720-2zh86a.
agent completed: [reviewer] reviewer (claude) (exit=0)
spawn run completed: claude (run=RUN-260720-1309c4, pid=27105, exit=0)

## Precondition Resources
- [TASK-260720-2sltje_inputs.md](file://TASK-260720-2sltje/TASK-260720-2sltje_inputs.md) — libssh2 observation-hooks fork requirements

## Outcome Resources
- [TASK-260720-2sltje_spawn-log_-implementer--developer--codex-.log](file://TASK-260720-2sltje/TASK-260720-2sltje_spawn-log_-implementer--developer--codex-.log) — System spawn log captured by task-board
- [TASK-260720-2sltje_results.md](file://TASK-260720-2sltje/TASK-260720-2sltje_results.md) — Implementation and verification summary
- [TASK-260720-2sltje_validate-libssh2.log](file://TASK-260720-2sltje/TASK-260720-2sltje_validate-libssh2.log) — Fork verification and live OpenSSH integration test
- [TASK-260720-2sltje_validate-core.log](file://TASK-260720-2sltje/TASK-260720-2sltje_validate-core.log) — Core boundary, Swift test, and Swift build validation
- [TASK-260720-2sltje_reproducibility.log](file://TASK-260720-2sltje/TASK-260720-2sltje_reproducibility.log) — Byte-identical XCFramework rebuild-lock comparison
- [TASK-260720-2sltje_validate-native.log](file://TASK-260720-2sltje/TASK-260720-2sltje_validate-native.log) — Broader native gate attempt showing unrelated HEV preflight mismatch
- [TASK-260720-2sltje_spawn-log_-reviewer--reviewer--claude-.log](file://TASK-260720-2sltje/TASK-260720-2sltje_spawn-log_-reviewer--reviewer--claude-.log) — System spawn log captured by task-board
- [TASK-260720-2sltje_review.md](file://TASK-260720-2sltje/TASK-260720-2sltje_review.md) — Reviewer verdict with independent gate re-runs and source-level hook verification
