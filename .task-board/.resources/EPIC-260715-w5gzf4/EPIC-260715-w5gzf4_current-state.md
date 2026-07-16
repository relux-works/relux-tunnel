# Current state and migration boundary

Last verified: 2026-07-15.

## What exists

The repository builds one SwiftPM macOS 14 executable, `ReluxProxy`, packaged by
shell scripts as a menu bar `.app` and DMG.

The app:

- stores SSH host, account, and local SOCKS port in `AppStorage`;
- launches `/usr/bin/ssh -N -C -D 127.0.0.1:<port>` with fail-fast, keepalive,
  timeout, batch-mode, and quiet logging options;
- inherits host aliases, keys, ProxyJump, and other behavior from the user's
  `~/.ssh/config`;
- reports connecting, connected, disconnecting, disconnected, and failed states;
- requires the user to configure a browser or other SOCKS-aware client manually;
- intentionally runs outside the App Sandbox so it can spawn system SSH.

Tests cover profile validation and exact SSH argument construction. CI runs
`swift test` and builds an ad-hoc-signed universal application bundle.

Tagged releases import the Relux Works Developer ID certificate, build a
universal app, sign the DMG, notarize and staple it, validate it with Gatekeeper,
publish checksums/provenance, and upload both versioned and stable
`ReluxProxy.dmg` assets.

## What does not exist

The current app is not a system VPN and does not contain:

- iOS targets;
- `NETunnelProviderManager` or packet-tunnel extensions;
- a userspace TCP/IP stack or packetFlow bridge;
- an embedded SSH implementation;
- UDP or system DNS forwarding;
- the remote `relux-relay` executable/protocol;
- shared profile/Keychain state between host and extension;
- Network Extension entitlements or provisioning;
- TestFlight/App Store release automation.

## Migration boundary

The planned product in `.spec/` is a new architecture, not an incremental toggle
inside `TunnelController`. Existing source files remain the current SOCKS
product until board-approved migration tasks create the multi-target project.

During migration:

- the stable macOS release path must remain reproducible;
- current host/account defaults and user expectations need an explicit migration
  decision;
- the system-SSH implementation may remain as a macOS legacy mode, be replaced,
  or be retired only through a product decision;
- SwiftPM tests and release history must not be silently discarded;
- Network Extension code must not be backported into the current manual app
  without the architecture and entitlement gates in `.spec/validation.md`.
