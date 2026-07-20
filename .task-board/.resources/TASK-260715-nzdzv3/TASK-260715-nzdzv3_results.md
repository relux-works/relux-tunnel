# TASK-260715-nzdzv3 — ReluxNIOSSH implementation results

## Outcome

- Added independent source SwiftPM package `Dependencies/ReluxNIOSSH` from the
  exact audited SwiftNIO SSH `0.14.1` commit
  `31cdc3c3391a10460dedf1170530cf651d2ca496`.
- Preserved product/module `NIOSSH` and upstream defaults; package identity is
  `ReluxNIOSSH`. No root target, including `ReluxTunnelCore`, depends on it yet.
- Added pre-open per-child receive-window configuration, immutable cap,
  deterministic adjustment threshold/suppression, consistent snapshots, and
  typed adjustment events emitted after consumer pipeline delivery.
- Added public production-path manual rekey, optional per-direction protected
  byte thresholds, injected monotonic elapsed-time threshold, request/reason
  coalescing, generation/counter snapshots, completion promises, and typed
  started/succeeded events. Server-initiated KEX remains supported and
  observable.
- Product code does not call `_rekey()` or any internal test-only symbol.

## Tests and validation

- `make validate-reluxniossh` — passed.
  - exact archive/license hashes and 16-file delta allowlist passed;
  - 323 upstream XCTest cases passed;
  - 10 new deterministic Swift Testing cases passed;
  - `swift build` passed without warnings.
- Strict `swift format lint` for the fork sources, changed upstream test helper,
  new Swift Testing suite, and package manifest — passed without diagnostics.
- `make validate-core` — passed: boundary/native-fixture checks, 49 Swift Testing
  cases, and root `swift build`. The existing linker emitted its known section
  alignment warning; there was no build or test failure.
- Python bytecode compilation and patch-manifest JSON parsing passed.
- Same-pin conflict preflight passed:
  `python3 scripts/reluxniossh-fork-tool.py conflict-test --upstream-ref 31cdc3c3391a10460dedf1170530cf651d2ca496`.

## Evidence

- Fork validation log SHA-256:
  `39ed985950728fd196f083527e0f302693be6cae2eaa6aafb657a31e23a6c82a`
- Root validation log SHA-256:
  `e9e9576f858937a13b448dd82f6ab818003d67c61ae87447ac7dc05217e95069`
- Upstream patch SHA-256:
  `1241622deca47f05a139998a94b2ce988935bb0e288f26cf57dc71f3d23317a4`

## Review focus

1. Confirm the channel-option timing and post-delivery WINDOW_ADJUST order.
2. Confirm protected-byte accounting boundary and KEX transition detection in
   `NIOSSHHandler`.
3. Confirm the 16-file patch allowlist contains no unrelated engine change.
4. Use the four logical commits in `RELUX_DELTA.md`; no commit or staging was
   performed by the implementation agent.
