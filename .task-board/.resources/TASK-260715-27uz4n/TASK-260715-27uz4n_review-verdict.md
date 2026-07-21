# TASK-260715-27uz4n — reviewer verdict

Date: 2026-07-21  
Verdict: changes requested → `to-dev`

## Blocking findings

1. **Installed Go source integrity is incomplete.**
   `verify_archive_provenance` verifies the pinned archive checksum but compares
   only the caller-supplied installed members. For Go those members are
   `go/bin/go` plus `asm`, `compile`, and `link`
   (`scripts/relay_release.py:207-249, 413-432`). It does not compare the
   installed standard-library/runtime source tree that clean builds consume.
   I copied the provisioned toolchain, replaced
   `go/src/archive/tar/common.go` with unrelated source, and then ran
   `verify_go_toolchain(tampered_go, "local", require_provenance=True)`; it
   returned success. This violates the pinned/offline-input and tampered-input
   requirements. Rework must verify the complete extracted Go tree against the
   checksum-pinned archive (including missing, added, changed, and unsafe file
   types), and add negative tests for changed/deleted standard-library/runtime
   inputs.

2. **The CI missing-Go gate is a false positive.**
   `scripts/tests/test-relay-toolchain-missing-input.sh:10-23` supplies the
   constant commit `012345...`, while `build-target` checks checkout identity
   before resolving Go. Reproduction produced
   `relay-release: source commit does not match checkout HEAD`; the intended
   missing Go path was never reached. With the real HEAD, the same command
   correctly produced `relay-release: release tool not found: missing-go`.
   Update the negative gate to use the actual checked-out commit and assert the
   exact expected diagnostic. Do the same for missing `SOURCE_DATE_EPOCH` and
   the new toolchain-tamper cases so unrelated failures cannot satisfy CI.

3. **Linux kernel 4.4 compatibility is asserted but not proven.**
   The Linux binary check (`scripts/relay_release.py:905-929`) proves ELF64 and
   absence of `PT_DYNAMIC`/`PT_INTERP`; it performs no kernel ABI/version or
   syscall-baseline inspection. Static linkage alone does not prove execution
   on Linux 4.4. The CI job cross-builds both Linux targets on Ubuntu 24.04 and
   executes neither baseline fixture. `relay/README.md:66-72` nevertheless says
   the gate verifies the Linux 4.4 floor. Add an enforceable, source-backed
   binary/runtime compatibility gate for both Linux architectures (or remove
   the unproved claim and supply the actual Linux 4.4 fixtures). The macOS 12.0
   `LC_BUILD_VERSION` and dylib contract are correctly inspected.

4. **The checkout action was downgraded without justification.**
   The existing workflow used `actions/checkout@v7`; this change pins v6.0.0 at
   `1af3b93b6815bc44a9784bd300feb67ff0d1eeb3`. That SHA is genuinely v6.0.0,
   but official v7.0.1 was released on 2026-07-20 at
   `3d3c42e5aac5ba805825da76410c181273ba90b1`. Pin the approved v7 revision
   (prefer the current fixed release) or record a concrete compatibility reason
   for the downgrade. Also make `toolchain-check` compare the workflow pin to
   the manifest's exact expected value; it currently accepts any 40-hex
   checkout SHA (`scripts/relay_release.py:640-644`).

5. **Post-build CPU-baseline verification is missing.**
   The produced binaries do contain `GOAMD64=v1` / `GOARM64=v8.0`, but
   `verify_go_build_info` checks only Go version, GOOS, GOARCH, cgo, and
   trimpath (`scripts/relay_release.py:982-999`). Add the architecture-variable
   check and negative fixtures so the declared CPU floors cannot silently
   drift.

## Evidence that passed

- Official Go 1.26.5 download hashes matched all four manifest archives.
- Official Syft v1.48.0 checksums matched all four manifest archives; the tag
  resolves to commit `3e2bc6ed095f7ec1a415fb38cfe1c319e95dfed6`.
- Python unit tests: 16/16 pass.
- Black, `py_compile`, ShellCheck, Actionlint, YAML parse, `git diff --check`,
  privacy scan, and `task-board validate` pass.
- `make relay-toolchain-ci ...` passes: Go tests/vet, license extraction, and
  all four clean target builds.
- `make relay-shell-validate ...` passes: two isolated four-target builds are
  byte-identical; manifest/SBOM/checksum/license verification passes; macOS
  arm64 runs natively and amd64 runs under Rosetta. Linux rows are honestly
  reported as not executed.
- A clean-mode sentinel was deleted and an incremental-mode sentinel was
  retained in the same target-scoped workspace, confirming the documented
  cache behavior.

## Source checks

- Go downloads and checksums: https://go.dev/dl/?mode=html
- Go Linux baseline documentation: https://go.dev/wiki/Linux
- Syft v1.48.0 release: https://github.com/anchore/syft/releases/tag/v1.48.0
- actions/checkout v7.0.1 release:
  https://github.com/actions/checkout/releases/tag/v7.0.1

