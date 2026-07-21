# TASK-260715-2ywde4 reviewer verdict

Date: 2026-07-21
Verdict: changes requested
Route: `to-dev`

## Required change

Acceptance criterion 5 requires an entry-point self-hash mismatch fixture, but the checked-in test is vacuous. `relay/cmd/relux-relay/main_test.go:190-193` only compares the computed SHA-256 with 64 zeroes. It does not supply a manifest hash, invoke a verifier, or exercise a rejection branch, so a broken or absent identity-versus-manifest comparison would still pass. The producer outcome's claim that mismatch rejection is covered is therefore unsupported.

The runtime smoke has the same negative-coverage gap: `scripts/tests/test-relay-shell-artifacts.sh:34-53` derives the expected `selfSha256` from the same executable being queried and does not compare the identity record with the selected artifact SHA in `relux-relay-manifest-v1.json`. A tampered executable can therefore pass that identity helper by reporting the hash of its tampered bytes; the separate release verifier rejects stale manifest metadata, but no automated test proves the identity-preflight mismatch contract requested by this task.

Rework must replace the zero-hash assertion with a real automated mismatch/tamper fixture. The test should compare the canonical bounded identity tuple against the manifest-selected target and deterministically reject a wrong `selfSha256` (and retain exact stdout/EOF/exit requirements). A suitable task-scoped integration test may tamper a copied binary or manifest fixture, assert rejection, and leave the canonical bundle untouched. Update the runtime smoke to bind identity to the manifest artifact SHA, or add an equivalent test-owned comparator at the correct bootstrap/release boundary. Then rerun the gates below.

## Independent review evidence

Green:

- Pinned Go 1.26.5 `make relay-shell-test relay-shell-vet`; 26 Python release tests passed.
- Uncached 20-repeat Go entrypoint/stdio/buildinfo run passed.
- `make relay-protocol-check` passed: 89 vectors, Go conformance, 58 Swift protocol tests, deterministic generation, and Swift build.
- Four-target release build reproduced byte-for-byte; `relay-shell-verify` passed.
- Native Darwin arm64 and Rosetta Darwin amd64 identity/stdio smoke passed. Native Intel macOS and both native Linux executions remain explicit CI-only rows.
- Independent executable matrix covered reordered, duplicated, missing, unknown, per-argument oversized, aggregate-oversized, malformed-hello/privacy, EOF, CLOSE_SESSION, SIGINT, SIGTERM, and tampered-copy identity behavior with stable exit codes and clean stdout/stderr.
- Independent SHA-256 of Darwin arm64 and amd64 artifacts matched both canonical identity output and manifest artifact SHA.
- Rootless live-process inspection found no listener sockets, child processes, or runtime files; UID was 502.
- A copied release bundle with a tampered Darwin arm64 executable was rejected by release verification with a stable artifact-size mismatch; invalid build identity input was rejected before tool execution.
- `git diff --check`, shell syntax, Python compilation, privacy/dependency scans, and `task-board validate` passed.

Lifecycle review found bounded process-level termination for malformed hello, CLOSE_SESSION, EOF, peer close, closed stdout, SIGINT, and SIGTERM. The production executable uses its real process boundary (not a test-only `os.Exit` replacement); no children, listeners, or runtime files exist to orphan. This is not the requested-change reason.
