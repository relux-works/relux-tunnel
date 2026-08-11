# Implement the versioned non-secret SSH profile snapshot loader

## Description
Implement the macOS provider-side decoder and validator for the complete bounded non-secret SSHProfileSnapshotV1 carried in NETunnelProviderProtocol.providerConfiguration. Capture one immutable configuration generation and reject malformed, unsupported, incomplete, stale, or unexpectedly changed input before credentials, routes, or packet forwarding are used.

## Scope
In scope: deterministic JSON schema/version/kind validation; 4096-byte providerConfiguration envelope bound including manager metadata; stable profile ID and generation; canonical DNS/IPv4/IPv6 host; port; account; opaque credential reference and generation; approved host identity records; immutable runtime capture; secret-field prohibition; typed privacy-safe errors; Swift Testing fixtures. No App Group read, no Keychain access, no profile mutation. Out of scope: UI, credential resolution, trust decisions, routing, DNS policy, OpenSSH config import, ProxyJump, and iOS.

## Acceptance Criteria
1. The loader consumes the complete SSHProfileSnapshotV1 from providerConfiguration and never reads an App Group. 2. Deterministic JSON bounds, schema/version/kind, duplicate keys, depth, UTF-8, canonical host forms, port, account, credential reference/generation, trust records, and configuration generation are validated fail-closed. 3. Exactly one complete immutable generation is captured for a runtime start; unsupported, malformed, oversized, stale, or replaced input returns a stable error before credentials, routes, or packet forwarding. 4. Decoded models cannot contain private-key or passphrase bytes, and prohibited-field/privacy regression fixtures fail. 5. Swift Testing covers valid host forms, Unicode/malformed names, IPv6, invalid ports, missing trust or credential references, corruption, oversize, duplicate keys, version transitions, generation replacement, and providerConfiguration integration.
