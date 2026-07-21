# TASK-260715-27uz4n — Review 02 focus

Fresh independent review of rework-01. Do not trust producer claims or prior verdict; reproduce the load-bearing evidence.

Verify all five original findings are fully resolved:

1. Provision an official pinned Go archive, tamper real installed runtime and stdlib source files, and prove provenance fails. Also verify deleted, added, mode/type drift, duplicate paths, traversal, links, devices, and unsafe archive members fail closed with exact diagnostics.
2. Exercise missing-Go and missing-SOURCE_DATE_EPOCH paths using the actual checkout HEAD. Confirm the intended missing-input branch fires first and exact diagnostics are asserted.
3. Confirm the Linux 4.4 claim is gone. The only Linux runtime claim must be native unprivileged Ubuntu 24.04 amd64 and arm64 CI fixtures; QEMU or static linkage must not be presented as old-kernel evidence. Validate both native workflow rows and smoke behavior as far as this macOS host permits, recording the evidence boundary honestly.
4. Confirm actions/checkout is pinned exactly to v7.0.1 commit 3d3c42e5aac5ba805825da76410c181273ba90b1 and the manifest/workflow equality gate rejects drift.
5. Confirm post-build metadata requires GOAMD64=v1 for amd64 and GOARM64=v8.0 for arm64, rejects wrong or cross-architecture settings, and preserves GOOS, GOARCH, CGO_ENABLED=0, and -trimpath.

Regression gates:

- Re-run all four target builds and two isolated-build byte reproducibility.
- Re-run linkage, SBOM/license/notices, compiler/archive provenance, offline/cache/environment isolation, clean versus incremental behavior, and available macOS native/Rosetta smoke.
- Re-run Python tests, Black, py_compile, ShellCheck, Actionlint/YAML, git diff --check, privacy scan, and task-board validation.
- Inspect the manifest, workflow, scripts, docs, and result evidence against every AC. No acceptance from tests alone.

Verdict contract: accepted only if every AC and original finding is independently evidenced; otherwise attach a new task-scoped verdict resource and route to rework with exact reproductions.
