# TASK-260728-1glezz: configure-autonomous-serial-agent-policy

## Description
Configure the project for one serial tracked child: Codex Sol primary orchestration, Claude Opus 5 production, independent Codex Sol review, lite agent context, bounded Codex auto-continue, provider restriction, commit-time sequencing, and task-board runtime ignores. Preserve the current Git identity and signing configuration.

## Scope
task-board.config.json, docs/spawn-policy.md, README.md, .gitignore, board-owned policy evidence; no tunnel product implementation and no spawn continuity feature enablement before its audited release.

## Acceptance Criteria
Effective preflights resolve developer/claude to claude-opus-5 and reviewer/codex to gpt-5.6-sol high; only Claude and Codex are allowed; max_parallel remains 1; lite context and bounded Codex auto-continue are effective; commit policy records the 20:00-09:00 MSK / 21:00-10:00 Tbilisi window, +04:00 timestamps, strict monotonic accepted-task order, at least one-minute intervals, push, and local-origin equality; current Git identity and signing config are unchanged; docs and README contain no superseded Fable, Claude-only, or credits fallback policy; config validation and diff checks pass.
