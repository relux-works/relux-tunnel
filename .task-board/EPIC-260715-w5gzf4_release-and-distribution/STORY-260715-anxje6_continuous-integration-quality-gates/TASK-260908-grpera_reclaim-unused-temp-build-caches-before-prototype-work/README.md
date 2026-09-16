# TASK-260908-grpera: reclaim-unused-temp-build-caches-before-prototype-work

## Description
Execute the users pending request to inspect and clean unnecessary temporary caches in /Users/iv/Developer/relux-tunnel/.temp to free disk space. This is operational filesystem housekeeping, not a source/test change. Preserve every worktree, branch, source checkout, task evidence, run log, attachment, signing material, and active validation artifact. Only delete explicitly validated regenerable build/cache directories that are not tracked and not used by live processes or active work. Never remove the .temp root or broad task/worktree directory. Work inline in the control root only for ignored cache paths; no product repository edits.

## Scope
Only reproducible unused caches strictly beneath relux-tunnel/.temp. Exclude the entire active Shared Runtime directory .temp/STORY-260715-1y04r0, .temp/deadline-20260908, .temp/spawn-runs, logwork, prompts, evidence, attachments and worktree Git metadata. Do not touch any other project or real VPN. Do not install tools or change global caches.

## Acceptance Criteria
1. Record before/after disk and .temp usage. 2. Record an exact deletion allowlist with path, size, regeneration method, Git ignored/untracked proof and live-process exclusion. 3. Delete only allowlisted caches, preserving every excluded path and worktree registration; unclear targets are skipped. 4. Attach sanitized task-scoped outcome and report freed allocation with APFS caveat. 5. Finish safely before 04:59 Tbilisi 2026-09-08; no successors, all work paused by 05:00.
