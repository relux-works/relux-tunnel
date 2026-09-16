# TASK-260717-rk4mi7 developer outcome

## Implementation
- Added persisted non-secret automatic-check and stable/pre-release channel preferences.
- Added a narrow host-only Sparkle adapter, deterministic scheduler reconciliation, check-now command, lifecycle presentation states, and fixed redacted failure copy.
- Added localized English MenuBarExtra controls with no window-opening or application-activation production path.
- Added metadata validation that distinguishes absent pre-release policy from malformed metadata and fails malformed values closed.

## Tests and validation
- Focused ReluxProxyMac Swift Testing: exit 0; 27 tests in 2 suites passed. Log: .temp/TASK-260717-rk4mi7/xcode-test-final.log.
- Unsigned macOS ReluxProxyMac Debug build: exit 0. Log: .temp/TASK-260717-rk4mi7/xcode-build-final.log.
- swift format strict recursive lint: exit 0.
- String Catalog JSON validation: exit 0. Info.plist validation: exit 0. git diff --check: exit 0.
- Negative gate proof: a temporary weakened production channel allowlist admitted traversal-shaped metadata and caused the named malformed-metadata test to fail, xcodebuild exit 65; the production regex allowlist was restored and the full focused suite passed. Log: .temp/TASK-260717-rk4mi7/channel-gate-mutant-02.log. Production call site: ReluxProxyUpdaterConfiguration.feedPolicy(in:).

## Safety boundary
No update was installed, no feed was published, no network update check was initiated, and no app/provider/system extension was activated. VPN, routes, interfaces, packet filters, and DNS were not changed. Tests used injected updater/scheduler seams plus a real no-start Sparkle controller.