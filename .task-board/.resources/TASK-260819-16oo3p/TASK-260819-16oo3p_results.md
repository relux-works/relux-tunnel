# TASK-260819-16oo3p results

## Outcome

Implemented a fail-closed build-host policy and closed the reviewer-reported denylist bypass. The production preflight now always uses the repository-owned config/build-only-hosts.sha256; RELUX_BUILD_ONLY_HOSTS_FILE cannot replace it. Synthetic denylist injection exists only as an explicit argument to the pure validation function used by tests.

The current development Mac is documented and registered build-only by a one-way IOPlatformUUID fingerprint. Authoritative instructions prohibit installing or opening a VPN app/system extension, saving or removing real NetworkExtension preferences, calling startVPNTunnel, activating a provider, and mutating routes or DNS locally. Builds, compilation, lint, unit/integration tests, harnesses, archive inspection, and unsigned-provider tests remain allowed.

## Review rework

Independent review reproduced an exit-0 bypass with RELUX_BUILD_ONLY_HOSTS_FILE=/dev/null. The production override was removed and an entrypoint regression now repeats that attempt with the current hostname and requires the repository build-host guard to reject it. The reviewer verdict is preserved in TASK-260819-16oo3p_reviewer-verdict.md, the task was routed back to development, and the remediation was recorded in .planning/EPIC-260716-3fyjn0_logbook.md.

## Dependency audit

Board API verification confirms all 19 active M1-M5 macOS network-mutating physical validation and release tasks directly depend on human gate TASK-260819-25e1ys. M0 command-line harness work remains local-safe. task-board validate: exit 0.

## Validation

- Probes/macOSPacketTunnelProbe/Scripts/test-physical-gate-p0.sh: exit 0. Covers absent opt-in, empty host, localhost aliases, IPv4 and IPv6 loopback, registered build-host fingerprint, runtime-host mismatch, a synthetic dedicated-host pass, guarded runner entrypoints, and the denylist-override regression.
- bash -n for all changed shell scripts: exit 0.
- shellcheck for all changed shell scripts: exit 0.
- git diff --check: exit 0.
- make core-test core-build: exit 0. Swift Testing ran 443 tests in 37 suites with 25 recorded known issues for the pre-existing unavailable ReluxNIOSSH adapter; swift build passed.
- task-board validate: exit 0.

## Safety evidence

No command installed or opened an application or system extension, accessed/saved/removed real NetworkExtension preferences, called startVPNTunnel, activated a tunnel/provider, or mutated routes or DNS. Tests exercised pure validation and fail-before-operation entrypoints only. No physical VPN validation ran on this build host.