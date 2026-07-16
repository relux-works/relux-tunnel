# Implement versioned runtime configuration and message models

## Description
Implement candidate-neutral shared Swift models and codecs for the non-secret provider configuration reference, start request, commands, capability snapshot, lifecycle snapshot, diagnostics snapshot, and protocol errors defined by the runtime contract.

## Scope
In scope: explicit schema versions, Codable or equivalent deterministic encoding, size bounds, unknown-field tolerance, unsupported-version rejection, opaque profile and Keychain reference identifiers, capability booleans, lifecycle state, redacted errors, and unit-test fixtures. Out of scope: raw secrets, profile editing, NETunnelProviderManager persistence, transport implementation, UI rendering, and compatibility with undocumented legacy payloads.

## Acceptance Criteria
1. Every message has a documented version, maximum encoded size, required fields, defaults, and stable error for unsupported input. 2. Configuration contains only non-secret identifiers and opaque references, with tests proving private-key and passphrase bytes cannot be represented. 3. Capability snapshots independently represent TCP, safe DNS, UDP, route mode, and runtime health without falsely claiming M2 full mode. 4. Round-trip, unknown-field, corrupt-payload, oversize, and old or future version tests are deterministic. 5. The models compile for ReluxTunnelCore, both hosts, and both providers without platform-specific transport types leaking into shared code.
