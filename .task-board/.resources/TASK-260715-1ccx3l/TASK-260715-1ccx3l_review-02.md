# TASK-260715-1ccx3l — Independent re-review 02

## Verdict

Accepted. The provenance rework closes both prior findings without weakening
the relay target-shell, artifact, or release-gate contracts.

## Fail-closed release-tool provenance

- The repository and the official upstream checksum documents agree on all
  four Go 1.26.5 archives and all four Syft 1.48.0 archives.
- The provisioned Darwin arm64 Go archive matches
  `efb87ff28af9a188d0536ef5d42e63dd52ba8263cd7344a993cc48dd11dedb6a`.
  The release verifier requires `GOTOOLCHAIN=local`, exact `go1.26.5`, exact
  host identity, the canonical path-free receipt, the retained archive hash,
  and archive equality for the Go driver, assembler, compiler, and linker.
- The provisioned Darwin arm64 Syft archive matches
  `fef3e6d5df336a0a4c3e421e503119d1e221cf82a3ef5e426a791fcd81667e87`.
  Its structured identity is Syft 1.48.0, commit
  `3e2bc6ed095f7ec1a415fb38cfe1c319e95dfed6`, Darwin arm64. The verifier also
  binds the retained archive checksum and installed executable bytes.
- Eleven release-tool unit tests passed. They cover missing/older/newer/wrong-
  platform Go, nonlocal automatic toolchain selection, wrong Go archive hash,
  Syft version-only and missing-field output, wrong Syft commit/platform/archive
  hash, substituted Syft bytes, path escape, and canonical provenance.
- Direct release-entry-point attacks also failed closed for nonlocal
  `GOTOOLCHAIN`, missing Go, a versionless Syft substitute, and a dirty checkout.
  An inherited `GOTOOLCHAIN=auto` could not override the explicit local verifier.

## Artifact, smoke, manifest, and hook evidence

- `make relay-shell-validate` passed with exact Go 1.26.5 and
  `CGO_ENABLED=0`. Two complete builds produced byte-identical copies of all
  four relay and all four protocol-test executables.
- File inspection found Mach-O x86_64/arm64 and static stripped ELF
  x86-64/aarch64 outputs. Embedded build metadata reports Go 1.26.5,
  `-trimpath`, `CGO_ENABLED=0`, and the exact target-specific CPU baseline.
- Darwin arm64 smoke passed natively. Darwin amd64 passed under Rosetta and is
  still labelled as requiring a native Intel release-CI row. Linux amd64 and
  arm64 remain unexecuted native release-CI rows, never local passes.
- Smoke JSON is deterministic and limited to schema/executable version,
  protocol version, source revision, build target, empty-health status, and
  `relayBehaviorImplemented: false`.
- The checksum file verified every manifest, notice, relay, and SPDX byte.
  Manifest field sets, target order, names, sizes, source revision, checksums,
  SBOM references, and Apple-bundle input are canonical and path-free.
- Four SPDX 2.3 documents passed policy with `stdlib@go1.26.5` declared
  BSD-3-Clause. The combined repository/Go notice exists and its Go license
  input is checksum-bound. Scan-local SPDX timestamps/namespaces may differ;
  each manifest binds the exact SBOM bytes it contains, as the accepted
  toolchain decision permits.
- The protocol-test shell runs exactly two target-shell cases: empty health and
  one version mismatch. No UDP socket, association, deployment, SSH execution,
  or release-publication behavior was added by this task.

## Regression and privacy gates

- Pinned Go unit tests, race tests, vet, gofmt, Python unit/compile checks,
  ShellCheck, Go/Swift protocol conformance, 57 Swift relay-protocol tests,
  schema regeneration, and Swift build passed.
- `make validate-core` passed all 306 Swift tests and the final Swift build.
- `git diff --check` and `task-board validate` passed.
- Changed and untracked versionable content passed absolute-path and credential
  pattern scans. The task runner's raw spawn-log outcome was removed; the
  retained review evidence contains no host/account identifier, credential,
  payload, remote-controlled string, or raw process log.

The dirty working tree correctly prevents exercising a successful
`--require-clean` release in-place; the negative clean-tree gate passed, and the
same provenance/build path passed through the non-publication validation entry
point. Native Intel macOS and both Linux execution rows remain release-CI gates
as required and do not block acceptance of these cross-build target shells.
