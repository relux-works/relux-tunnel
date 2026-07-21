# Independent re-review after release-tool provenance rework

Re-review `TASK-260715-1ccx3l` against `TASK-260715-1ccx3l_review.md` and `TASK-260715-1ccx3l_rework-01-results.md`.

Focus on the two previously blocking supply-chain findings:

1. Prove the release path cannot use Go auto-download/switching. Exercise `GOTOOLCHAIN`/wrong-version/missing/wrong-architecture/wrong-checksum cases and verify only an exactly pinned, checksum-verified local Go 1.26.5 provisioning is accepted.
2. Prove Syft verification binds version 1.48.0, expected build commit, platform/archive checksum, and installed bytes. Re-run wrong-commit, version-only mock, wrong-checksum, substituted-binary, missing-field, and unsupported-platform cases.

Then rerun or independently validate the two-build four-target artifact matrix, deterministic smoke/manifest, protocol-test scope, checksums, SBOM/licenses, race/vet/tests, `make validate-core`, privacy, board, and diff gates. Confirm native Intel and Linux execution remain release-CI gates. Ensure no raw spawn-log outcome is versionable.

Use only Codex `gpt-5.6-sol` high, without delegation or Claude. Accept/done only if the rework closes both findings without weakening the accepted release provenance contract.
