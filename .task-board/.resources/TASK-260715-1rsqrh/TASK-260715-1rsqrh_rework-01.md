# TASK-260715-1rsqrh rework 01

Address the blocking production-boundary finding in `TASK-260715-1rsqrh_review.md` without weakening the accepted lifecycle/error contract.

Required changes:

- Normalize synchronous `NETunnelProviderSession.startTunnel(options:)` errors in both iOS and macOS `VPNHostSession` adapters before they cross into `VPNSessionController`.
- Known public `NEVPNError` values must map to the existing stable start results exactly: `configurationInvalid`, `configurationDisabled`, and `connectionFailed`.
- Preserve the original domain and integer code for every unknown/non-NEVPN error so the controller returns the accepted `platformRejected(domain, code)` result; never replace them with reflected Swift type names or code zero.
- Keep the shared controller platform-neutral. Prefer the existing `VPNPreferencePlatformError`/stable translator surface or a small shared injectable normalization seam; do not import NetworkExtension into Core.
- Add deterministic tests at both Apple adapter boundaries, not only a fake Core session: cover the three known `NEVPNError` cases and an unknown NSError with exact domain/code preservation on iOS and macOS.
- Add coverage for a freshly loaded exact-owned but disabled production-manager path, proving start fails as `configurationDisabled` without calling the system start API.
- Preserve all accepted authority, deadline, generation, cancellation, observer-retirement, and race behavior from the producer handoff.
- Rerun focused normal and TSan tests, full `make validate-core`, strict formatting/diff/board checks, and sequential iOS/macOS adapter builds. Attach task-scoped rework evidence and return to `to-review`; do not self-accept.
