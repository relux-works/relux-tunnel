# TASK-260715-3jloqy — macOS App IDs, capabilities, and development profiles

Execution date: 2026-08-10 (Asia/Tbilisi). Matrix: `2026-07-28.r12`. Team: Relux Works, LLC (`262RZ595FP`).

## Outcome

Xcode automatic provisioning, using the account already authorized in Ceremony C1, created or reused the four exact explicit macOS App IDs and downloaded one newly generated device-bound Mac development profile for each:

| Bundle identifier | Profile UUID | Created (UTC) | Expires (UTC) |
| --- | --- | --- | --- |
| `works.relux.tunnel.mac` | `94e03d45-3e13-4466-8aa4-66f85875e01a` | 2026-08-10 19:28:44 | 2027-08-10 19:28:44 |
| `works.relux.tunnel.mac.tunnel` | `94f18743-1bca-489c-9c00-b5737b8ae89e` | 2026-08-10 19:30:58 | 2027-08-10 19:30:58 |
| `works.relux.tunnel.probe.mac` | `c0a3cd4e-77c8-475e-98e0-6deec8269810` | 2026-08-10 19:31:26 | 2027-08-10 19:31:26 |
| `works.relux.tunnel.probe.mac.tunnel` | `ef64bcae-00ac-458f-94dc-45834429fe80` | 2026-08-10 19:31:50 | 2027-08-10 19:31:50 |

Each profile is named `Mac Team Provisioning Profile: <bundle identifier>`. Its `OSX` platform, enumerated `ProvisionedDevices`, and Apple Development certificate set establish the Mac development class. No certificate was created or exported.

## Profile inspection

The four CMS payloads were decoded locally and checked in memory. Every row passed all of these assertions:

- `TeamIdentifier == [262RZ595FP]` and `ApplicationIdentifierPrefix == [262RZ595FP]`.
- `com.apple.application-identifier == 262RZ595FP.<exact bundle identifier>`.
- Platform is `OSX`; the profile is valid now and has a one-year validity window ending 2027-08-10.
- `ProvisionedDevices` contains exactly one device: this Apple-silicon Mac. Only the privacy-safe reference `sha256:8ea3983a9990` is retained.
- `com.apple.developer.networking.networkextension` contains the unsuffixed `packet-tunnel-provider` value on hosts and providers alike. It does not contain `packet-tunnel-provider-systemextension`. The portal's development capability profile also lists its standard additional unsuffixed Network Extensions values; r12 assertion A7 requires the profile to authorize the requested value as a superset.
- `com.apple.security.application-groups` is absent from every profile (A16).
- The profile-only `keychain-access-groups == [262RZ595FP.*]` wildcard is present on every profile. This is the expected team-wide Mac development wildcard and is not a K2 finding; no target entitlement or portal keychain-sharing mutation was requested.
- `ProvisionsAllDevices` is absent and development certificates are present.

The validator found one unique local profile UUID for each approved App ID, exactly four profiles changed during this run, and zero unexpected changed profiles. Exit: 0, zero assertion failures.

## Mutation-scope negatives

The isolated provisioning project declared exactly four macOS application targets with the four approved bundle identifiers, automatic Debug signing for team `262RZ595FP`, and one authored entitlement only:

```text
com.apple.developer.networking.networkextension = [packet-tunnel-provider]
```

It declared no App Group identifier or App Groups capability, no Keychain Sharing/keychain access group, no iOS target or identifier, no distribution configuration/profile request, and no legacy `works.relux.proxy` target. Therefore this run made no App Group-record mutation, App Groups-capability mutation, Keychain access-group mutation, iOS App-ID mutation, distribution-profile mutation, or legacy identity mutation. The four locally changed profiles are all in the approved macOS development set; no iOS or distribution profile changed.

Read-only Safari page observation remains unavailable: a bounded front-document query timed out at exit 142. Consequently this evidence does not claim an exported portal inventory screenshot. The server-issued explicit profiles prove the four App IDs and Network Extensions capability, while the exact harness mutation surface, four-only changed-profile audit, and profile entitlement negatives prove what this task requested and did not request. No fresh portal authentication or two-factor challenge occurred.

The four iOS identifiers remain defined only in r12 and are the named ADR-024 deferred gap. No iPhone profile was created or checked.

## Reproduction procedure

1. Generate an isolated Xcode project with the four target mappings above. Set `CODE_SIGN_STYLE=Automatic`, `DEVELOPMENT_TEAM=262RZ595FP`, macOS platform, Debug configuration, and the single entitlement shown above.
2. For each target, run `xcodebuild` with the project, target scheme, `-configuration Debug`, `-destination platform=macOS`, `-allowProvisioningUpdates`, and `-allowProvisioningDeviceRegistration`.
3. Locate each downloaded `.provisionprofile` in Xcode's standard user provisioning-profile cache and decode it with `security cms -D -i <profile>`.
4. Parse only the fields recorded in this outcome. Compare the profile device value to `system_profiler`'s Provisioning UDID in memory; persist only the truncated SHA-256 reference.
5. Assert exact team/prefix/application identifier/platform/device/validity, membership of `packet-tunnel-provider`, absence of the suffixed development value and App Groups key, expected profile-only keychain wildcard, and exactly one unique profile UUID per approved bundle ID.
6. Do not attach or commit the raw profiles, decoded CMS payloads, certificates, certificate fingerprints, signing keys, account/session values, or full device identifier.

The temporary project, raw build logs, decoded inspection files, and raw profiles remain under ignored local/Xcode caches and are not board outcomes or Git content.

## Commands and real exit codes

- Required `set_status(... development)`: exit 0.
- XcodeGen project generation and `xcodebuild -list`: exit 0.
- Initial host provisioning build: exit 65 after profile acquisition because the first temporary Swift stub incorrectly combined `main.swift` with `@main`; corrected autonomously.
- Corrected host and the other three profile-bearing builds: each reached the correct named profile, compiled, and then exited 65 at final `codesign` with `errSecInternalComponent`. This is the previously observed unattended login-Keychain access anomaly, not a portal/profile failure. No secret was requested, supplied, or printed.
- Separate all-four-target compile with code signing disabled: exit 0 (`BUILD SUCCEEDED`). Product code and the product build graph were untouched.
- Privacy-safe four-profile validator: exit 0; four changed, zero unexpected, zero failures.
- Entitlements plist lint: exit 0. Inspector Python compile: exit 0. XcodeGen regeneration: exit 0.
- Authoritative r12 matrix validator: 2,862 checks, exit 0.
- Live A1/P1/D1 portal-consumer gate, first invocation from the materialized resource directory: exit 2 because the board root could not be resolved. Correct rerun from the project root: A1 28 checks, P1 20 checks, D1 41 checks, exit 0.
- `git diff --check`: exit 0.
- `task-board validate`: exit 0, no issues.
- Git/status sensitive-artifact gate: zero tracked or pending `.provisionprofile`, `.mobileprovision`, `.p8`, `.p12`, or `.cer` files; exit 0.
- Attached-outcome assertion/privacy gate: all 13 required facts present; zero private-key headers, absolute user paths, credential assignments, or pending sensitive artifacts; exit 0.

Product tests, SwiftUI/Core Data/Go tests, and product lint are not applicable because product code is explicitly out of scope and unchanged. The relevant provisioning inspector, matrix/consumer gates, plist/Python checks, isolated build, diff check, board validation, and privacy gate pass. The final codesigning anomaly is preserved here and in `LOGBOOK.md`; it does not alter the four valid downloaded profiles.
