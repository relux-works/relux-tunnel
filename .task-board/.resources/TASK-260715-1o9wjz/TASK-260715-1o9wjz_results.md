# TASK-260715-1o9wjz developer evidence

## Outcome
Implemented the read-only macOS system-domain Keychain credential resolver and provider composition seam. The resolver uses SecKeychainCopyDomainDefault for the system domain and one SecItemCopyMatching query containing generic-password class, fixed non-identifying service, exact canonical opaque account reference, kSecUseDataProtectionKeychain=false, explicit one-element kSecMatchSearchList, return attributes/data, and match limit one. Static audit confirms no hard-coded System Keychain path, ambient search, enumeration, fallback, add/update/delete call, kSecUseKeychain, access group, accessibility attribute, Codable secret record, logging, or providerConfiguration secret path in the resolver.

The strict protected-record decoder validates magic/version, exact reference and credential generation, private-key/passphrase bounds, optional absent/empty/present passphrase states, digest, truncation, and trailing bytes. Stable redacted outcomes distinguish not provisioned, access denied, wrong class, generation mismatch, malformed record, passphrase required/invalid, unsupported key, and cancellation. Mutable owned record/key/passphrase/digest buffers are cleared best-effort; parsed credentials are retired after libssh2 authentication or cancellation. Immutable Swift, Security-framework, allocator, and parser copies cannot be proven zeroized.

The production format registry remains deliberately fail-closed because TASK-260715-2hhh7x has not assigned reviewed production format IDs. Injected imported/generated registries prove both candidate-neutral external-signer representations without inventing a production identifier.

## Non-secret Keychain evidence
The focused Swift Testing suite creates two throwaway file-based Keychains under the test temporary directory, writes placeholder-only fixture bytes to one, resolves successfully when kSecMatchSearchList contains that exact Keychain, and receives errSecItemNotFound when the identical exact query is scoped to the unrelated Keychain. Both throwaway Keychains are deleted by the harness. The real system-domain Keychain is resolved only to obtain a read-only SecKeychain reference; no real credential item is read, written, enumerated, logged, or attached.

## Gates
- Focused resolver suite: 11 tests, 1 suite, exit 0.
- Combined resolver, SSH contract, libssh2 bridge, and provider suite: 56 tests, 4 suites, exit 0.
- Complete swift test: 403 tests, 33 suites, exit 0.
- make validate-core: dependency verification, boundary guard, complete tests, and swift build, exit 0.
- Recursive swift format lint: exit 0 with no findings.
- Static forbidden-surface scan: PASS, exit 0.
- git diff --check: exit 0.
- task-board validate: exit 0 and reports one parent aggregate anomaly: STORY-260715-2wjwuf is stored backlog while child aggregate is development. No out-of-scope parent mutation was made.

The Xcode SDK emits expected deprecation warnings for the contract-mandated file-based SecKeychain APIs; build and tests pass.