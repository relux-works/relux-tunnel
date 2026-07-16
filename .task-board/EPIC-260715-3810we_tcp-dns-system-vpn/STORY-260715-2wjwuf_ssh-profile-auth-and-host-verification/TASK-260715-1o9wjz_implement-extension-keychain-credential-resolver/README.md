# Implement the packet-extension Keychain credential resolver

## Description
Implement least-privilege retrieval of the selected private key and optional passphrase from the shared Data Protection Keychain access group using only opaque references from the validated profile. Bound secret lifetime, prevent logging or serialization, and return stable access and format errors.

## Scope
In scope: SecItem query abstraction, approved access group and accessibility class from M0 identifiers, item identity and type validation, imported and generated key representations supported by the selected engine, optional passphrase retrieval, cancellation, scoped secret container, best-effort buffer clearing, and provider-context tests. Out of scope: key import or generation, Keychain UI, password auth, biometric interaction that cannot run in the provider, credential sync, exporting keys, and engine selection.

## Acceptance Criteria
1. The resolver queries only the approved shared access group and exact opaque references and cannot enumerate or fall back to unrelated items. 2. Missing, inaccessible, wrong-class, malformed, passphrase-required, and unsupported-key items return distinct privacy-safe errors before authentication begins. 3. Secret values are never placed in App Group data, providerConfiguration, logs, metrics, crash annotations, Codable models, test snapshots, or task resources. 4. Secret containers have a bounded lexical or asynchronous lifetime and release or overwrite mutable buffers where the selected API permits, with limitations documented. 5. Unit and provider-context tests prove host access succeeds where intended, unrelated processes or access groups fail, cancellation releases values, and redaction catches accidental interpolation.
