# BUG-260720-2zh86a: hev-xcframework-deployment-target-mismatch-blocks-apple-matrix

## Description
PRE-EXISTING (surfaced by TASK-260720-2sltje validation): the full make validate-native Apple build matrix stops before Xcode builds because the HEV XCFramework declares a macOS 10.14/11.0 minimum that mismatches the project deployment targets (macOS 15.0 / iOS 18.0 per ADR-016/3r0993). Task-specific static inspection + validate-core pass, but the full Apple-matrix build is blocked. Must be fixed before the packet-plane Apple builds and physical validation (12x6oq etc.) and before CI full matrix. Likely in the 1g9cyt native seam / build-apple hook or the HEV XCFramework Info.plist minimums. Fix so all native XCFrameworks (HEV, ReluxLibSSH2) declare minimums compatible with iOS 18/macOS 15, and validate-native builds the full matrix.

## Scope
(define bug scope / affected area)

## Acceptance Criteria
(define fix acceptance criteria)
