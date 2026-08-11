# Active macOS system-Keychain resolver scope

Binding inputs:

- `TASK-260728-7ii1xz_macos-credential-transport-decision.md` revision 2 is accepted and supersedes the stale shared Data Protection Keychain/App Group wording for macOS.
- `TASK-260715-29ws8l_profile-trust-credential-contract.md` is the accepted profile/trust/credential boundary. Secrets remain provider-only; no secret value may enter providerConfiguration, logs, shell, board evidence, or Codable/public message models.
- macOS only; iOS is deferred. libssh2 is the selected primary SSH engine, but this task exposes a candidate-neutral credential result.

Implementation constraints:

1. Resolve the file-based system-domain keychain with `SecKeychainCopyDomainDefault(kSecPreferencesDomainSystem, ...)`; never hard-code `/Library/Keychains/System.keychain`.
2. Read through `SecItemCopyMatching` with `kSecUseDataProtectionKeychain=false`, an explicit `kSecMatchSearchList` containing only the resolved system-domain keychain, a fixed non-identifying service constant, and the exact opaque credential reference. Never enumerate, use the ambient search list, fall back, add `kSecAttrAccessGroup`, or add `kSecAttrAccessible`.
3. `kSecUseKeychain` is add-only and does not belong in the resolver query. `startTunnel` is read-only: a miss fails immediately with `credentialNotProvisioned`; no seeding, polling, prompt, or wait is allowed.
4. Use an injected Security-framework seam so query shape, OSStatus mapping, cancellation, secret lifetime, and negative search-list controls are exercised deterministically with Swift Testing. The accepted E10 throwaway-keychain harness is a valid non-root template; do not touch or reveal real credential items.
5. Document best-effort clearing limitations honestly. Evidence must contain only schema/query-shape assertions, statuses, counts, and redacted diagnostics—never secret material or identifying Keychain attributes.
6. Align stale macOS statements in `.spec/security-privacy.md` if needed, while preserving iOS Data Protection Keychain semantics as deferred platform-specific behavior.

Physical signed-provider persistence and sandbox validation belongs to the downstream physical task; do not block this implementation on it and do not claim it was exercised here.
