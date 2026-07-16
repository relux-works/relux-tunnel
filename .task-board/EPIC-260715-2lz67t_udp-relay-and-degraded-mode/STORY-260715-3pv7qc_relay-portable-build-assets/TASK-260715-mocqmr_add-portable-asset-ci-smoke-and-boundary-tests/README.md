# Add portable asset CI smoke and runtime-boundary tests

## Description
Create the automated four-target gate that builds relay assets and verifies architecture, rootless stdio behavior, handshake or identity, self-hash, manifest consistency, diagnostics separation, resource cleanup, and absence of forbidden runtime modes.

## Scope
In scope: four target jobs; native execution where available and documented emulation otherwise; binary format and architecture inspection; unprivileged user; read-only working directory where feasible; version, self-hash, and stdio handshake smoke; stdout contamination sentinel; stderr redaction; unsupported arguments; EOF and signal exit; listener or child-process checks; manifest tampering; artifact and log retention. Out of scope: remote SSH upload, live destination UDP, physical iPhone traffic, App Store signing, public network scans, and treating emulation as the only release evidence for a target with required native runners.

## Acceptance Criteria
1. CI builds all four target assets from clean pinned inputs and verifies binary format, architecture, nonzero size, manifest size and hash, protocol version, and build identity. 2. Each executable runs as an unprivileged user, performs the supported stdio smoke, reports a matching self-hash, and exits on EOF or termination without leftover process, file, or listener state. 3. Tests fail any framed-stdout contamination, payload-like stderr output, daemon or public listener behavior, privilege requirement, system-path write, or unsupported command acceptance. 4. Missing runner support is an explicit red gate with owner and evidence requirement rather than an automatic pass from cross-compilation alone. 5. Job outputs record target, runner or emulator, revisions, commands, durations, hashes, exit codes, and privacy-safe failures and retain the four gated artifacts.
