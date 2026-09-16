# BUG-260916-2764p8: fix-swift61-m1-runtime-weak-capture-compilation

## Description
Hosted CI run35087910852 on signed PR6 head310a560916d8b8012fa238f65b51649041caee4d now compiles MacOSSSHBootstrapErrorMapper but fails in Sources/ReluxTunnelHarnessSupport/M1RuntimeCommand.swift:138:16: weak must be a mutable variable, because it may change at runtime. Diagnose and minimally fix Swift6.1 compatibility while preserving runtime ownership, cancellation and weak-reference behavior. File belongs to accepted but unlanded Shared Runtime PR stack, not fresh remote main. Reuse accepted prerequisite bytes with exact identity evidence; no unrelated repairs.

## Scope
Minimal harness compatibility source/test delta on the verified accepted PR6 composition. Managed candidate may include only exact accepted prerequisite stack bytes needed to validate this unlanded source; identify them separately from new delta. No gate relaxation, tooling edits, VPN operations, routing changes or publication before independent review.

## Acceptance Criteria
Weak-reference semantics and runtime ownership remain correct; focused meaningful validation passes with exact toolchain bounds recorded; accepted prerequisite identities and new delta are independently reviewable. Hosted Swift6.1 proof and exact signed-head review are subsequent delivery gates, not producer handoff prerequisites.
