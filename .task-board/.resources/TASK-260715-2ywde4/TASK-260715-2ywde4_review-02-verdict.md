# TASK-260715-2ywde4 — review-02 verdict

Date: 2026-07-21
Verdict: changes requested
Route: to-dev

## Required rework

The manifest-bound identity fix is functionally correct, but the newly changed shell smoke is not lint-clean. ShellCheck 0.11.0 reports SC1007 at scripts/tests/test-relay-shell-artifacts.sh:10 for `script_dir=$(CDPATH= cd -- ...)` and exits 1. Use the project-established explicit empty assignment form, e.g. `CDPATH= cd ...`, while preserving the resolved script directory and exact smoke behavior. Rerun ShellCheck on both changed shell scripts and the focused/full gates.

Board hygiene also needs recovery: task-board validate reports TASK-260715-2ywde4_review-02-focus.md as an orphan resource file with no board reference. Attach or remove it through task-board CLI; do not edit board files directly.

## Accepted evidence retained

Pinned Go 1.26.5 tests and vet pass; all 27 Python release tests pass; make relay-protocol-check passes 89 vectors, Go conformance, 58 Swift tests, deterministic generation, and Swift build. Two four-target builds are byte-identical; release verify and native Darwin arm64 plus Rosetta amd64 identity/stdio smoke pass. Independent hashes for both Darwin executables match canonical bounded identity output and their manifest records. Copied-fixture and CLI negatives reject identity hash, manifest hash/size/target, same-size executable tampering, symlink substitution, and extra stdout with fixed path-free diagnostics. Exact invocation, malformed hello, EOF, CLOSE_SESSION, closed stdout, 12x SIGINT, 12x SIGTERM, rootless, no-child, no-listener, and no-runtime-file checks pass. Native Intel macOS and Linux amd64/arm64 remain honest CI-only runtime rows.

Review logs are under .temp/TASK-260715-2ywde4-review-02/.