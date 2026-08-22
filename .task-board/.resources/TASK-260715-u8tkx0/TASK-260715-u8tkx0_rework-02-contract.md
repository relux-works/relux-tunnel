# Rework 02 contract — TASK-260715-u8tkx0

Read the attached `TASK-260715-u8tkx0_reviewer-results-rework-01-input.md`. Rework 01 closed every prior finding except AC2: the strict update sequence is not executable against the current supply-chain generator.

Required correction:

1. Resolve the step 6 / step 9 contradiction. `scripts/relay_supply_chain.py generate()` immediately validates that `relay/supply-chain-source-v1.json` revision/version/artifact manifest constants match `relay/asset-bundle-source-v1.json`, then rewrites the asset source supply-chain reference and generated Swift catalog. A changed source/version/archive cannot run generation while the old asset contract remains active.
2. Document one supported coordinated metadata rotation boundary, or an executable two-phase staging boundary, that preserves the invariant: no accepted-tree source contract or generated catalog is mutated before reproducibility and all four native runtime rows pass. Identify every exact update surface, including the validator's accepted-artifact task/resource/SHA constants.
3. Make the ordering unambiguous and copy-paste executable. It must preserve the mandated logical order (source/dependency/protocol/build/notices/provenance/repro/smoke/manifest/bundle/bootstrap) without asking the generator to validate mutually inconsistent old/new contracts.
4. Reproduce a deliberately changed candidate in an isolated task-scoped copy. Execute the documented sequence through coordinated contract/policy rotation and generation; prove success while `git diff`/hashes show the accepted repository tree was not mutated by the trial.
5. Update the runbook, handoff outcome, and LOGBOOK with the contradiction and resolution. Preserve all already accepted historical/current reproducibility, manifest-role, rollback, compromise, RACI, task-ID, privacy, and build-only evidence.
6. Re-run focused tests, link/shell-block checks, workspace/macOS validation, `git diff --check`, and `task-board validate`. Do not commit/push or perform real VPN/system-network actions.

Return to `to-review` only with exact commands, exits, and evidence closing AC2.
