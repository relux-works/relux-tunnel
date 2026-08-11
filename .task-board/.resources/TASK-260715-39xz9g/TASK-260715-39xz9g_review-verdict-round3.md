# TASK-260715-39xz9g — reviewer verdict, round 3

Verdict: changes requested; route to `to-dev`.

## Acceptance-blocking findings

1. AC5 privacy boundary remains bypassable. `scripts/ssh_matrix_fixture.py:183-185` accepts any string beginning with `SHA256:` and length at least 20. `_validate_public_observation` applies that weak check to per-run provider fingerprints at lines 680-699, then persists the values at lines 895-896. Independent probe exit 0 demonstrated acceptance of `SHA256:private-host.example/user/alice`. An external provider override can therefore place host/user/path-like text in a report while it is labeled as a fingerprint. Require exact OpenSSH SHA-256 fingerprint syntax and decoded 32-byte digest length; add regression tests for arbitrary routing, account, path, address, and credential-like values in manifest and provider observations.

2. Linux teardown can falsely claim zero residual resources. `scripts/ssh_matrix_provider.py:715-727` ignores the return code from `limactl delete -f` and computes `residualResources` only from the local provider directory. Independent mocked probe exit 0 forced the delete command to exit 99 and received `{status: ok, residualResources: 0}`. Fail closed on delete error/timeout, verify the named Lima instance is absent before reporting success, and add regression tests. Preserve enough task state to retry cleanup if external deletion is not confirmed.

These are implementation rework, not a Stop-The-Line condition. The fresh happy-path lifecycle did exit 0 and left no observed VM or server-row state, but finding 2 makes that report format incapable of proving cleanup on a failed delete path.

## Independent gates

- `make ssh-fixtures-test`: exit 0; 33 tests passed.
- `swift test`: exit 0; 428 tests in 35 suites passed.
- `make ssh-fixtures-lifecycle`: exit 0; all four rows reachable non-root, exact rotation dispositions, 11 controls, and reported zero residuals. Fresh report privacy scan: exit 0; provider-state row set empty; named Lima instance absent.
- Strict recursive Swift format, Python compilation, tab scan, and `git diff --check`: exit 0.
- Fresh streamed 5 GiB source/sink: exit 0; 5,368,709,120 bytes and `SHA256:fc01cfd7aebf90ff9491f8556131b6ef575c3e1fa33a0277ba28920bbaee7f54`; no payload retained.
- Stdlib trace coverage: fixture 83.7% from the 33-test run; provider 91.2% from a fresh traced live lifecycle.
- One diagnostic accumulation wrapper exited 1 because Python 3.14 `trace --no-report` did not create its counts file and its instrumented lifecycle emitted a redacted SSH failure. Corrected report-producing trace runs and the authoritative uninstrumented lifecycle exited 0.
- `task-board validate`: exit 0 with the existing parent-only `PARENT_STATUS_MISMATCH` for `STORY-260715-lkshfz`.

## Required rework

Tighten fingerprint parsing at every persisted public boundary; make Lima deletion and absence verification part of zero-residual truth; add both negative regression tests; rerun the existing gates and live lifecycle; update the task logbook with these review regressions; attach a new privacy-safe result before another reviewer cycle.