# TASK-260715-9yp8to — physical Gate P0 runbook

Run only on an authorized Apple-silicon development Mac in its logged-in GUI
session. Do not attach raw provisioning profiles, device identifiers,
certificate fingerprints, private-key material, passwords, or unfiltered
system logs.

## 1. Build and preflight

From the repository root, run the checked-in build from an Aqua Terminal if
the login-Keychain signing key is unavailable to a background shell:

```bash
Probes/macOSPacketTunnelProbe/Scripts/build-and-inspect.sh
PROBE_PHYSICAL_OUTPUT_ROOT=.temp/TASK-260715-9yp8to/preflight \
  Probes/macOSPacketTunnelProbe/Scripts/physical-gate-p0.sh preflight
```

Both commands must exit 0. Confirm both signed products have App Sandbox, exact
`packet-tunnel-provider`, and no App Groups or Keychain Sharing entitlement.

## 2. Install and verify PlugInKit registration

Use either the administrator-approved `/Applications` path or the authorized
user Applications path. The successful reference run used:

```bash
mkdir -p "$HOME/Applications"
ditto \
  .temp/TASK-260715-1r0fxv/ReluxPacketTunnelProbe.xcarchive/Products/Applications/ReluxPacketTunnelProbe.app \
  "$HOME/Applications/ReluxPacketTunnelProbe.app"
Probes/macOSPacketTunnelProbe/Scripts/inspect-archive.sh \
  "$HOME/Applications/ReluxPacketTunnelProbe.app"
open "$HOME/Applications/ReluxPacketTunnelProbe.app"
pluginkit -m -A -D -v -i works.relux.tunnel.probe.mac.tunnel
```

Approve the VPN configuration if macOS asks. PlugInKit must report exactly one
provider at the installed app's embedded `Contents/PlugIns` path.

## 3. Run ten cycles

```bash
PROBE_PHYSICAL_OUTPUT_ROOT=.temp/TASK-260715-9yp8to/ten-cycle \
PROBE_CYCLE_TIMEOUT_SECONDS=300 \
  Probes/macOSPacketTunnelProbe/Scripts/physical-gate-p0.sh exercise \
  "$HOME/Applications/ReluxPacketTunnelProbe.app" 10
```

Expected exit: 0. The summary must contain ten passed cycles,
`managerCount=1`, and `providerProcessCount=0` for every host termination.

## 4. Controlled reinstall

Quit the exact host, verify the provider is absent, and move the installed app
to a resolved, task-scoped backup path before restoring the same inspected
archive. Do not use a broad or unresolved deletion target.

```bash
pkill -TERM -f '^.*/ReluxPacketTunnelProbe.app/Contents/MacOS/ReluxPacketTunnelProbe$' || true
mkdir -p .temp/TASK-260715-9yp8to/reinstall-backup
mv "$HOME/Applications/ReluxPacketTunnelProbe.app" \
  .temp/TASK-260715-9yp8to/reinstall-backup/ReluxPacketTunnelProbe.first-pass.app
ditto \
  .temp/TASK-260715-1r0fxv/ReluxPacketTunnelProbe.xcarchive/Products/Applications/ReluxPacketTunnelProbe.app \
  "$HOME/Applications/ReluxPacketTunnelProbe.app"
Probes/macOSPacketTunnelProbe/Scripts/inspect-archive.sh \
  "$HOME/Applications/ReluxPacketTunnelProbe.app"
open "$HOME/Applications/ReluxPacketTunnelProbe.app"
pluginkit -m -A -D -v -i works.relux.tunnel.probe.mac.tunnel
PROBE_PHYSICAL_OUTPUT_ROOT=.temp/TASK-260715-9yp8to/reinstall-cycle \
  Probes/macOSPacketTunnelProbe/Scripts/physical-gate-p0.sh exercise \
  "$HOME/Applications/ReluxPacketTunnelProbe.app" 1
```

The final commands must again show one PlugInKit match, one manager, a clean v1
message/stop, and no provider process.

## 5. Local validation

```bash
bash -n Probes/macOSPacketTunnelProbe/Scripts/*.sh
shellcheck -x Probes/macOSPacketTunnelProbe/Scripts/physical-gate-p0.sh \
  Probes/macOSPacketTunnelProbe/Scripts/test-physical-gate-p0.sh
Probes/macOSPacketTunnelProbe/Scripts/test-physical-gate-p0.sh
Probes/macOSPacketTunnelProbe/Scripts/test-log-redaction.sh
Probes/macOSPacketTunnelProbe/Scripts/test-inspector-drift.sh \
  .temp/TASK-260715-1r0fxv/ReluxPacketTunnelProbe.xcarchive/Products/Applications/ReluxPacketTunnelProbe.app
```

Attach only privacy-scanned focused logs, summaries, metadata, requirements,
coverage, and registration output.

