# Relay and protocol-test target shells

Implement `TASK-260715-1ccx3l` on top of the accepted `TASK-260715-3bdplx` Go 1.26.5 / `CGO_ENABLED=0` toolchain and the existing relay protocol/schema work. Preserve the repository's SPM/workspace decoupling and do not wait for Apple signing or A0/P0.

Requirements:

1. Create or complete buildable source/test target shells for `relux-relay` and protocol tests. Reuse existing Go/schema scaffolding; do not duplicate or move the source of truth.
2. Produce the required Linux/macOS × amd64/arm64 artifact matrix deterministically. A macOS host may cross-build Linux artifacts without executing them; record that execution as a release-CI row, never as a local pass.
3. Add a deterministic credential-free smoke command that reports executable version, protocol version, source revision, and build target. No host paths, timestamps, usernames, or secrets may enter output or manifests.
4. Generate stable checksums and a manifest, plus license and SBOM hooks. Preserve the accepted SPDX/Syft approach and dependency provenance.
5. Provide a runnable protocol-test entry point with an empty/health contract and one version-mismatch case only. Do not implement UDP association/framing behavior in this task and do not imply feature readiness.
6. Verify clean-checkout reproducibility as far as locally possible, byte-identical rebuilds, architecture/file type, version output, manifest schema, notices/SBOM, and repository validation. Attach a new task-scoped results outcome.
7. Privacy is stop-the-line: no raw spawn log, host identifier, absolute local path, credential, payload, or remote-controlled string may be versionable.

Use Codex `gpt-5.6-sol` at high only, serially. Do not delegate or use Claude. If the accepted toolchain cannot satisfy an AC without a workaround, stop with exact evidence.
