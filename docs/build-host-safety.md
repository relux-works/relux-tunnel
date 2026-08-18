# Build-host safety policy

The current development Mac is permanently **build-only** for this repository.
Its one-way platform-identity fingerprint is registered in
`config/build-only-hosts.sha256`; the raw platform UUID is neither stored nor
printed. This denylist is authoritative and fail-closed.

Allowed locally: source generation, build, compile, lint, unit and integration
tests, the command-line harness, simulators, archive inspection, and unsigned
provider tests that do not reach NetworkExtension preferences or system state.

Prohibited locally:

- installing or opening a VPN containing app or system extension;
- saving, removing, or enabling a real `NETunnelProviderManager` preference;
- calling `startVPNTunnel` or otherwise starting/activating a provider;
- changing routes, interfaces, packet-filter rules, or DNS settings;
- running any physical VPN lifecycle, routing, leak, reconnect, or product
  validation row.

Every macOS task that performs those operations must be blocked by the human
gate `TASK-260819-25e1ys` until a dedicated Mac is provisioned. Agents must not
work around the gate, ask for local GUI approval, or turn a build-host test into
a physical test. These restrictions apply even if local signing credentials or
an older installed probe are present.

## Dedicated-host preflight

Physical scripts execute on the dedicated Mac (normally through an operator's
remote session), not on the build host. Before bundle inspection or lifecycle
exercise, the runner requires:

```sh
export RELUX_PHYSICAL_TEST_OPT_IN=dedicated-mac-only
export RELUX_PHYSICAL_TEST_HOST=the-dedicated-mac-hostname
scripts/physical-test-host-preflight.sh
```

The configured name must identify the Mac executing the command, cannot be a
localhost alias or loopback address, and the executing Mac's hashed platform
identity must not appear in the build-only denylist. Missing identity evidence,
missing opt-in, unreadable policy, or any mismatch fails closed. Passing this
technical guard does not replace the unfinished human gate or authorize
credentials, installation, or GUI approval by an agent.

The preflight's negative tests use synthetic names and fingerprints only. They
do not install, save, activate, start, route, resolve, or modify DNS/VPN state.
