# TASK-260715-pmww4f — ReluxTunnelHarness implementation evidence

## Delivered scope

- Added the standalone SwiftPM executable product and target
  `ReluxTunnelHarness`; no Tuist/Xcode workspace is generated or required.
- Added `ReluxTunnelHarnessSupport`, linked directly to `ReluxTunnelCore`, with
  a stable validated subcommand registry and provider-equivalent
  `TunnelRuntimeContext` composition.
- Added versioned JSON configuration from `--configuration` or
  `--configuration-json`. The document supplies a deterministic seed, source
  revision, dependency revisions, and privacy labels.
- Added deterministic sorted-key JSON result encoding with result schema 1,
  metric schema 1, redacted configuration, duration, platform, and metrics.
- Added injectable Core clock/metrics/logger/cancellation/pressure dependencies,
  SSH transport factory, packet endpoint factory, and fault policy.
- Added SIGINT/SIGTERM cancellation mapping (exit 130/143) and a LIFO resource
  scope for managed tasks, Unix datagram descriptors/paths, files, and temporary
  directories.
- Added README usage/schema/privacy/exit-code documentation and extended the
  dependency/import guard to fail if the harness imports UI/NetworkExtension or
  stops linking `ReluxTunnelCore`.

## Swift Testing evidence

Clean-run sequence:

1. `swift package clean` — exit 0.
2. `swift test` — exit 0; 12 tests in 2 Swift Testing suites passed. Harness
   coverage includes argument validation, configuration schema rejection,
   deterministic result and metric schemas, privacy redaction, normal cleanup,
   signal-cancelled cleanup and exit code 143, all injection seams, and the
   provider-equivalent composition path.
3. `swift build --product ReluxTunnelHarness` — exit 0.
4. `swift build` — exit 0.

Additional validation:

- `swift format lint --recursive Sources Tests Package.swift` — no diagnostics.
- `shellcheck scripts/check-core-boundaries.sh` — exit 0.
- `make check-core-boundaries` — `ReluxTunnelCore dependency and import boundaries are valid`.
- `git diff --check` — exit 0.
- `task-board validate` — `Board is valid. No issues found.`
- `/tmp/relux-smoke-*` and `/tmp/relux-test-*` leak scan after tests/smoke — no
  remaining directories.
- Running `.build/debug/ReluxTunnelHarness` without arguments returns usage exit
  code 64 and lists the stable `smoke` subcommand.

## Standalone smoke evidence

Executed `swift run ReluxTunnelHarness smoke --configuration-json ...` directly
from SwiftPM at repository HEAD `12bb53c226f3278ba9d808312573345d54dcc396`.
The package currently has no external dependencies, so the recorded dependency
revision map is empty. The worktree contains this uncommitted task change; no
claim is made that the HEAD hash alone identifies those uncommitted bytes.

Exit code: 0

```json
{"command":"smoke","configuration":{"parameters":{"destination":"<redacted>","mode":"noop"},"profileReference":"<redacted>"},"dependencyRevisions":{},"durationNanoseconds":984541,"metrics":{"counters":{"harness.smoke.runs":1},"gauges":{},"schemaVersion":1},"platform":{"architecture":"arm64","operatingSystem":"macOS","operatingSystemVersion":"Version 26.5 (Build 25F71)"},"schemaVersion":1,"seed":260715,"sourceRevision":"12bb53c226f3278ba9d808312573345d54dcc396","status":"succeeded"}
```

The sensitive profile and destination fixture strings do not appear in the
machine-readable result.

## Finding recorded in the M0 logbook

macOS's per-user temporary directory under `/var/folders` can make an otherwise
short Unix socket exceed `sockaddr_un.sun_path`. The harness uses a short,
collision-safe `/tmp` lexical workspace and cleans resources in task/socket/
directory order. This does not change the ADR-003 provider packet-bridge design.
