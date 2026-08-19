# TASK-260715-mocqmr build-host implementation contract

Implement the four-target relay asset CI smoke and runtime-boundary gate exactly as specified by the task and accepted relay contracts.

## Required behavior

- Start from the accepted pinned toolchain, exact four-asset archive/manifest, supply-chain provenance, and cross-language protocol fixtures already in the repository.
- Build or validate all four target assets from clean pinned inputs.
- Verify format, architecture, non-zero size, exact manifest hash/size, protocol version, build identity, self-hash, stdio handshake, stdout/stderr separation, EOF/signal cleanup, unprivileged execution, unsupported arguments, and absence of daemon/public-listener/system-write/child-process residue.
- Preserve native-versus-emulated evidence honestly. Emulation may add evidence but cannot be recorded as native execution. Missing required native runner support must fail red with a named owner and evidence requirement.
- Retain privacy-safe per-target evidence and exact gated artifacts without credentials, private keys, host-specific paths, mutable URLs, or payload data in logs.
- Add deterministic local tests for workflow/scripts so the implementation can be reviewed on this build host without relying solely on a remote CI result.

## Build-host safety

This Mac is permanently build-only. Allowed: unsigned builds, static inspection, local rootless relay subprocesses in bounded test fixtures, process/file/socket observation, and emulation that does not alter host networking.

Forbidden: signing, installing or launching an app/provider, NetworkExtension preferences, `startVPNTunnel`, real VPN activation, route/interface/pf/DNS mutation, public listeners, remote destination traffic, or physical VPN validation. Do not weaken `docs/build-host-safety.md` or work around `TASK-260819-25e1ys`.

## Delivery

- Exercise behavior, not only static workflow text.
- Run focused and relevant regression suites.
- Attach task-scoped outcome evidence and hand off to fresh independent review; do not mark the task done as producer.
