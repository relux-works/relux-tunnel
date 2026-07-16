# Implement the versioned non-secret SSH profile snapshot loader

## Description
Implement the extension-side loader and validator for atomically published App Group SSH profile snapshots. Resolve an opaque profile identifier to one immutable generation and reject malformed, unsupported, incomplete, stale, or unexpectedly changed data before credentials, routes, or packet forwarding are used.

## Scope
In scope: schema version, stable profile ID and generation, display name, canonical host or literal address, port, account, opaque key and passphrase references, approved host identity records, atomic file or store read, size bounds, normalization, validation errors, and test fixtures. Out of scope: editing or writing profiles in the provider, raw private keys, DNS resolver policy, trust UI, OpenSSH config import, ProxyJump, and migration of legacy SOCKS preferences.

## Acceptance Criteria
1. Hostnames are canonicalized with a documented IDNA and case policy, literal IPv4 and IPv6 addresses parse unambiguously, ports are valid, and account plus key reference are required. 2. Loader accepts one complete supported generation or returns a stable error without partially applying fields. 3. Snapshot reads are atomic, size-bounded, immutable for a runtime generation, and detect unsupported versions or generation replacement. 4. Decoded models cannot contain raw private-key or passphrase fields and prohibited-key regression fixtures fail. 5. Unit tests cover valid host forms, Unicode and malformed names, IPv6 syntax, invalid ports, missing trust or credential references, corruption, oversize, and version transitions.
