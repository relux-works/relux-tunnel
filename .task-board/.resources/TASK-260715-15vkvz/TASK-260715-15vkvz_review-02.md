# TASK-260715-15vkvz review 02 — changes requested

## Findings

1. P1 — Repository operations are not serialized across suspension points. OwnedVPNManagerRepository is an actor, but every public mutation path suspends in load/save/remove/terminal-status callbacks. Swift actors are reentrant while a method is suspended, and there is no operation gate or queued tail in this actor. A second ensure/enable/disable/remove/repair call can therefore enter while the first callback is pending, observe the same zero/one-owned state, and issue a conflicting create or stale-object mutation. This violates the accepted contract's per-process serialization requirement and defeats zero/one convergence under concurrent callers. Add an explicit non-reentrant operation gate and deterministic tests that hold the first callback, start another repository operation, and prove the second does not load or mutate until the first reaches a terminal result; include concurrent zero-manager ensure proving only one canonical manager is saved.

2. P1 — The production adapters still overflow and type-confuse manager-contract NSNumber values. IOSVPNManagerPreferences.swift:208-209 and MacOSVPNManagerPreferences.swift:209-210 accept every non-Boolean NSNumber and use intValue. Foundation demonstrates that NSNumber(value: 1.5) becomes Int 1 and NSNumber(value: UInt64.max) becomes Int -1. The former is falsely accepted as current schema; the latter is a positive unsupported-future version misclassified as repairable corruption, allowing ensure to overwrite it. This violates AC 2-4 and rework item 1. Decode only exact integer representations without truncation, preserve every positive future value through a non-overflowing inspection/error representation, and add iOS/macOS seam tests for fractional NSNumber, Bool, UInt64.max, Int.max, and normal Int 1. Prove unsupported/future values receive zero setter/save/remove calls.

## Prior rework assessment

The review-01 findings themselves are closed for the core Int fixtures: UInt16.max+1 and Int.max stay future, explicit enable rejects connecting/reasserting/disconnecting and saves/reloads when already enabled, stale replacements are freshly revalidated, and distinct post-save reloads reject noncanonical persistence.

## Independent validation

- swift test --filter OwnedVPNManagerRepositoryTests: PASS, 23 tests in 1 suite.
- make validate-core: PASS, 241 tests in 24 suites plus post-test build.
- iOS Simulator ReluxTunnelIOSAdapter xcodebuild: PASS.
- macOS ReluxTunnelMacOSAdapter xcodebuild: PASS.
- swift format lint --strict --recursive Sources Tests Package.swift: PASS.
- git diff --check: PASS.
- task-board validate: PASS.

Verdict: changes requested. Route to to-dev for serialization and exact NSNumber decoding rework, followed by a fresh reviewer cycle.
