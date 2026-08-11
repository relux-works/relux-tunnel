# TASK-260715-3f4lxy schema evidence

Accepted input: `TASK-260715-29ws8l_profile-trust-credential-contract.md`, SHA-256 `8c81d2dc15904d6648f1333620370ac2c8c455e081fe6e98b4480a92c64bd5f2` (verified locally before implementation and rework).

## Provider configuration envelope

The loader accepts exactly the existing owner marker, signed manager-contract v1 marker, and `works.relux.tunnel.configuration-reference` containing the complete canonical snapshot JSON. The exact three-key binary property-list envelope, including manager metadata, must be at most 4096 bytes. Missing, extra, wrong-type, old, future, or oversized input fails closed.

## SSHProfileSnapshotV1

The envelope is exactly `protocolVersion=1`, `kind=sshProfileSnapshot`, and `schemaVersion=1`. Validation covers canonical lowercase profile UUID, configuration generation at least 1, UTC millisecond timestamps, NFC display/account strings, canonical DNS/IPv4/IPv6 host, port 1...65535, opaque canonical credential UUID and generation, ordered approved host-key algorithms, and bounded canonically ordered trust records.

JSON must be UTF-8 deterministic sorted-key encoding with canonical strings and numbers, no insignificant whitespace, no duplicate keys, no trailing bytes, and maximum depth 8. Canonical unknown fields are validated, ignored, and dropped on re-encode.

The recursive privacy scan normalizes case and punctuation to lowercase alphanumerics, then applies a bounded prohibited-root plus fixed semantic-suffix policy for private-key, seed, passphrase, decrypted-key/private-key, key-byte, raw-host-key, password, and staging-credential families. Nested case and punctuation fixtures cover `privateKeyMaterial`, `privateKeyData`, `passphraseBytes`, `passwordValue`, `seedBytes`, `decryptedPrivateKey`, and `stagingCredentialPayload`.

## Runtime start request and immutable capture

A present start request contains exactly five fields: `protocolVersion`, `schemaVersion`, `kind`, `configurationGeneration`, and `snapshotDigestSHA256`. Versions are 1, kind is `sshProfileSnapshotStart`, generation is at least 1, and the digest is exactly 64 lowercase hexadecimal SHA-256 characters. The request is bounded to 4096 bytes and rejects additive fields.

The host-side request helper hashes the exact canonical snapshot bytes stored in provider configuration. Before the first capture, the provider compares both generation and digest against those exact stored bytes. Any mismatch returns `profileGenerationMismatch`; nil start options may capture the validated stored snapshot. Once captured, only byte-identical rereads return the immutable value.

## Stable loader errors

- `profileOversize`
- `profileCorrupt`
- `profileVersionUnsupported`
- `profileInvalidField` with a fixed non-sensitive field token
- `profileGenerationMismatch`
- `profileContainsProhibitedField`

## Implementation locations

- `Sources/ReluxTunnelCore/SSHProfileSnapshot.swift`
- `Sources/ReluxTunnelCore/RuntimeMessageModels.swift`
- `Sources/ReluxTunnelCore/VPNSessionController.swift`
- `Sources/ReluxTunnelMacOSAdapter/MacOSSSHProfileSnapshotLoader.swift`
- `Tests/ReluxTunnelCoreTests/SSHProfileSnapshotLoaderTests.swift`
- `Tests/ReluxTunnelCoreTests/RuntimeMessageCodecTests.swift`

The loader boundary contains no App Group, Keychain, secret-bearing model, route, network, packet-forwarding, or profile-write API.