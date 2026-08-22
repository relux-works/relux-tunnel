# TASK-260715-u8tkx0 fresh reviewer verdict after rework 02

Date: 2026-08-22
Role: reviewer
Verdict: changes requested (`to-dev`)

## Result

Rework 02 closes the coordinated metadata-rotation contradiction. The staged
ten-file update is consistent with the current generator, validators, archive
defaults, Swift acceptance assertions, and generated outputs. The task is not
accepted because the documented deterministic update block is not copy-paste
executable from a genuinely fresh clone: it creates a task-scoped directory
with `mktemp` below `$REPO/.temp`, but neither the block nor its stated
prerequisites create the untracked `.temp` parent.

## Material finding

Following the current-candidate block exactly in a fresh no-local/no-hardlink
repository copy failed before the first clone/build command:

```text
mktemp: mkdtemp failed on <review-root>/repository/.temp/TASK-260715-u8tkx0.full-release.<suffix>: No such file or directory
```

The published command at `docs/relay-asset-release-runbook.md:396` exited `1`.
The repository does not track `.temp`, and the preceding prerequisite block
does not create it. Adding the single undocumented setup command
`mkdir -p .temp` in the disposable review copy allowed the exact fenced blocks
to complete. This violates AC1 and the independent-review requirement that
every command be executable from the stated directory without tribal setup.

Required correction: create `$REPO/.temp` explicitly before the deterministic
`mktemp` call (or establish an equally explicit earlier prerequisite), then
rerun the shell-block and fresh-clone gate. Check every other `mktemp` parent
for the same fresh-checkout assumption.

## Independent execution evidence

- Historical lane: exit `0`. Two independent split-pin builds produced exact
  four-target bytes and byte-identical archives matching the retained archive
  SHA-256 `1f0ba226ed591d1baf5f9464b33e45b7658a33bf5a1a114e77b6d22d3d9eef4e`.
  All four documented sizes/hashes matched. Two trusted five-file bundles
  generated and checked independently and matched the accepted trusted
  application manifest.
- Deterministic block in a fresh clone as published: exit `1` at `mktemp`
  because `.temp` was absent. This is the rejecting evidence.
- Environmental retry with `.temp` created but only 1.0 GiB free: exit `1`
  from `go build`. Disposable review roots were removed; a later retry had
  adequate space and passed, so this capacity event is not attributed to the
  runbook implementation.
- Deterministic retry after the one added `mkdir -p .temp`: exit `0`.
  Comparator output was `relay reproducibility: identical=15/15`; archive
  SHA-256 was `09014b22e694b1ff4ab664c81d46b3afccd5a973f701cbd4625bfd88c093ab40`;
  release-builder manifest SHA-256 was
  `ef5bd8b3cc41ce0e30c026bd088b370faeea30d789a7c6708631330afe8b049d`.
- Native Darwin/arm64 smoke: exit `0`, `17/17`. Unsupported native
  Linux/amd64 request on Darwin/arm64: expected gate exit `1`, bounded
  `native_runner_identity_mismatch`, no artifact observation, and no process
  start.
- Coordinated rotation in the disposable copy: exit `0`. Candidate archive
  board-resource add/get and `cmp` passed. Generation/audit passed; 21
  supply-chain Python tests, 26 asset-manifest Python tests, and four Swift
  manifest tests passed twice; bundle check passed; exact changed set was
  `10/10`; staged and applied copies compared byte-identically.
- The ten accepted repository metadata surfaces remained byte-identical after
  the trial (`10/10` SHA-256 checks reported `OK`). The pre-apply guards run
  before `git apply`; `set -eu` stops any failed post-apply generator/audit/test
  without permitting continuation to later bundle/bootstrap gates.
- Two post-rotation trusted application manifests and complete five-file
  bundles matched. Copied-bundle drift produced expected `make` exit `2` and
  `relay asset size does not match the manifest`; the suspect copy was not run.
- Main-tree focused suites: 107 Python tests passed; toolchain positive and
  missing-input gates, supply-chain audit, and trusted bundle check exited `0`.
- Workspace generation/validation and macOS target validation exited `0`.
  Only documented Xcode destination/product-name and deprecation/linker
  warnings appeared.
- Runbook shell syntax `14/14`, changed-document local links `48/48`, live
  concrete task IDs `33/33`, added-content sensitive/absolute-path scan, and
  `git diff --check` all exited `0`.
- `task-board validate` process exit was `0`; it reports the existing
  `PARENT_STATUS_MISMATCH` for `EPIC-260715-2lz67t`, whose displayed aggregate
  follows this task's review status.

## Acceptance assessment

- AC1: not accepted. The fresh-clone deterministic block requires an
  undocumented `.temp` parent creation.
- AC2: accepted in substance. The release-builder/repository-generator split
  and coordinated ten-file rotation are executable and preserve the mandated
  order once the scratch parent exists.
- AC3: accepted. Rollback retains exact known-good bytes/manifests, separates
  coexistence from replacement, and forbids unverified remote execution.
- AC4: accepted. RACI separates source/hash/notices from application signing,
  notarization, attestation, and human approval.
- AC5: accepted. Drift, missing target, unsupported runtime, notice failure,
  compromised inputs, credential-safe evidence, M2/M5 owners, and all ten
  downstream consumers are covered by live concrete IDs.

## Safety

The review was rootless and build-only. It did not sign, notarize, attest,
publish, install, launch an app/provider, access credentials, configure or
start a VPN, change NetworkExtension preferences, or mutate routes, DNS,
interfaces, or packet filters. No mismatched or remote executable was run.
