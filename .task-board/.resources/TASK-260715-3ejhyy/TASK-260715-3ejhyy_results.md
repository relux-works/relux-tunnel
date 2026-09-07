# TASK-260715-3ejhyy — developer rework 3 outcome

## Result

Ready for review. Revision-2 finding F1 is closed without widening the accepted
M0 graph or exposing a production override.

## Change

- `MacOSProductionBindingManifestValidator.bool(_:)` now accepts only an
  `NSNumber` whose Core Foundation type is exactly `CFBoolean`. Foundation's
  numeric `NSNumber(0)` and `NSNumber(1)` values no longer bridge into the
  `productionCompositionPermitted` gate.
- The Swift Testing regression changes only
  `productionCompositionPermitted` to numeric `0` and `1`. The semantic layer
  requires `.compositionNotPermitted`; the real production entry point
  `MacOSProductionDependencyFactory.makeRuntime()` independently requires the
  immutable digest and proves zero component-factory calls before refusal.
- `LOGBOOK.md` records the type-confusion, fix, adversarial mutant, and final
  verification.

## Accepted dependency pin

- Sole accepted source:
  `Configuration/TASK-260720-1qhxqa_m0-production-bindings-v1.json`
- Repository and task precondition copies are each 17,492 bytes.
- Both SHA-256 values are
  `40333862b46b7af04cdd966ade91e8c9cc917e573c6601e26e7fa956d11ae161`.
- Live M0 validation reports `productionCompositionPermitted=true`, no
  failures, schema version 1, and the same digest.

## Negative evidence

The exact current test was attacked by restoring the rejected production
implementation `value as? Bool`. The named
`semanticBooleanTypes` Swift test then exited 1 because numeric `1` returned a
complete `MacOSAcceptedM0Bindings` value. After restoring the exact-CFBoolean
guard, the same test exited 0. The test also drives
`MacOSProductionDependencyFactory.makeRuntime()` for numeric `0` and `1` and
requires the immutable digest gate to stop both with zero graph construction.

Production call site: `MacOSProductionDependencyFactory.makeRuntime()`.

## Verification

| Gate | Result | Evidence |
| --- | --- | --- |
| Focused composition | exit 0; 10/10 | `.temp/TASK-260715-3ejhyy/swift-test-composition-bool-rework-02.log` |
| Exact boolean mutant | expected exit 1; numeric `1` admitted | `.temp/TASK-260715-3ejhyy/swift-test-bool-mutant-expected-failure-02.log` |
| Restored boolean gate | exit 0; 1/1 | `.temp/TASK-260715-3ejhyy/swift-test-bool-restored-02.log` |
| Exact macOS production ownership | exit 0; 1/1 | `.temp/TASK-260715-3ejhyy/swift-test-ownership-bool-rework-01.log` |
| Exact deterministic harness ownership | exit 0; 3/3 | `.temp/TASK-260715-3ejhyy/swift-test-harness-bool-rework-01.log` |
| Full SwiftPM suite | exit 0; 508 tests / 43 suites; 25 known unavailable-ReluxNIOSSH issues | `.temp/TASK-260715-3ejhyy/swift-test-full-bool-rework-02.log` |
| macOS adapter build | exit 0 | `.temp/TASK-260715-3ejhyy/swift-build-macos-adapter-bool-rework-01.log` |
| Deterministic harness build | exit 0 | `.temp/TASK-260715-3ejhyy/swift-build-harness-bool-rework-01.log` |
| Unsigned macOS host/provider Debug+Release matrix | exit 0 | `.temp/TASK-260715-3ejhyy/macos-targets-validate-bool-rework-02.log` |
| Core boundary guard | exit 0 | `.temp/TASK-260715-3ejhyy/check-core-boundaries-bool-rework-01.log` |
| Native HEV/libssh2 pins and linkage | exit 0 | `.temp/TASK-260715-3ejhyy/check-native-dependencies-bool-rework-01.log` |
| Accepted M0 live validation | exit 0; permitted, no failures | `.temp/TASK-260715-3ejhyy/m0-bindings-check-bool-rework-01.log` |
| M0 adversarial suite | exit 0; 32/32 | `.temp/TASK-260715-3ejhyy/m0-bindings-test-bool-rework-02.log` |
| Strict recursive Swift format and diff check | exit 0 | `.temp/TASK-260715-3ejhyy/final-lint-diff-hashes-bool-rework-01.log` |
| Manifest size/digest verification | exit 0; both copies exact | `.temp/TASK-260715-3ejhyy/final-diff-and-pin-bool-rework-01.log` |

## Preserved evidence and safety

- The initial tool-readiness command exited 1 because `status` is readonly in
  zsh; the corrected task-scoped readiness probe exited 0.
- The first M0 negative-suite wrapper and first provider-matrix wrapper yielded
  without a final exit code. Neither was treated as a pass. Both gates were
  rerun to observed exit 0; the provider rerun was polled to terminal state.
- `task-board validate` returned process exit 0 while reporting the pre-existing
  owning Story aggregate mismatch (`to-dev` versus child aggregate
  `development`). The result is retained at
  `.temp/TASK-260715-3ejhyy/task-board-validate-bool-rework-01.log` and is not
  described as a clean board validation.
- No signing, installation, application/provider launch, VPN start, live
  Keychain lookup, SSH network connection, route/DNS mutation, or live
  PacketFlow/HEV runtime was performed.
