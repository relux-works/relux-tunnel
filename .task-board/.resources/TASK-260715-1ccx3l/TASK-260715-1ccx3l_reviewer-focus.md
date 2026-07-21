# Independent review: relay and protocol-test target shells

Review `TASK-260715-1ccx3l` independently.

- Verify the repository acquires and uses exactly Go 1.26.5 rather than the older host Go, and that `CGO_ENABLED=0`/target settings match the accepted toolchain decision.
- Rebuild both `relux-relay` and the protocol-test shell for Darwin/Linux × amd64/arm64 twice and compare bytes, checksums, architecture/file type, and manifest entries.
- Execute the supported local Darwin rows and verify Linux/native-Intel execution is reported as a release-CI gate, not as a local pass. Rosetta evidence must be labelled accurately.
- Inspect smoke output for deterministic executable version, protocol version, source revision, and build target; reject timestamps, host paths, usernames, or nondeterministic fields.
- Verify protocol-test scope is exactly empty health plus one version mismatch and no UDP/socket/association behavior is implied.
- Validate strict manifest schema, stable ordering, source revision, checksums, licenses, SPDX/Syft output, Apple-bundle input, clean-release gate, and relevant negative tests.
- Run Go tests, release-tool tests, repository validation, diff checks, and privacy scans. No raw spawn log or host/account/secret identifier may be versionable.

Use only Codex `gpt-5.6-sol` at high. Do not delegate or use Claude. Accept/done only if every AC is independently evidenced; otherwise return bounded rework.
