# TASK-260715-pmww4f — Review evidence (accepted)

Independent reviewer verification at working tree with uncommitted harness change (HEAD 12bb53c).

## Commands re-run by reviewer

- `swift test` — exit 0; 12 tests in 2 Swift Testing suites passed (harness + provider adapter contracts).
- `swift build --product ReluxTunnelHarness` — exit 0.
- `make check-core-boundaries` — "ReluxTunnelCore dependency and import boundaries are valid".
- `swift format lint --recursive Sources Tests Package.swift` — no diagnostics, exit 0.
- `shellcheck scripts/check-core-boundaries.sh` — exit 0.
- `git diff --check` — exit 0. `task-board validate` — board valid.

## Live binary verification

- No args → exit 64 with usage listing the stable `smoke` subcommand.
- `smoke --configuration-json <valid>` → exit 0; sorted-key JSON with result schemaVersion 1, metric schemaVersion 1, seed, sourceRevision, dependencyRevisions, redacted sensitive profileReference/destination, duration, platform.
- Unknown subcommand → exit 64. Unsupported configuration schemaVersion 9 → exit 64 with "unsupported configuration schema version: 9".
- File-based `--configuration` path (README example) → exit 0, redaction correct.
- `/tmp/relux-smoke-*` leak scan after runs → clean.

## AC verdicts

1. Standalone SPM macOS executable linking ReluxTunnelCore — PASS; no Tuist/Xcode workspace involved; boundary guard now fails closed if harness drops the Core link or imports NetworkExtension/SwiftUI/UIKit/AppKit.
2. Deterministic machine-readable smoke output with revisions/config/duration/platform/metric schema — PASS; byte-identical output proven in test with injected clock/platform.
3. Cancellation/normal-exit cleanup with tested exit codes — PASS; tests verify exit 143 plus LIFO cleanup of temp dir, Unix socket, and managed task; 130/143 mapping tested.
4. Injection seams (clock, SSH transport, packet endpoint, pressure, fault policy) without UI imports — PASS; dependencyInjection test exercises every seam; HarnessCoreComposition builds the same TunnelRuntimeContext as Core ProviderLifecycle (extension-equivalent composition confirmed against ProviderLifecycle.swift).
5. Swift Testing coverage of arg validation, schema versioning, cancellation, cleanup — PASS.

## Minor non-blocking notes

- `HarnessConfigurationDocument.parameters` defaults to `[:]` in the memberwise init but is required when decoding JSON (omitting it yields a keyNotFound usage error, exit 64). Fail-closed and documented via README example; consider decodeIfPresent later.
- `SignalHarnessCancellationSource` (DispatchSourceSignal wiring) has no in-process end-to-end signal test; the reason→exit-code mapping and application-level cancellation/cleanup are fully tested. Acceptable: real-signal tests inside a parallel Swift Testing run are flaky by nature.
- `sourceRevision`/`dependencyRevisions` are caller-supplied configuration inputs, not auto-detected — keeps output deterministic; documented in implementer evidence.
