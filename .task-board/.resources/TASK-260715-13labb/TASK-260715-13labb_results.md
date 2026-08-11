# TASK-260715-13labb developer handoff evidence

## Outcome
Implemented the macOS-only SSH bootstrap error boundary with public CustomNSError domain sshProfileBootstrap, stable string and integer codes, fixed stages, finite user-action categories, terminal/retryableLater/cancelled disposition, typed privacy-safe internal causes, and bounded endpoint-family and reviewed-algorithm context. Runtime diagnostics now retain only the latest structured bootstrap projection for the active generation. No reconnect behavior was added.

## Taxonomy
Stages: profileLoad, physicalPathResolution, endpointConnect, algorithmNegotiation, hostVerification, credentialAccess, publicKeyAuthentication, cancellation, sessionClose.

Profile, host-policy, credential, and authentication configuration/trust gates are terminal. Host mismatch and malformed host evidence collapse to hostPolicyRejected; unsupported algorithms use hostKeyAlgorithmUnsupported. Cancellation and explicit user stop use operationCancelled and userStopped with cancelled disposition. Only bounded timeouts, path unavailability, connection reset/abort, temporary resource exhaustion, and later-stage transport interruption are retryableLater. Connection refusal, corrupt profile, inaccessible credential, host change/revocation/mismatch, unsupported host key, and authentication rejection are terminal. Classification is recorded for M3 and does not schedule retries.

Public NSError userInfo contains only stage, code, configurationGeneration, userAction, retryDisposition, and optional endpointFamily/algorithm. It has no NSUnderlyingErrorKey, localized platform prose, hostname/address/account/profile or credential reference, fingerprint/raw key, Keychain path, banner, command, destination, payload, or stack trace. Unknown/hostile algorithm names collapse to unsupported.

## Tests and validation
- SSHBootstrapErrorMappingTests: 10 tests, exit 0. Covers golden taxonomy, every stage, terminal gates, transient allowlist, typed internal cause, cancellation/user stop, authentication-stage timeout/transport precedence, hostile underlying text, prohibited data, POSIX/URL classes, and runtime snapshot round trip/clear.
- Focused macOS plus selected libssh2 evidence: 6 tests across 3 suites, exit 0. Covers OSStatus, NWError/POSIX, injected resolution/connect/KEX timeouts, and live authentication timeout.
- RuntimeDiagnosticsTests after schema allowlist update: 9 tests, exit 0.
- Initial make validate-core: exit 2 because the existing runtime snapshot reflection allowlist did not yet include sshBootstrapError. The allowlist was updated; no production behavior was weakened.
- Final make validate-core: exit 0. Core boundaries, native fixture verification, libssh2 fork/artifact verification, all 425 Swift tests in 35 suites, and swift build passed.
- swift format lint --recursive Sources Tests Package.swift: exit 0.
- bootstrap forbidden error-prose static scan: exit 0, PASS.
- git diff --check: exit 0.
- task-board validate: exit 0 and reports the pre-existing STORY-260715-2wjwuf stored-backlog versus child-development aggregate mismatch. No out-of-scope parent mutation was made.

The accepted file-based SecKeychain APIs continue to emit their pre-existing SDK deprecation warnings; no new compile warning remains. Important mapping-precedence findings and the board anomaly are recorded in LOGBOOK.md.