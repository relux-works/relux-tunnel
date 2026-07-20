## Status
done

## Assigned To
[reviewer] reviewer (claude)

## Created
2026-07-20T05:38:50Z

## Last Update
2026-07-20T06:12:08Z

## Blocked By
- TASK-260715-nzdzv3
- TASK-260720-100wu6

## Blocks
- TASK-260715-1af33i

## Checklist
- [x] External async-signer offer works without private-key export (fork test)
- [x] Reply-observing keepalive/global-request round-trip works (fork test)
- [x] Caller KEX/host-key allowlist + negotiated-algorithm snapshot exposed and tested
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
spawn queued: [implementer] developer (codex) (run=RUN-260720-606de9, max_parallel=1)
spawn run started: [implementer] developer (codex) (run=RUN-260720-606de9)
Implemented all three fork hooks. Compatibility decision: expose the immutable negotiated snapshot without injecting a pre-auth user event, because such an event breaks existing first-event auth/banner handlers. Exact 20-file delta and verification evidence are attached. Ready for reviewer routing after producer handoff.
agent completed: [implementer] developer (codex) (exit=0)
spawn run completed: codex (run=RUN-260720-606de9, pid=17639, exit=0)
spawn queued: [reviewer] reviewer (claude) (run=RUN-260720-5d1be9, max_parallel=1)
spawn run started: [reviewer] reviewer (claude) (run=RUN-260720-5d1be9)
REVIEW ACCEPTED -> done. Independently re-ran all gates: fork-tool exact-delta verify (20-file allowlist, archive/license hashes match), 323 upstream XCTest + 13 fork Swift Testing cases pass, strict swift-format lint clean on all 9 changed files, make validate-core passes (boundary check + 61 root tests + build), attached patch SHA-256 matches working tree. All 3 AC hooks verified in code: external async signer covers upstream signature universe (ed25519/P256/P384/P521) with no private-key export and unreachable sync-init precondition; sendGlobalRequest reuses the ordered pendingGlobalRequests/encrypted path with want-reply + 32KiB bound and no listener side effects; KEX/host-key allowlists filter bundled algorithms in caller order and fail closed, snapshot copies NegotiationResult (test proves constraint via host-key preference inversion and non-configured cipher/MAC reporting). Non-blocking notes for adapter (TASK-260715-1af33i), also in LOGBOOK 2026-07-20 1015: AEAD macAlgorithm reports negotiated-but-unused MAC-list value; .global promise resolves REQUEST_FAILURE as .failure value (not an error); untested residual paths = .success reply payload for .global and empty-allowlist fail-closed — cover during adapter integration.
agent completed: [reviewer] reviewer (claude) (exit=0)
spawn run completed: claude (run=RUN-260720-5d1be9, pid=40607, exit=0)

## Precondition Resources
- [TASK-260720-34d4du_inputs.md](file://TASK-260720-34d4du/TASK-260720-34d4du_inputs.md) — Fork extension: 3 public API hooks

## Outcome Resources
- [TASK-260720-34d4du_spawn-log_-implementer--developer--codex-.log](file://TASK-260720-34d4du/TASK-260720-34d4du_spawn-log_-implementer--developer--codex-.log) — System spawn log captured by task-board
- [TASK-260720-34d4du_ReluxNIOSSH-upstream.patch](file://TASK-260720-34d4du/TASK-260720-34d4du_ReluxNIOSSH-upstream.patch) — Exact 20-file unified fork delta against swift-nio-ssh 0.14.1 / 31cdc3c
- [TASK-260720-34d4du_results.md](file://TASK-260720-34d4du/TASK-260720-34d4du_results.md) — Implementation and verification summary
- [TASK-260720-34d4du_spawn-log_-reviewer--reviewer--claude-.log](file://TASK-260720-34d4du/TASK-260720-34d4du_spawn-log_-reviewer--reviewer--claude-.log) — System spawn log captured by task-board
