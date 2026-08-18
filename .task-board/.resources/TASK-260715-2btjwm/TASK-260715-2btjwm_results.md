# TASK-260715-2btjwm — workspace foundation results

## Outcome

Ready for independent review after reviewer-requested rework. The repository
generates `ReluxTunnel.xcworkspace` and `ReluxTunnelApp.xcodeproj` from
source-controlled Tuist manifests using exactly Tuist 4.202.5 through Mise.
Generated Xcode state and the credential-bearing local signing overlay are
ignored.

The foundation defines exactly Debug and Release, one shared settings chain,
macOS 15.0 and iOS 18.0 inputs, Swift 6 complete-concurrency inputs, provider
extension-safe overlays, credential-free signing defaults, the accepted r12
identifier projection, and one version input.

The checked-in `.macOSOnly` workspace-mode input emits exactly these six stable
schemes: `ReluxProxyMac`, `ReluxProxyMacTunnel`, `ReluxTunnelCore`,
`ReluxTunnelHarness`, `relux-relay`, and `relux-relay-protocol-test`. The
reviewer-reported mismatch is resolved: `ReluxProxyIOS` and
`ReluxProxyIOSTunnel` remain source-controlled future names behind
`.macOSAndIOS`, but are absent from the generated macOS-only workspace and from
`xcodebuild -list`. ADR-024/ADR-027 must resume before the iOS target task may
select that mode and add the matching targets/actions.

The existing root `Package.swift` remains tracked and byte-unchanged. The
generated project contains an Xcode local-package reference to `.` and does not
absorb package sources or tests.

## Source-controlled deliverables

- `mise.toml`, `Tuist.swift`, `Workspace.swift`, and `Project.swift`
- `Configuration/*.xcconfig` checked-in settings, identity, version, provider,
  and signing-example inputs
- `scripts/generate-workspace.sh` pinned clean generator
- `scripts/validate-workspace-foundation.sh` normalized double-generation gate
- `Makefile` entry points: `workspace-generate`, `workspace-validate`
- `docs/generated-workspace-foundation.md`, `LOGBOOK.md`, and README inventory
- `.gitignore` generated-project and local-signing policy

## Validation evidence

All commands were rerun from `/Users/iv/Developer/relux-tunnel` after rework.

- `mise exec -- tuist version` — exit 0; `4.202.5`.
- `make workspace-validate` — exit 0. Two clean generations had identical
  normalized file-hash manifests. Both manifest files have SHA-256
  `9fc4f2398350abdf70c89210af6a5d6c546634df1aa15d83ee78b33c4941342e`.
  Exactly six active schemes were visible; both deferred iOS schemes were
  absent. Debug/Release, deployment/Swift/signing/version/provider inputs,
  ignored generated state, the local-package reference, and Package.swift
  preservation passed.
- `swift format lint --strict Project.swift Tuist.swift Workspace.swift` —
  exit 0, no diagnostics.
- `sh -n scripts/generate-workspace.sh scripts/validate-workspace-foundation.sh`
  — exit 0.
- `swift test` — exit 0; 443 tests in 37 suites passed with 25 pre-existing
  recorded known issues.
- `swift build` — exit 0.
- `git diff --check` — exit 0.
- `git diff --exit-code -- Package.swift` — exit 0; current Package.swift
  SHA-256 is `70a954490209da3e87067fcc8f4de27a8e6b0d72f769698d608a9890b2a131dc`.

Task-scoped generated evidence is under `.temp/TASK-260715-2btjwm/`, including
`generation-01.sha256`, `generation-02.sha256`, and `xcodebuild-list.log`.

## Expected behavior

Tuist/Xcode reports that foundation schemes have no supported build destination
because this task intentionally adds no platform targets or source. Dependent
host, provider, package-action, and relay-action tasks attach build/test actions
to these stable names. This outcome does not claim signing, target builds, or
iOS enablement.
