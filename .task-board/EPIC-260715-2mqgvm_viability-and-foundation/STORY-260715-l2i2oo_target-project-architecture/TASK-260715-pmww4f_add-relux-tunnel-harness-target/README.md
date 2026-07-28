# Add the ReluxTunnelHarness macOS CLI target

## Description
Create the fast macOS command-line harness target that hosts ReluxTunnelCore components for packet, SSH, relay, fault-injection, and metric experiments without requiring a Network Extension lifecycle for every iteration.

## Scope
In scope: CLI target and stable subcommand registry; structured configuration input; dependency injection; cancellation and signal handling; privacy-safe structured metrics output; deterministic seed and run metadata; temporary-resource cleanup; extension-equivalent core composition. Out of scope: implementing packet bridge or SSH commands, product profile UX, privileged networking, production credentials, and behavior that cannot later run inside the provider.

## Acceptance Criteria
1. ReluxTunnelHarness builds via SPM as a standalone macOS executable (NO generated Xcode/Tuist workspace required — that workspace is gated behind Gate P0 only; Gate A0 is deferred off this path under ADR-013 and remains required before App Store distribution) and links the same ReluxTunnelCore products intended for the providers. 2. A no-op smoke command records source revision, dependency revisions, configuration, duration, platform, and metric schema in deterministic machine-readable output. 3. Signal cancellation and normal exit release temporary files, sockets, and tasks with tested exit codes. 4. Subcommands can inject clocks, transports, packet endpoints, pressure signals, and fault policies without importing app UI. 5. Swift Testing covers argument validation, result-schema versioning, cancellation, and cleanup.
