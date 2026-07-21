## Status
done

## Assigned To
[reviewer] reviewer (codex)

## Created
2026-07-16T21:05:48Z

## Last Update
2026-07-21T19:25:07Z

## Blocked By
- (none)

## Blocks
- TASK-260717-xempiv
- TASK-260717-1mt4e7

## Checklist
- [x] Verify current Sparkle and Apple behavior from primary sources
- [x] Record exact dependency, signature, notarization, channel, helper, and lifecycle contract
- [x] Define rollback, withdrawal, key custody, privacy, and human release gates
- [x] Bound Network Extension update claims and preserve physical validation gate
- [x] Attach dated research and task-scoped downstream handoff evidence
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
spawn queued: [analyst] researcher (codex) (run=RUN-260721-af47a3, max_parallel=1)
spawn run started: [analyst] researcher (codex) (run=RUN-260721-af47a3)
Research checkpoint 2026-07-21: official Sparkle release/docs select exact 2.9.4; signed feeds require 2.9 and fail-closed settings; Sparkle 2 removed downgrade support. Apple TN3134 requires a system-extension packet-tunnel provider for direct Developer ID distribution; host replacement and provider activation/replacement are separate lifecycle gates.
Producer validation 2026-07-21: dated primary-source report and downstream handoff attached as task-scoped outcomes and verified byte-identical to .research sources; ADR-018, platform distribution, threat model, security claims, README, and LOGBOOK refined. Official latest release/tag/manifest/checksum reverified; downloaded 2.9.4 SPM asset checksum matched; git diff --check, required-spec presence, task-board validate, and Ruby YAML syntax cross-check passed. Local Python workflow YAML row was unavailable because PyYAML is not installed and is recorded under task-scoped .temp; workflow files were unchanged. All 11 checklist items satisfied. Independent Codex review remains required before done.
agent completed: [analyst] researcher (codex) (exit=0)
spawn run completed: codex (run=RUN-260721-af47a3, pid=97365, exit=0)
spawn queued: [reviewer] reviewer (codex) (run=RUN-260721-091fa0, max_parallel=1)
spawn run started: [reviewer] reviewer (codex) (run=RUN-260721-091fa0)
Independent reviewer verdict 2026-07-21: ACCEPTED. Live official Sparkle and Apple evidence, exact 2.9.4 tag/manifest/license/asset checksum, updater and System Extension semantics, cross-document consistency, task-scoped handoff, privacy/secret scans, board/diff/link validation, and a green 332-test rerun satisfy all AC. The first full Swift run had one transient unrelated HEV UDP baseline failure; its exact focused rerun and a fresh full suite passed. Verdict outcome: TASK-260717-2uyfn5_review-verdict.md.
agent completed: [reviewer] reviewer (codex) (exit=0)
spawn run completed: codex (run=RUN-260721-091fa0, pid=12173, exit=0)

## Precondition Resources
- [TASK-260717-2uyfn5_execution-brief.md](file://TASK-260717-2uyfn5/TASK-260717-2uyfn5_execution-brief.md) — Primary-source self-update decision brief
- [TASK-260717-2uyfn5_reviewer-focus.md](file://TASK-260717-2uyfn5/TASK-260717-2uyfn5_reviewer-focus.md) — Independent primary-source review focus

## Outcome Resources
- [TASK-260717-2uyfn5_research.md](file://TASK-260717-2uyfn5/TASK-260717-2uyfn5_research.md) — Primary-source macOS self-update decision and evidence
- [TASK-260717-2uyfn5_downstream-handoff.md](file://TASK-260717-2uyfn5/TASK-260717-2uyfn5_downstream-handoff.md) — Downstream implementation, validation, privacy, and residual-gate handoff
- [TASK-260717-2uyfn5_review-verdict.md](file://TASK-260717-2uyfn5/TASK-260717-2uyfn5_review-verdict.md) — Independent primary-source review acceptance and validation evidence
