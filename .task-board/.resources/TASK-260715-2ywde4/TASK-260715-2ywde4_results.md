# TASK-260715-2ywde4 — relay entrypoint rework-01 results

## Review-01 rework delivered

- Added `scripts/relay_release.py verify-identity`, a reusable release/bootstrap boundary that consumes the exact bounded identity output, the canonical manifest, the selected target, and the selected executable.
- The comparator requires one canonical JSON line with one LF and at most 512 bytes; it checks the manifest schema/protocol/build tuple, canonical target record, artifact size/SHA-256, selected executable size/SHA-256, and exact identity field order/values.
- Manifest, identity, and executable inputs are regular files opened with `O_NOFOLLOW`; executable size and SHA-256 are derived from the same descriptor.
- Bound `scripts/tests/test-relay-shell-artifacts.sh` native and Rosetta identity smoke to `relux-relay-manifest-v1.json`. Exact stdout and stderr are captured under a private umask-077 temporary directory; identity must pass before stdio smoke.
- Removed the prior 64-zero non-comparison from the Go entrypoint test. Copied binary/manifest fixtures now prove acceptance plus deterministic rejection of identity hash, manifest hash, manifest size, target tuple, same-size executable tampering, symlink input, and extra stdout. The real CLI success/failure paths and path-free mismatch diagnostic are asserted.

## Preserved behavior

- Exact supported invocations remain `--identity --protocol 1` and `--stdio --protocol 1`; fixed exit behavior, stdout/stderr separation, EOF/signal/cancellation cleanup, rootless operation, and no-listener/no-child/no-runtime-file boundaries are unchanged.
- Protocol stdout remains hello/framed bytes only. Comparator diagnostics are fixed and never include identity bytes, manifest contents, executable paths, or injected errors.
- The pinned four-target build path, deterministic metadata, offline toolchain, CPU baselines, and existing release verifier remain authoritative.

## Verification evidence

- Focused copied-fixture and CLI mismatch matrix: pass, including all requested self-hash/size/target/selected-byte negatives.
- `make relay-shell-test relay-shell-vet`: all relay Go packages pass with pinned Go 1.26.5; 27 Python release tests pass; `go vet ./...` passes.
- `make relay-protocol-check`: 89 canonical vectors, Go conformance/hostile tests, 58 Swift protocol tests, deterministic generation/drift checks, and Swift build pass.
- `make relay-shell-reproducibility relay-shell-verify relay-shell-smoke RELAY_VERSION=0.1.0 SOURCE_COMMIT=6f43760c5f104f2015a8181b78a26855bc78509f SOURCE_DATE_EPOCH=1784651493`: two four-target builds are byte-identical; release/manifest/SBOM verification passes; native Darwin arm64 identity+stdio smoke and Rosetta Darwin amd64 identity+stdio smoke pass.
- Pinned `gofmt -d`, Python bytecode compilation, shell syntax, production dependency/prohibition scan, `git diff --check`, and `task-board validate`: pass.

## Honest runtime boundary

- Native Intel macOS, Linux amd64, and Linux arm64 execution were unavailable on this Darwin arm64 host and remain explicit release-CI rows. Rosetta evidence does not replace native Intel evidence.
- `relay-shell-release --require-clean` was not run because task changes remain intentionally uncommitted for review; the clean checkout/source-commit gate remains enforced by that command.
