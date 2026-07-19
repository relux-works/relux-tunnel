## Status
done

## Assigned To
[reviewer] reviewer (claude)

## Created
2026-07-15T01:00:10Z

## Last Update
2026-07-19T22:11:02Z

## Blocked By
- (none)

## Blocks
- TASK-260715-3r0993
- TASK-260715-3bdplx
- TASK-260715-32umrc
- TASK-260715-35nc5m
- TASK-260715-14lk3y
- TASK-260715-2nfz7w

## Checklist
- [x] Every existing build, test, default, packaging, and release path is inventoried
- [x] Must-preserve invariants and later retirement decisions are separated
- [x] The regression inventory is attached as a TASK-ID-scoped outcome resource
- [x] Findings written to file
- [x] Key aspects highlighted
- [x] Fact-checking performed — claims verified, sources cited
- [x] Findings linked on the board as a new task-scoped outcome resource
- [x] All questions from task description answered
- [x] Important findings, decisions, anomalies, or regressions recorded in logbook when relevant
- [x] Implementation matches AC
- [x] Solution fits project architecture
- [x] Tests green
- [ ] If review does not accept the work — verdict evidence added and status routed by the explicit verdict branches

## Notes
spawn queued: [analyst] researcher (codex) (run=RUN-260719-a01ea8, max_parallel=1)
spawn run started: [analyst] researcher (codex) (run=RUN-260719-a01ea8)
Research artifact attached as TASK-260715-1fv4z1_legacy-inventory.md and persisted at .research/260720_legacy-inventory.md. Verified v0.1.0 source/build/tests/release, separated M0 preservation from later retirement, mapped ownership, and logged that ignored local dist output is not the notarized published release baseline.
agent completed: [analyst] researcher (codex) (exit=0)
spawn run completed: codex (run=RUN-260719-a01ea8, pid=28515, exit=0)
spawn queued: [reviewer] reviewer (claude) (run=RUN-260719-eb5ec7, max_parallel=1)
spawn run started: [reviewer] reviewer (claude) (run=RUN-260719-eb5ec7)
REVIEW ACCEPTED (2026-07-20). Independently re-verified against /Users/iv/Developer/relux-proxy read-only: signed tag v0.1.0 -> 2557aba1c030d0643d76e0bc3b185f6d5fd172e1 (good ECDSA signature, fingerprint matches); v0.1.0..HEAD diff limited to the five documented doc changes, scoped worktree clean; Package.swift (tools 5.10, macOS 14, lang v5, one exec + one test target, no deps), five source files, four XCTest cases, AppStorage defaults sshHost=relux/sshAccount=administrator/localPort=1080, exact /usr/bin/ssh argument vector, Info.plist keys incl. works.relux.proxy + LSUIElement, all six Makefile targets, build-app.sh (Developer ID default identity, ad-hoc fallback, UNIVERSAL=1), create-dmg.sh (-universal naming, UDZO, Relux Proxy volume), ci.yml and release.yml (secrets, -P "" import, notarytool wait, staple, spctl, provenance, stable asset) all match the inventory verbatim. TunnelController claims confirmed at source: singleton guard, port preflight, 100x200ms readiness poll, 4000-char stderr cap, SIGTERM then SIGKILL after 2s, shutdown on Quit and applicationWillTerminate. GitHub evidence re-checked live: release run 29274001137 success with headSha = tag commit; v0.1.0 assets non-draft, published 2026-07-13T18:20:45Z, both DMGs 1775722 bytes digest 5159c07c...63c20d, SHA256SUMS 179 bytes. Anomaly 1 confirmed: local dist DMG is 1748814 bytes, 97ef2332...523ae0, differing from published baseline. Tests re-run green: 4/4 XCTest passed in a disposable v0.1.0 clone under .temp/TASK-260715-1fv4z1 (removed after). Referenced destination evidence exists: .spec/platform-distribution.md, .spec/architecture.md, diagrams/TASK-260715-32umrc_target-dependency-plan.dot, docs/current-state.md (legacy), and board tasks TASK-260715-14lk3y/32umrc/35nc5m. All five AC met; artifact usable as standalone regression checklist. Verdict: done.
agent completed: [reviewer] reviewer (claude) (exit=0)
spawn run completed: claude (run=RUN-260719-eb5ec7, pid=36551, exit=0)

## Precondition Resources
- [TASK-260715-1fv4z1_context.md](file://TASK-260715-1fv4z1/TASK-260715-1fv4z1_context.md) — Paths and access for the legacy inventory

## Outcome Resources
- [TASK-260715-1fv4z1_spawn-log_-analyst--researcher--codex-.log](file://TASK-260715-1fv4z1/TASK-260715-1fv4z1_spawn-log_-analyst--researcher--codex-.log) — System spawn log captured by task-board
- [TASK-260715-1fv4z1_legacy-inventory.md](file://TASK-260715-1fv4z1/TASK-260715-1fv4z1_legacy-inventory.md) — Authoritative legacy inventory and M0 regression checklist
- [TASK-260715-1fv4z1_spawn-log_-reviewer--reviewer--claude-.log](file://TASK-260715-1fv4z1/TASK-260715-1fv4z1_spawn-log_-reviewer--reviewer--claude-.log) — System spawn log captured by task-board
