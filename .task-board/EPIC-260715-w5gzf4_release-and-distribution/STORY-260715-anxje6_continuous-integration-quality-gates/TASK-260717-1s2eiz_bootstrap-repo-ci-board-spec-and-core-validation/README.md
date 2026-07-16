# TASK-260717-1s2eiz: bootstrap-repo-ci-board-spec-and-core-validation

## Description
Stand up minimal GitHub Actions CI on the relux-tunnel repo from day one, before the full quality-gate pipeline exists. Runs on push/PR: task-board validate (board structural integrity), .spec presence/link check, YAML lint of workflows, and — once ReluxTunnelCore SwiftPM target exists — swift build/test of the shared core. Hardened defaults: least-privilege GITHUB_TOKEN permissions, pinned action major versions, concurrency guard. AC: workflow present and green on a clean checkout; validates board + specs with no Apple credentials required; documented as the seed that the full CI story (harden-github-actions, target build matrix, release orchestration) extends, not replaces. Autonomous end-to-end.

## Scope
(define task scope)

## Acceptance Criteria
(define acceptance criteria)
