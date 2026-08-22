# TASK-260715-u8tkx0 independent reviewer evidence

Date: 2026-08-19
Role: reviewer
Verdict: changes requested (`to-dev`)

## Material finding

The four unsigned executables, normalized archive, and trusted application
manifest are independently reproducible, but the strict update procedure is
not executable end to end as documented.

The runbook directs operators to build the full release tree in both independent
clones and then run `scripts/relay_release.py compare` for the expected
`relay reproducibility: identical=15/15` result. Following that procedure with
the documented accepted split source/recipe pins produced two successful full
builds, but the four SPDX documents differed in their Syft-generated
`documentNamespace` UUIDs and wall-clock `creationInfo.created` values. The
release-builder manifests and SHA256SUMS therefore differed as well; manifest
`cmp` exited 1. A direct comparison across the two independent clone paths also
exited 1 with `relay-release: output paths must remain under .build/relay`.

This contradicts the no-variance expectation in the strict update procedure and
leaves no documented, copy/paste-safe comparator invocation. The same section
names the native smoke and double-generation bundle gates without supplying the
required arguments, evidence paths, report assertions, or complete comparison
commands. A second operator can infer these from tool help, but the task
contract explicitly requires runnable commands without tribal knowledge.

Relevant runbook locations are the per-clone metadata build and 15/15 claim at
lines 277-289, the native-smoke prose at lines 297-306, the double-generation
bundle prose at lines 307-311, and the split-pin full-build command at lines
328-345.

## Independent execution evidence

- Pinned Go 1.26.5 and Syft 1.48.0 identities, full-history Git prerequisites,
  source commit, recipe commit, and `make relay-supply-chain-audit`: exit 0;
  audit token `relay supply-chain audit: pass`.
- Retained archive retrieval and accepted SHA-256 verification: exit 0.
- Two independent no-local/no-hardlink clones: clean source checks, three-file
  recipe overlay, compiled-source diff, toolchain checks, and all eight target
  builds exited 0.
- Clone A versus clone B normalized archive `cmp`: exit 0. Rebuilt versus
  retained archive `cmp`: exit 0. Archive SHA-256 was
  `1f0ba226ed591d1baf5f9464b33e45b7658a33bf5a1a114e77b6d22d3d9eef4e`.
  All four executable sizes and hashes matched the runbook exactly.
- Trusted application bundle generation A/check A/generation B/check B: every
  command exited 0 with the documented pass tokens. Complete bundle comparison
  and comparison to the current trusted manifest exited 0; the tree contained
  exactly four executables plus `relux-relay-assets-v1.json`.
- Full release-tree build in each clone: exit 0. Direct cross-clone comparator:
  exit 1 due to path containment. Release-builder manifest `cmp`: exit 1 due to
  four differing SPDX hashes. This is the rejecting discrepancy above.
- Native Darwin arm64 smoke against `relux-relay-manifest-v1.json`: exit 0,
  `status=pass`, matching host/target, native evidence true, 17/17 checks pass.
- Copied-bundle size/hash drift gate: `make relay-asset-bundle-check` exited 2
  with `relay asset size does not match the manifest`; no suspect executable ran.
- Required native Linux amd64 on the Darwin arm64 runner: exit 1 before process
  start with `native_runner_identity_mismatch`, failed native evidence, and a
  bounded JSON report.
- Toolchain check and missing-input negative test: exit 0. Focused relay release,
  supply-chain, asset-manifest, and runtime-smoke Python suites: 107 tests pass,
  exit 0. Swift `RelayAssetManifestTests`: four tests pass, exit 0.
- Workspace generation/validation and macOS target validation: exit 0, including
  exact relay resource graph enforcement. `git diff --check`: exit 0.
- Documentation link check: 48 local links pass. Added-content absolute-path and
  secret scan: exit 0. All 32 concrete M2, protocol, bootstrap, M5, and incident
  task IDs resolve on the live board with the documented titles, parents, and
  statuses.
- `task-board validate`: process exit 0 while reporting the existing
  `PARENT_STATUS_MISMATCH` for `EPIC-260715-2lz67t`; the task transition changes
  only the reported child aggregate, not the pre-existing stored backlog state.

## Acceptance assessment

- AC1: the accepted executable bytes, archive, and trusted manifest reproduce;
  the second release-builder manifest layer exposes the discrepancy above.
- AC2: not accepted. Exact reproducibility and native-smoke invocations are
  incomplete, and the demonstrated split-pin full-tree path cannot produce the
  claimed 15/15 result.
- AC3: accepted. Rollback preserves retained exact bytes/manifests, distinguishes
  coexistence from replacement, and prohibits pre-verification execution.
- AC4: accepted. Responsibility boundaries separate M2 source/hash/notices from
  M5 application signing, notarization, attestation, and approval.
- AC5: accepted. Required failure classes, compromise response, credential-safe
  evidence, and concrete task ownership are present and semantically valid.

## Required rework

1. Provide an actually supported two-clone full-release reproducibility recipe,
   including containment-safe staging and the exact `compare` arguments, or
   explicitly delimit the historical SPDX/manifest behavior and use a verified
   deterministic metadata path. Do not claim 15/15 for the demonstrated
   historical path until it is independently reproduced.
2. Add copy/paste-ready native-smoke commands for all required arguments and
   bounded report assertions, plus exact double bundle generation/comparison
   and red-path commands with expected exit behavior.
3. State precisely which of `relux-relay-manifest-v1.json` and
   `relux-relay-assets-v1.json` is regenerated and compared at each audit/update
   stage, and whether historical SPDX bytes are expected to be retained or
   reproducible.
4. Record this full-release metadata anomaly in the producer handoff/logbook,
   then rerun the independent procedure before requesting review again.

## Safety

The review was offline after retained local tool/archive provisioning and was
rootless. It did not sign, notarize, attest, access credentials, publish,
install, launch an app/provider, configure or start a VPN, modify
NetworkExtension preferences, or mutate routes, DNS, interfaces, or packet
filters. No remote or mismatched executable was run.
