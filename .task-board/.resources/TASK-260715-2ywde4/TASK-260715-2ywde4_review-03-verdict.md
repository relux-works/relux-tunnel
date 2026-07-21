# TASK-260715-2ywde4 — review-03 verdict

Date: 2026-07-21
Role: reviewer
Verdict: accepted
Route: done

## Rework-02 closure

- `scripts/tests/test-relay-shell-artifacts.sh` uses the explicit empty assignment
  `CDPATH=''` in its `script_dir` subshell and still resolves and executes the
  release comparator and native/Rosetta smoke correctly.
- ShellCheck 0.11.0 exits 0 with no findings for both changed shell scripts;
  `sh -n` also passes for both.
- `task-board validate` reports `Board is valid. No issues found.` The removed
  `TASK-260715-2ywde4_review-02-focus.md` is no longer an orphan or referenced
  resource; its name remains only in historical review notes.
- The narrow rework did not alter the accepted manifest-bound comparator,
  entrypoint, identity, protocol, or release implementation.

## Complete acceptance audit

1. Exact invocation: fresh process-level tests against the produced Darwin arm64
   executable reject empty, reordered, duplicated, missing, unknown,
   per-argument-oversized, and aggregate-oversized forms with exit 64, empty
   stdout, and the single fixed stderr line. Only the exact identity and stdio
   triples are admitted.
2. Stream/privacy boundary: supported EOF and CLOSE_SESSION runs produce exactly
   the 16-byte server hello and legal framed bytes with empty stderr. Malformed
   hello produces only the finite wire rejection on stdout and fixed diagnostic
   on stderr; closed stdout exits 74. Injected argument/stdin/payload/domain/
   destination/credential text is never reflected. Static review found one
   stdout writer and no dynamic diagnostic content.
3. Identity/build binding: Darwin arm64 identity is 235 bytes and reports
   `3d5d632fef2b9d939c14543d2db80ae4c268edeb8f557c46b497edf66dbadf44`;
   Rosetta amd64 reports
   `2f2546504646d2e1df0d52ff04e316282304f1d615399fa6563a4763ef3353a3`.
   Each independently computed executable SHA-256 equals both canonical identity
   output and the manifest-selected record. The 27-test release suite covers
   identity, manifest hash/size/target, same-size executable tamper, symlink, and
   extra-stdout rejection. Two four-target builds compare byte-identically and
   release verification passes.
4. Rootless lifecycle: the produced process ran with nonzero effective UID. While
   stdio remained live after handshake, `pgrep -P` found no children and `lsof`
   found no TCP listener or UDP descriptor. SIGTERM exited 130 within the bound,
   stderr stayed empty, and the task-local working directory stayed empty.
   Fresh pinned Go tests additionally cover SIGINT/SIGTERM, EOF, malformed hello,
   CLOSE_SESSION with inherited stdin open, closed stdout, repeated clean exit,
   cancellation worker joins, and no runtime files. The production dependency
   boundary contains neither `net` nor `os/exec`; source review found no listener,
   child-process, privilege, or runtime-file path.
5. Tests/builds: pinned Go 1.26.5 focused tests were forced fresh with `-count=1`;
   all relay packages and vet pass; 27 Python tests and `py_compile` pass;
   `make relay-shell-validate` passes tests, vet, two four-target builds,
   reproducibility, release verify, and native/Rosetta smoke; and
   `make relay-protocol-check` passes 89 vectors, Go conformance, 58 Swift tests,
   deterministic regeneration, negative fixtures, drift checks, and Swift build.

## Additional gates and boundaries

- `gofmt -d`, `git diff --check`, final ShellCheck, and final board validation are
  clean.
- Local Black was unavailable (`python3: No module named black`). This does not
  weaken the verdict: rework-02 changed only shell/board state, the Python diff
  retained review-02's independently accepted formatting evidence, and the
  unchanged Python passed all 27 tests plus `py_compile` in this review.
- Native Intel macOS and Linux amd64/arm64 execution remain honestly CI-only;
  local evidence is native Darwin arm64 plus Rosetta amd64.
- The reviewer made no product-code changes.

All task AC, architecture, security/privacy boundaries, tests, lint, build, and
board hygiene are satisfied. Accepted.
