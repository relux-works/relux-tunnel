# Security policy

## Reporting a vulnerability

Do not open a public issue containing a vulnerability, private key, host
fingerprint, traffic capture, or signing credential. Report security concerns
privately to the Relux Works repository maintainers through GitHub Security
Advisories for `relux-works/relux-proxy`.

Include the affected commit/version, platform and OS version, reproduction steps,
impact, and only the minimum redacted logs needed. Do not include real user
traffic or production credentials.

## Supported state

The released macOS SOCKS application is the only currently implemented product.
The VPN architecture under `.spec/` is pre-implementation and has no supported
binary yet. Security reports about design flaws in the specifications are still
welcome and should reference the relevant document/decision.

## Security invariants for planned work

- SSH host-key verification cannot be disabled silently.
- Private keys/passphrases stay in Keychain and out of logs/configuration files.
- Ordinary DNS cannot fall back outside an advertised connected VPN mode.
- Remote relay binaries are verified before execution and never require a public
  listening port.
- No private Apple APIs, utun descriptor discovery, or hidden entitlement bypass
  is accepted.
- VPN traffic payloads and destinations are not telemetry.

See `.spec/security-privacy.md` for the full threat model and privacy contract.
