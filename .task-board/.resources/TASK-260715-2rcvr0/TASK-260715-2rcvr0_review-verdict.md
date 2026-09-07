# TASK-260715-2rcvr0 review verdict

## Verdict

Changes requested. Route to `to-dev`.

## Candidate reviewed

CR-TASK-260715-2rcvr0-1 revision 1; base `fce475e906c5dc3b0178231e56bd5725ccd62b75`; candidate tree `b40447e6fe64a17815c28852ad2f64001700f067`. All nine working paths matched the candidate blobs. Patch SHA-256 matched `0e533d5d8c5b189bf9a1f29005e216551023fc0b42acf94c631004fc1e168080`.

## Blocking finding

The partial-failure page does not match the production settings-apply control flow. In `diagrams/TASK-260715-2rcvr0_m1-runtime-lifecycle.puml:60`, the branch labelled `committed or uncertain, or later activation fails` proceeds unconditionally through `activateReads` at line 62. In production, `TunnelRuntimeCoordinator.runStartup` records `committed` or `uncertain` for a described apply error and immediately throws at `Sources/ReluxTunnelCore/TunnelRuntimeCoordinator.swift:605`; only a successful apply reaches packet activation at line 623. The focused negative test `settings apply error dispositions preserve failure and clear exactly when required` independently covers notCommitted, committed, and uncertain apply failures. The diagram therefore depicts packet activation after failed committed/uncertain applies, violating AC1 and AC2.

Required rework: split the diagram into three truthful cases: apply failure `notCommitted` (no clear, no activation), apply failure `committed` or `uncertain` (clear, no activation), and successful committed apply followed by packet-activation failure (clear). Regenerate all four SVG pages, visually inspect them, rerun source/link/diff checks, update task outcome evidence, and publish a new CR revision.

## Independent verification

Reviewer reran eight focused Swift filters: 105 tests passed. Negative coverage reached production entry points for malformed/duplicate/stale commands, M0 manifest absence/unreadability and narrowed digest/semantics, rollback at each ownership boundary, stale health, diagnostics hostile labels/values, and SSH redaction. `make m1-runtime-harness-test` passed 6 tests and 7 fixture scenarios. Both adapter target builds passed. Cached terminal rerun of `make macos-targets-validate` passed generated provider graph/resource checks and unsigned macOS host/provider Debug and Release builds. PlantUML check/render passed; regenerated SVGs matched all candidate SVGs byte-for-byte; four pages were visually inspected. Local documentation links passed (29/29), exact candidate `git diff --check` passed, and the M2-M5 task IDs resolved to board elements whose names match the documented seams.

The content correctly avoids a full-UDP claim and explicitly reports the generated macOS provider shell, so no separate finding is recorded for those areas.

## Board anomaly

`task-board validate` exited 0 but reported `PARENT_STATUS_MISMATCH`: Story `STORY-260715-1y04r0` is stored as `analysis` while the child aggregate is `reviewing`. This is not inferred as a clean validation and is not a product blocker; parent normalization remains orchestrator-owned.