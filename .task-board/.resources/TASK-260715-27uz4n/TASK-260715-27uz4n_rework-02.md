# TASK-260715-27uz4n — review 02 verdict

Date: 2026-07-21
Verdict: changes requested → to-dev

## Rework finding

Incremental workspace isolation is bypassable through symlinks. prepare_build_sandbox(..., incremental) accepts an existing symlink as the workspace root, and sanitized_environment accepts symlinked HOME, TMPDIR, GOCACHE, GOMODCACHE, or GOPATH children because mkdir(..., exist_ok=True) follows them. The environment strings remain syntactically below .build/relay, while filesystem resolution points outside the isolated target workspace. This violates the documented incremental-only-reuses-that-workspace contract and the task cache/credential-isolation scope.

Independent reproduction used task-scoped scratch paths only. A workspace symlink under .build/relay pointing to .temp was accepted; the emitted HOME resolved under .temp. A real workspace with its home child symlinked to a separate .temp directory was also accepted, and HOME resolved exactly to that external directory. The same construction applies to all cache children. Clean mode still deletes a normal target workspace and fails rather than following a root symlink, so this is ordinary incremental-mode rework, not a stop-the-line blocker.

Required rework:

1. Resolve and validate the final workspace component, not only its parent, and reject symlink/non-directory roots in both preparation and environment construction.
2. In incremental mode, lstat every workspace/cache path and reject symlinks or other unsafe types; require every resolved HOME/TMPDIR/GOCACHE/GOMODCACHE/GOPATH path to remain beneath the resolved target sandbox.
3. Add deterministic exact-diagnostic regressions for a symlinked sandbox root and each symlinked child cache/home path. Preserve clean deletion and legitimate incremental reuse.
4. Re-run the complete pin, official-archive provenance, exact-negative, four-target, reproducibility, linkage/runtime, license/SBOM, lint, privacy, and board gates and attach new task-scoped evidence.

## Original rework findings

All five prior findings are resolved: the official Go tree is fully compared; runtime and stdlib tampering plus missing/added/mode/symlink/hardlink drift fail with exact diagnostics; duplicate/traversal/link/device archives fail closed; missing Go and missing SOURCE_DATE_EPOCH use actual HEAD and exact stderr; the Linux 4.4 claim is gone and native Ubuntu 24.04 amd64/arm64 workflow rows are honest; actions/checkout is exactly v7.0.1 commit 3d3c42e5aac5ba805825da76410c181273ba90b1 and workflow drift is gated; GOAMD64=v1 and GOARM64=v8.0 are present and enforced.

## Passing evidence

- Official upstream metadata matched all four Go 1.26.5 archive hashes, all four Syft 1.48.0 archive hashes, Syft tag commit 3e2bc6ed095f7ec1a415fb38cfe1c319e95dfed6, and checkout v7.0.1 commit 3d3c42e5aac5ba805825da76410c181273ba90b1.
- 20 Python tests, exact missing-input shell gates, real official-Go content/tree drift negatives, hardlink archive negative, and real cross-architecture metadata rejection passed.
- make relay-toolchain-ci and make relay-shell-validate passed. Four portable targets built; two isolated release builds produced byte-identical relay and protocol-test executables.
- Linux binaries are static ELF64 without dynamic interpreter/library linkage; Darwin binaries carry LC_BUILD_VERSION 12.0 and exactly libSystem/libresolv. CPU, GOOS/GOARCH, CGO_ENABLED=0, and trimpath metadata match.
- License extraction, SPDX/manifest/checksum verification, native macOS arm64 smoke, and Rosetta amd64 smoke passed. Native Linux runtime execution cannot run on this macOS host; workflow source plus Actionlint confirms both native rows, without claiming a local pass.
- Black, py_compile, JSON parse, shell syntax, ShellCheck, Actionlint, YAML parse, git diff --check, targeted privacy scan, and task-board validate passed.
