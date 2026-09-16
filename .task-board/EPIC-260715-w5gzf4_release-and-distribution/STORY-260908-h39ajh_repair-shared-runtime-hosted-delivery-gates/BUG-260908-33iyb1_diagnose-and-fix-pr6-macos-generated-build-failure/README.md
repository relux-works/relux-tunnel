# expose-hosted-macos-build-diagnostics

## Description
Diagnostic prerequisite split from the original hosted build failure. Deliver diagnostic propagation preserving failure status and bounded output. Full root-cause repair and hosted green requirement remains open as BUG-260908-shki8p in STORY-260908-23tefs; never claim original failure fixed.

## Scope
Existing diagnostic patch, macOS validator log propagation, positive/negative/narrowing tests and docs. Preserve signed sibling and Shared Runtime; no guessed toolchain/product change.

## Acceptance Criteria
Actual validation entry points preserve exit65 and other failures, expose bounded diagnostic tail, retain full logs in artifact root; named positive/negative/narrowing tests; real macOS validation on candidate and exact PR6 composition; independent immutable review; original hosted repair remains open BUG-260908-shki8p without any hosted green or root-cause claim.
