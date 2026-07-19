# TASK-260715-3r0993 — Review verdict: ACCEPTED

**Review date:** 2026-07-20
**Reviewer:** [reviewer] reviewer (claude)
**Artifact reviewed:** `.research/260720_task-260715-3r0993-project-generator-deployment-target-policy.md`
(byte-identical to board outcome resource `TASK-260715-3r0993_project-generator-deployment-target-policy.md`)

## Verdict

Accepted → `done`. Decision: Tuist 4.202.5 pinned via repository-local Mise;
new Apple targets iOS 18.0 / macOS 15.0; legacy SwiftPM product stays on a
separate macOS 14.0 lane; explicit Xcode 26.5 (current) and 16.4 (minimum) CI
pins. ADR-016 and ADR-017 are resolved with evidence, spec and logbook are
synchronized, and no code changed (research/decision task — no test run
applicable; only `.spec`, `.planning`, `.research`, and board files touched).

## Independent fact-check (all verified 2026-07-20)

| Claim | Verification | Result |
|---|---|---|
| Tuist 4.202.5 is current stable CLI release | GitHub API: pure-semver stable tags; 4.202.5 published 2026-07-17, newest stable; 4.203.0 exists only as canary prerelease | Confirmed |
| Tuist 4.202.5 requires Swift tools 6.1, macOS 15 host | `Package.swift` at tag: `swift-tools-version: 6.1`, `platforms: [.macOS(.v15)]` | Confirmed |
| Local toolchain Xcode 26.5 (17F42), Swift 6.3.2, macOS 26.5 | `xcodebuild -version`, `swift --version`, `sw_vers` | Confirmed |
| Global Homebrew tuist 4.118.1 is drift, not the pin | `/opt/homebrew/bin/tuist version` → 4.118.1 | Confirmed |
| iPhone 11 (iPhone12,1) paired, iOS 26.5 | `devicectl list devices` + `device info details` | Confirmed |
| iPhone 15 (iPhone15,4) paired, iOS 18.6.2 | Same | Confirmed |
| MacBook Pro Mac15,9, Apple M3 Max | `system_profiler SPHardwareDataType` | Confirmed |
| macOS 14 hosted runner deprecation began 2026-07-06, unsupported by November | actions/runner-images issue #13518 | Confirmed |
| macOS 26 image default Xcode 26.5 → 26.6 on 2026-07-21 | actions/runner-images issue #14344 | Confirmed |
| macos-15 arm64 image: macOS 15.7.7, Xcode 16.4 (16F6) default, iOS 18.5 SDK + 18.6 simulator runtime | macos-15-arm64-Readme.md on main | Confirmed |
| macos-26 arm64 image: Xcode 26.5 (17F42) default, iOS 26.5 simulator | macos-26-arm64-Readme.md on main | Confirmed |
| SwiftNIO SSH 0.14.1 floors macOS 10.15 / iOS 13, tools 6.1 | `Package.swift` at tag 0.14.1 | Confirmed |
| Sparkle 2.9.4 current stable | GitHub releases (published 2026-07-03) | Confirmed |
| NEPacketTunnelProvider macos(10.11)/ios(9.0); NWConnection macos(10.14)/ios(12.0) | Local Xcode 26.5 SDK headers | Confirmed |

## Acceptance criteria

1. Dated TASK-ID-scoped artifact compares Tuist, XcodeGen, checked-in Xcode
   project, and SwiftPM-only across deterministic output, extension targets,
   signing, dependency integration, CI maintenance, and Relux Works fit — met.
2. Tool (Tuist), exact version (4.202.5), pin mechanism (Mise `mise.toml`),
   bootstrap commands, and named upgrade owners — met.
3. iOS 18.0 / macOS 15.0 selected from executable-support evidence (maintained
   runner + simulator + paired physical device), not preference; all API and
   dependency floors verified below the targets — met.
4. Physical baselines named (iPhone 11/iOS 26.5, M3 Max/macOS 26.5) plus oldest
   build-and-test lanes (iPhone 15/iOS 18.6.2, macos-15 runner/Xcode 16.4) — met.
5. Unsupported assumptions held as explicit gates (P0 signing/provisioning,
   iPhone 15 DDI mount repair, ADR-014 SSH pin, HEV revision), not converted to
   configuration — met.

## Non-blocking observations

- The comparison table says Relux Works projects use exact `.mise.toml` pins
  while the pin block is titled `mise.toml`; Mise accepts both filenames — the
  workspace-foundation task (TASK-260715-2btjwm) should just pick one.
- The macos-26 runner host OS is currently macOS 26.4 while its Xcode 26.5
  provides the 26.5 SDKs; the artifact words this correctly (SDK-level claim)
  but CI docs should not assume the runner host OS equals the SDK version.
- iPhone Air iOS 27.0 beta canary lane was not independently version-verified;
  it is optional and carries no decision weight.
