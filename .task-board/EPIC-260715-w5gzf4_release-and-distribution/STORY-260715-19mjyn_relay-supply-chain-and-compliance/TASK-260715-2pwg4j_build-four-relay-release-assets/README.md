# Build the four declared relay release assets

## Description
Produce release-mode relux-relay executables for Linux x86_64, Linux arm64, macOS x86_64, and macOS arm64 from the pinned build environments with unique deterministic names and metadata.

## Scope
In scope: clean release builds, four declared targets, optimization and strip policy, generated protocol constants, rootless executable permissions, stdio-only boundary, build identity and self-hash commands, unique file names, expected binary formats and architecture slices, size ceilings, and build logs. Out of scope: universal macOS merging unless the contract requires it, Apple application bundling, remote installation, code signing, notarization, and publishing.

## Acceptance Criteria
1. One clean command emits exactly one executable for each declared OS and architecture and no undeclared or ambiguously named release asset. 2. Binary inspection confirms target format and architecture, entrypoint, executable permissions, expected linked libraries, absence of public listener or daemon packaging, and configured size ceiling. 3. Each executable reports the expected protocol and privacy-safe build identity and its self-hash agrees with the external SHA-256 path. 4. Build logs record all pinned inputs and commands without host-specific paths, credentials, or unbounded nondeterministic data. 5. Missing targets, duplicate names, wrong architecture, unexpected dynamic linkage, identity mismatch, oversize output, or extra release files fail the build.
