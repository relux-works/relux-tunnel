## Status
done

## Assigned To
[reviewer] reviewer (claude)

## Created
2026-07-20T06:34:55Z

## Last Update
2026-07-20T07:22:16Z

## Blocked By
- TASK-260715-28ok1k
- TASK-260715-1g9cyt

## Blocks
- TASK-260715-1ozsb6
- TASK-260720-2sltje

## Checklist
- [x] Public client-rekey exported over existing ssh2_kex_exchange (no private-symbol import)
- [x] Deterministic test proves client rekey completes; server rekey preserved
- [x] Minimal allowlisted patch + rebuilt XCFramework, notices preserved
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
spawn queued: [implementer] developer (codex) (run=RUN-260720-16e636, max_parallel=1)
spawn run started: [implementer] developer (codex) (run=RUN-260720-16e636)
Implemented one two-file public client-rekey patch and checksum-first XCFramework builder. Public-header-only integration test observes real client/server NEWKEYS and post-rekey channels. Deterministic rebuild lock, source-tamper gate, notices, native gates, lint, 62 core tests, and swift build pass. See TASK-260720-3vwls7_results.md and attached logs.
agent completed: [implementer] developer (codex) (exit=0)
spawn run completed: codex (run=RUN-260720-16e636, pid=69377, exit=0)
spawn queued: [reviewer] reviewer (claude) (run=RUN-260720-7190e3, max_parallel=1)
spawn run started: [reviewer] reviewer (claude) (run=RUN-260720-7190e3)
REVIEW ACCEPTED. Independently re-ran all gates live: make check-libssh2 (patch manifest, artifact lock, public symbol nm, header allowlist, no libssh2_priv.h leak, notices hash) PASS; make test-libssh2-source-gates (tampered libssh2/OpenSSL archives fail closed BEFORE extraction/patching) PASS; make test-libssh2 (deterministic sshd rekey test: client rekey completed after 3 EAGAINs, sshd DEBUG3 log proves client-initiated KEXINIT first + RekeyLimit server rekey, NEWKEYS installed both directions twice, post-rekey channels OK) PASS; make validate-core (boundary check, 62 tests incl. ReluxLibSSH2PackagingTests, swift build) PASS; swift format lint --strict clean. Patch verified minimal: exactly 2 allowlisted files, wrapper reuses upstream server-rekey call pattern packet.c:1369 ssh2_kex_exchange(session,1,&session->startup_key_state) — no invented semantics, no crypto changes. Reproducibility confirmed: two rebuild artifact locks byte-identical. Docs (RELUX_DELTA/UPSTREAM/PATCH_MANIFEST/README/native-dependency-packaging) and notices (BSD-3-Clause + Apache-2.0 + acknowledgements) in place. All 5 ACs met. Verdict: done.
agent completed: [reviewer] reviewer (claude) (exit=0)
spawn run completed: claude (run=RUN-260720-7190e3, pid=15742, exit=0)

## Precondition Resources
- [TASK-260720-3vwls7_inputs.md](file://TASK-260720-3vwls7/TASK-260720-3vwls7_inputs.md) — libssh2 client-rekey fork requirements

## Outcome Resources
- [TASK-260720-3vwls7_spawn-log_-implementer--developer--codex-.log](file://TASK-260720-3vwls7/TASK-260720-3vwls7_spawn-log_-implementer--developer--codex-.log) — System spawn log captured by task-board
- [TASK-260720-3vwls7_results.md](file://TASK-260720-3vwls7/TASK-260720-3vwls7_results.md) — Implementation and verification summary
- [TASK-260720-3vwls7_validate-core.log](file://TASK-260720-3vwls7/TASK-260720-3vwls7_validate-core.log) — Core boundary, 62-test, and Swift build validation log
- [TASK-260720-3vwls7_artifact-lock.json](file://TASK-260720-3vwls7/TASK-260720-3vwls7_artifact-lock.json) — Checksum lock for the reproducibly rebuilt static XCFramework
- [TASK-260720-3vwls7_spawn-log_-reviewer--reviewer--claude-.log](file://TASK-260720-3vwls7/TASK-260720-3vwls7_spawn-log_-reviewer--reviewer--claude-.log) — System spawn log captured by task-board
