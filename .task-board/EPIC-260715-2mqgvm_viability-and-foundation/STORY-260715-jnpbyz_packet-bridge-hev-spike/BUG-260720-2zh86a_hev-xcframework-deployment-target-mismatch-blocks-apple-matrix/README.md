# BUG-260720-2zh86a: hev-xcframework-deployment-target-mismatch-blocks-apple-matrix

## Description
PRE-EXISTING (surfaced by TASK-260720-2sltje validation): the full make validate-native Apple build matrix stops before Xcode builds because the HEV XCFramework declares a macOS 10.14/11.0 minimum that mismatches the project deployment targets (macOS 15.0 / iOS 18.0 per ADR-016/3r0993). Task-specific static inspection + validate-core pass, but the full Apple-matrix build is blocked. Must be fixed before the packet-plane Apple builds and physical validation (12x6oq etc.) and before CI full matrix. Likely in the 1g9cyt native seam / build-apple hook or the HEV XCFramework Info.plist minimums. Fix so all native XCFrameworks (HEV, ReluxLibSSH2) declare minimums compatible with iOS 18/macOS 15, and validate-native builds the full matrix.

## Scope
(define bug scope / affected area)

## Acceptance Criteria
1. All locally-rebuilt native XCFrameworks (HEV ReluxHEV + ReluxLibSSH2) declare deployment-target minimums compatible with the project targets iOS 18.0 / macOS 15.0 (per ADR-016/3r0993) across every slice (ios-arm64, ios-arm64_x86_64-simulator, macos-arm64_x86_64, and any tvOS if kept) — no slice advertises macOS 10.14/11.0. 2. make validate-native builds the FULL Apple matrix (iOS device, iOS simulator, macOS provider + harness) without stopping on the deployment-target mismatch. 3. The fix is in the build/vendor path (build-apple invocation flags and/or XCFramework Info.plist MinimumOSVersion normalization in the 1g9cyt seam / build-native-apple-matrix.sh), NOT by patching pinned upstream C source. 4. Static/extension-safety + checksum gates still pass; make validate-core stays green; no regression to accepted HEV/libssh2 integration tests. 5. Reproducible: a clean rebuild produces XCFrameworks with the corrected minimums.
