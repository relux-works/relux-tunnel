# TASK-260715-u8tkx0 fresh reviewer verdict after rework 01

Date: 2026-08-19
Role: reviewer
Verdict: changes requested (`to-dev`)

## Result

Rework 01 closes the prior raw-Syft reproducibility, cross-clone containment,
manifest-role, and missing-command findings. The task is not accepted because
the strict update sequence still contradicts the current supply-chain
generator and cannot be followed in its documented order for a changed source,
version, or archive.

## Material finding

Runbook step 6 instructs the operator to update authoritative source/build
provenance and dependency inputs and run `make relay-supply-chain-generate`
before reproducibility and native smoke. Step 9 says only after all four native
rows pass may the operator rotate `relay/asset-bundle-source-v1.json`, update
`relay/supply-chain-source-v1.json`, and regenerate.

The current implementation does not support that split. In
`scripts/relay_supply_chain.py`, `generate()` immediately calls
`validate_config()`. That validation requires the supply-chain source revision
and relay version to equal the still-current asset source contract, and it
requires the artifact manifest block to equal the exact accepted archive task,
resource name, and SHA-256. Generation then rewrites the asset source contract's
supply-chain reference and generated Swift catalog. Therefore a source/version
update cannot pass step 6 while the asset contract remains unrotated until step
9; rotating the contract early bypasses the documented order. The runbook also
does not identify the validator's exact accepted-artifact constants as an
update surface.

This fails AC2's no-bypass update order and the requirement that documentation
remain consistent with current code. Correct the procedure by defining an
executable two-phase metadata boundary or by moving/documenting the coordinated
asset-contract, supply-chain-policy, and generated-output rotation at the one
supported point. Reproduce a changed candidate in a task-scoped copy and show
the documented sequence succeeds without mutating the accepted tree in place.

## Independent execution evidence

- Pinned Go 1.26.5 and Syft 1.48.0 identities, full-history commits, and
  `make relay-supply-chain-audit`: exit 0; `relay supply-chain audit: pass`.
- Retained archive retrieval and SHA-256 verification: exit 0.
- Historical split-pin lane: two no-local/no-hardlink clones, eight clean-cache
  builds, compiled-source checks, two normalized archives, retained-archive
  comparison, and all four documented size/hash tuples: exit 0. Archive SHA-256
  is `1f0ba226ed591d1baf5f9464b33e45b7658a33bf5a1a114e77b6d22d3d9eef4e`.
- Two independent trusted five-file bundle generations/checks and comparison to
  the default accepted manifest: exit 0. Trusted manifest SHA-256 is
  `bd9428e6de9caa63f659b87d89914be09fe280c1964fbd2064c84af5c9d62614`.
- Deterministic current path: two fresh clones, exact 11 release files plus four
  protocol-test executables, containment-safe comparator, and two archives:
  exit 0; `relay reproducibility: identical=15/15`. Archive SHA-256 is
  `09014b22e694b1ff4ab664c81d46b3afccd5a973f701cbd4625bfd88c093ab40`;
  release-builder manifest SHA-256 is
  `ef5bd8b3cc41ce0e30c026bd088b370faeea30d789a7c6708631330afe8b049d`.
- Native Darwin/arm64 smoke: exit 0 and 17/17 checks pass. Native Linux/amd64 on
  Darwin/arm64: expected exit 1, `native_runner_identity_mismatch`, no artifact
  observation, and no process start.
- Copied trusted-bundle drift: expected `make` exit 2 with
  `relay asset size does not match the manifest`; no suspect file ran.
- Four focused Python suites: 107 tests pass, exit 0. Swift
  `RelayAssetManifestTests`: four tests pass, exit 0. Toolchain negative gate,
  asset bundle check, 26 manifest Python tests, and repeated Swift manifest
  tests: exit 0.
- Workspace generation/validation and macOS target validation: exit 0; exact
  generated relay resource graph passes.
- Documentation links: 48 local links pass. All 12 shell blocks pass `bash -n`.
  Added-content absolute-path/credential scan and `git diff --check`: exit 0.
- All 33 task IDs present in the runbook, including the current task, resolve on
  the live board with matching titles, parents, and stated statuses. The seven
  M2 build gates, protocol gate, ten downstream bootstrap consumers, and M5
  ownership links are semantically correct.
- `task-board validate`: process exit 0 while reporting the existing
  `PARENT_STATUS_MISMATCH` for `EPIC-260715-2lz67t`; the displayed aggregate is
  `reviewing` because this reviewer set the assigned task to `reviewing`.

## Acceptance assessment

- AC1: accepted. Historical exact bytes/archive and the trusted application
  manifest reproduce using the documented commands.
- AC2: not accepted due to the step 6/step 9 generator and contract-order
  contradiction above.
- AC3: accepted. Rollback preserves known exact bytes/manifests, distinguishes
  coexistence from replacement, and prohibits pre-verification execution.
- AC4: accepted. RACI separates M2 source/hash/notices from M5 application
  signing, notarization, attestation, and approval.
- AC5: accepted. Required failures, compromise handling, credential-safe
  evidence, and concrete task ownership are documented and live-board-valid.

## Safety

The review was rootless and build-only. It did not sign, notarize, attest,
publish, install, launch an app/provider, configure or start a VPN, change
NetworkExtension preferences, or mutate routes, DNS, interfaces, or packet
filters. No remote or mismatched executable ran.
