# TASK-260830-1srcgk: realign-autonomous-serial-agent-policy-to-sol-high

## Description
Realign the project orchestration policy to the active primary goal: Codex gpt-5.6-sol high only, one tracked child at a time, lite context, fresh serial reviewer, and existing signed commit/push synchronization rules.

## Scope
task-board.config.json, docs/spawn-policy.md, .spec/goal-macos-v1.md consistency checks, effective producer/reviewer preflights, and board evidence. No product runtime code or VPN activation.

## Acceptance Criteria
The effective developer and reviewer preflights both resolve Codex gpt-5.6-sol high with max_parallel 1 and lite context; canonical policy documents agree; config validation and focused drift scans pass; task-scoped evidence records the superseded medium/parallel policy and the accepted replacement.
