# TASK-260715-1idq8c developer outcome — rework 02

## Delivered

- Fixed the POSIX conditional-function failure path in `run-apple-ui-test-smoke.sh`: Xcode, extractor, artifact validator, runtime row, and aggregate statuses are captured explicitly.
- Added an independent fail-closed artifact validator for `screenshots.json`, schema/count consistency, task-directory confinement, non-empty PNGs, and the two expected step names.
- Added a production-script regression that injects extractor exit 42 and proves the aggregate build-host gate exits 1. Missing, empty, malformed, and incomplete evidence also has focused Python coverage.
- Kept native macOS runtime explicitly deferred to `TASK-260822-3q4grm`; no signed/native runtime or VPN/system-network action was introduced.

## Acceptance and command evidence

- `make apple-ui-test-contract`: exit 0. Static safety, four Python extraction/validation tests, injected extractor-failure aggregate regression, 18-fixture shared Swift Testing suite, and snapshot-diff suite passed. Log: `.temp/TASK-260715-1idq8c/apple-ui-test-contract-rework-02-02.log`.
- `make apple-ui-test-smoke`: exit 0. Run: `.temp/TASK-260715-1idq8c/apple-ui-test/run.mR0QvC`. Native macOS unsigned build-for-testing 0; native runtime deferred; iOS Simulator Xcode 0; screenshot artifact validation 0; iOS row 0; controlled snapshot mismatch 1; aggregate 0. Log: `.temp/TASK-260715-1idq8c/apple-ui-test-smoke-rework-02-02.log`.
- Negative production seam: injected extractor exit 42, iOS artifact/row exit 42, aggregate exit 1. Covered by `scripts/tests/test-apple-ui-test-smoke-extractor-failure.sh` through the focused contract gate.
- Shell syntax, Python compile, strict recursive Swift format lint, and `git diff --check`: exit 0. Log: `.temp/TASK-260715-1idq8c/rework-02-syntax-lint-diff-01.log`.
- `make workspace-validate`: exit 0. Log: `.temp/TASK-260715-1idq8c/workspace-validate-rework-02-01.log`.
- `swift build`: exit 0. Log: `.temp/TASK-260715-1idq8c/swift-build-rework-02-01.log`.
- `swift test`: exit 0; 455 tests in 40 suites passed with the 25 declared ReluxNIOSSH-unavailable known issues. Log: `.temp/TASK-260715-1idq8c/swift-test-rework-02-01.log`.

## Visual review

Both extracted iOS Simulator PNGs were opened at original 1206x2622 resolution. `Step_01__diagnostic_fixture_ready_*` and `Step_02__diagnostic_fixture_confirmed_*` are portrait, centered and unclipped, show the expected diagnostic fixture, disabled network/VPN boundary, action, and state text, and are neither black nor empty. The controlled 32x32 `diff.png` visibly highlights the intentional mismatch.

## Safety and residual risks

No signing, notarization, native macOS app/test launch, provider installation or launch, NetworkExtension approval, VPN preference mutation, or route/DNS/interface/packet-filter change occurred. Signed native macOS fixture runtime remains owned by `TASK-260822-3q4grm` on the dedicated host. Physical-device evidence remains a separately named future contract. Product-screen snapshot baselines remain intentionally absent until product screens exist.
