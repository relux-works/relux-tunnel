# TASK-260715-1ue4oy build-host-safe implementation contract

Implement the deterministic relay asset manifest and typed read-only Apple lookup on the accepted relay bundle foundation.

Authoritative inputs and boundaries:

- `TASK-260715-24icoz` is accepted. Its board-owned archive SHA-256 is `1f0ba226ed591d1baf5f9464b33e45b7658a33bf5a1a114e77b6d22d3d9eef4e` and contains exactly the four canonical Darwin/Linux amd64/arm64 executables. Consume or deterministically materialize those exact accepted bytes; do not silently substitute a current-HEAD rebuild.
- Preserve the retained executable build identity/provenance reference. A current checkout/source mismatch must remain explicit and fail closed where provenance validation is required; direct byte validation must not be mislabeled as current-source provenance.
- Generate stable schema-versioned ordering and compute size/SHA-256 from exact bundled bytes. Reject missing, extra, renamed, duplicate, zero-length, hash/protocol/identity mismatch, unsupported tuple, and unparseable manifest/resource inputs.
- Normalize the documented handoff values for macOS/Linux and x86_64/amd64/aarch64/arm64 into exactly four supported tuples. Remote `uname` execution/parsing and upload remain out of scope.
- The Apple-side API must expose immutable typed lookup with no caller-supplied path, mutable manifest injection, network fetch, secret handling, or user-facing proxy behavior.
- Include/compile the generated resource in both Apple product graphs using the existing SPM/generated-workspace boundaries. Do not recouple core development to A0/P0 or require a signed/running extension.
- Add deterministic regeneration, tamper/negative, tuple normalization, resource-inclusion, and typed lookup tests. Exercise behavior, not only snapshots.

Build-host safety is mandatory: do not sign, install, approve, configure, or launch a VPN app/provider; do not call `startVPNTunnel`; do not modify NetworkExtension preferences, routes, DNS, or system VPN state. Builds, SPM tests, generated-workspace compilation, rootless relay binaries, and harness tests are allowed.

Attach task-scoped outcome evidence and hand off to a fresh reviewer. Never mark the task done without reviewer acceptance.
