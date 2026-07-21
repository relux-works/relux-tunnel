# TASK-260715-27uz4n — Rework-02 sandbox-isolation evidence

Date: 2026-07-21

## Change

`scripts/relay_release.py` now lstat-checks the final build workspace and every HOME, TMPDIR, GOCACHE, GOMODCACHE, and GOPATH directory without following links. Existing symlinks and non-directory types fail closed with stable path-specific errors. Each child is resolved after creation and must remain under the resolved target sandbox. Both clean and incremental preparation validate the root; clean still deletes and recreates a safe workspace, while incremental reuses only safe target-local directories. The manifest drift gate pins this cache policy, and the README plus LOGBOOK record it.

## Exact regressions

- Symlinked workspace root rejected in clean mode, incremental mode, and direct environment construction: `build sandbox root must not be a symbolic link`.
- Regular-file workspace root rejected in all three paths: `build sandbox root must be a directory`.
- Symlinked HOME, TMPDIR, GOCACHE, GOMODCACHE, and GOPATH each rejected with the exact variable-specific `must not be a symbolic link` error.
- Non-directory TMPDIR rejected with `build sandbox TMPDIR must be a directory`.
- A normal directory outside the resolved sandbox is rejected with `build sandbox HOME escapes build sandbox root`.
- Incremental reuse preserves a cache marker; clean mode removes it and recreates the root.

## Final verification

- Python unit suite: 26 pass.
- `make relay-toolchain-ci` with pinned source and epoch: pass; four clean targets, Go tests/vet, exact missing-input gates, metadata/linkage, and licenses.
- `make relay-shell-validate` with the same inputs: pass; two byte-identical isolated four-target builds, SBOM/checksum/notices/verification, native macOS arm64 and Rosetta amd64 smoke.
- Black, py_compile, JSON, shell syntax, ShellCheck, Actionlint, YAML, gofmt, privacy, diff, and board validation: pass.
- Local Linux runtime execution is not claimed on macOS; native Ubuntu 24.04 amd64 and arm64 remain explicit CI evidence rows.
