# TASK-260717-xempiv results

Date: 2026-08-30
Role: developer
State: ready for review

## Delivered scope

- Added official remote Swift Package Manager dependency Sparkle 2.9.4 only to
  `ReluxProxyMac`. `.package.resolved` pins revision
  `b6496a74a087257ef5e6da1c5b29a447a60f5bd7`.
- Embedded the byte-identical complete Sparkle 2.9.4 license (SHA-256
  `389a4e4e9a32f059775b13a06e25a591445ba229d2838d26dd3e7c0c45127cfe`).
- Added canonical HTTPS feed metadata, the approved public EdDSA key, required
  signed-feed and pre-extraction verification, zero failure expiration,
  consent-based scheduling, no automatic installation/profiling/JavaScript,
  and Installer-launcher-only service configuration. The decoded public key is
  32 bytes; its non-secret SHA-256 fingerprint is
  `1e9eb93b4aa611f2ebf968ee67dfa4e99f4b93ca7a7c45f76cafc4b47bf36b54`.
- Added a host-owned application delegate that constructs and retains one
  `SPUStandardUpdaterController`. Normal launches start the updater; the hosted
  deterministic test lane constructs it with `startingUpdater: false`.
- Added production validation for HTTPS/no-parameter feed URLs and 32-byte
  base64 public-key metadata, with absent/malformed/insecure negative tests.
- Added `scripts/validate-sparkle-integration.sh`, Make target, README tool row,
  integration documentation, and a logbook entry.

No private key bytes were requested, exported, logged, or persisted. The public
key was read from the existing Sparkle Keychain item's public comment through a
Security API attributes-only query with `kSecReturnData=false`. The official
`generate_keys -p` command was attempted first; headless Keychain policy
functionally refused it even though the vendor process returned exit 0. That
attempt is failure evidence, not the source of the pinned value.

## Validation evidence

| Gate | Result | Evidence |
| --- | --- | --- |
| Tuist 4.202.5 generation and exact SPM resolve | exit 0 | `.temp/TASK-260717-xempiv-workspace-generate-02.log`; generated lock matches `.package.resolved` |
| Focused hosted macOS tests | exit 0; 15 tests in 1 suite | `.temp/TASK-260717-xempiv-focused-test-04.log` |
| HTTP-admitting feed mutant | expected xcodebuild exit 65; named non-HTTPS test failed | `.temp/TASK-260717-xempiv-feed-narrowing-mutant-01.log`; source restored byte-for-byte |
| One-byte-key-admitting mutant | expected xcodebuild exit 65; named malformed-key test failed | `.temp/TASK-260717-xempiv-key-narrowing-mutant-01.log`; source restored byte-for-byte |
| Final Release build, embedded layout, host/provider linkage, plist, license, Hardened Runtime settings, nested component entitlements, inside-out ad-hoc signing, and `codesign --verify --deep --strict` | exit 0 | `.temp/TASK-260717-xempiv-sparkle-smoke-04.log`; artifacts under `.temp/TASK-260717-xempiv/sparkle-smoke-04/` |
| Workspace foundation validation | exit 0 | `.temp/TASK-260717-xempiv-workspace-validate-01.log` |
| Changed Swift format lint, shell syntax, plist lint, and `git diff --check` | exit 0 | `.temp/TASK-260717-xempiv-swift-format-lint-04.log` and command transcript |
| Changed-scope private-material scan | exit 0; zero candidates | `.temp/TASK-260717-xempiv-private-material-scan-02.log` |

The first Release signing smoke is not a passing gate. Its outer `tee` pipeline
masked an internal failure: strict verification detected Sparkle's stale seal
after Xcode removed Headers/Modules from the embedded framework. The corrected
validator preserves component entitlements, re-signs Sparkle nested code
inside-out, then signs provider and host. Final direct runs 02, 03, and 04 exited
0; run 04 is the acceptance evidence.

The credential-free signature is ad-hoc and has no Team ID. It proves nested
code shape, retained entitlements, runtime flags, and strict signature
consistency without Apple secrets. It does not claim Developer ID signing,
notarization, stapling, or update installation. Release build warnings are
pre-existing deprecation/alignment/App Category warnings; the build completed.

`task-board validate` returned process exit 0 but printed three parent-status
mismatches, so board state is not reported clean. Two are unrelated Stories.
The relevant `STORY-260717-1ecq74` remains `backlog` while this child is in
development because the Story is hard-blocked by `STORY-260715-l2i2oo` and
`STORY-260715-c1qsc6`; no parent status was forced manually.

## Security and lifecycle boundaries

- Host development and Developer ID entitlement source files retain their exact
  approved five-key sets, including App Sandbox, network client, system-extension
  install, and only `-spks`/`-spki` Sparkle Mach names. No App Group, Keychain
  group, JIT, unsigned-memory, library-validation, or debug entitlement was
  introduced.
- The packet-tunnel provider has no Sparkle linkage or updater/helper content.
  Its entitlement source and system-extension embedding boundary remain intact.
- Installer XPC is enabled; Downloader, Installer Connection, and Installer
  Status services are disabled. The disabled Downloader XPC may remain present
  in the official framework but has no plist authority to launch.
- No updater network start, update installation, VPN enablement, system-extension
  activation, route/DNS mutation, publication, or notarization ran.

## Residual physical gates

Before accepting a physical update installation, the host must request an
orderly tunnel stop and wait for system-authoritative inactivity. After Sparkle
replaces and relaunches the host, the application must separately activate or
replace the embedded Network Extension system extension, accurately surface
approval/failure/restart-required state, and avoid automatic VPN reconnect.
These behaviors were documented but not exercised on this machine; downstream
physical-validation tasks retain ownership.
