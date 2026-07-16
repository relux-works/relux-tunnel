# Build the four declared portable relay assets

## Description
Produce the bundle-ready relay binaries for Linux x86_64, Linux arm64, macOS x86_64, and macOS arm64 using the pinned path, with unique names, verified machine types, declared linkage, and target-baseline execution evidence.

## Scope
In scope: clean release-mode builds; protocol-enabled relay source; unique normalized file names; executable permissions for staging; binary architecture and format inspection; strip and debug-symbol policy; minimum macOS and Linux or libc compatibility; linkage inventory; file-size budget; controlled target smoke; artifact retention and hashes. Out of scope: universal binaries unless explicitly chosen, application bundle manifest, remote upload, code signing or notarization, Docker images as product artifacts, UDP end-to-end traffic, and unsupported operating systems.

## Acceptance Criteria
1. Exactly one nonempty executable is produced for each declared OS and architecture tuple and automated inspection confirms its binary format and machine architecture. 2. Asset names, protocol version, build mode, minimum runtime, dynamic library requirements, and debug-symbol disposition are unambiguous and recorded. 3. Each asset starts and exits successfully as an unprivileged user on its baseline native or approved emulated fixture and reports the expected build identity. 4. File sizes remain below the recorded bundle budget or the task reports measured impact and obtains an updated explicit budget before handoff. 5. Build logs and retained artifacts contain no developer paths, credentials, signing material, real host data, or undeclared runtime dependencies.
