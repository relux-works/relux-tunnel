# Rework 01: fail-closed release-tool provenance

Address the two blocking findings in `TASK-260715-1ccx3l_review.md`. Preserve the accepted target-shell behavior and artifact outputs.

1. The release entry point must not auto-download or switch Go through `GOTOOLCHAIN`. Enforce local/preprovisioned execution and exact Go 1.26.5 identity. Add a documented, checksum-verified provisioning path based on the accepted upstream artifact/checksum contract; fail closed on missing, older/newer, wrong-architecture, wrong-checksum, or auto-toolchain conditions. Tests may use an isolated verified fixture, but release evidence must identify the accepted source/checksum without host paths.
2. Pin Syft with the full accepted provenance, not version text alone. Validate the exact release artifact checksum and the expected build commit from structured/version output. Reject wrong commit, wrong checksum, unexpected platform, missing fields, or a version-only mock. Keep the SBOM hook deterministic and offline after provisioning.
3. Add negative tests for both supply-chain paths and re-run the full matrix, deterministic rebuild, smoke, manifest/checksum, license/SBOM, privacy, board, and diff gates.
4. Update documentation/results and attach a new task-scoped rework outcome. Do not publish raw spawn logs or weaken the release-only provenance rule.

Use only Codex `gpt-5.6-sol` at high; no delegation and no Claude. Return to review only after all checks pass.
