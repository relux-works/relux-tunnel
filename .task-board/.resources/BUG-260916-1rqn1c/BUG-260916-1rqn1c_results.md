# BUG-260916-1rqn1c results: hosted native Xcode toolchain alignment

## Diagnosis (hosted evidence)

PR6 `d45c85d67b78b6578b5cb0821bd2e78217124d30`, hosted run 35091586150,
job `generated project credential-free validation` (ID 104778924295):
all gate stages PASS through `swift-release-build`, then `native-packaging`
(`make check-native-dependencies`) FAILS with exit 2:

```
python3 scripts/libssh2-fork-tool.py verify
+ xcodebuild -version
libssh2-fork-tool: Xcode build mismatch: expected Build version 17F42, got Xcode 16.4
Build version 16F6
```

Root cause: the job runs on `macos-15`, whose default AND selectable Xcodes
cannot satisfy the manifest pin. Official inventory
(actions/runner-images, image 20260907.0351.1) shows macos-15[-arm64] ships
at most Xcode 26.3 (17C529) with default Xcode 16.4 (16F6), while the pinned
Xcode 26.5 (17F42) at `/Applications/Xcode_26.5.app` exists only on the
GA `macos-26`/`macos-26-arm64` images — whose default is Xcode 26.6
(17F113), so an explicit selection is required on top of the image move.
Full tables: `BUG-260916-1rqn1c_toolchain-evidence.md`.

Both manifest pins agree on the single toolchain (`libssh2-openssl`
`compiler.xcode_build` == `hev-lwip` `rebuild.xcode_build` == `17F42`);
the libssh2 pin is enforced at verify time by
`verify_xcode_build` in `scripts/libssh2-fork-tool.py`, the hev pin governs
rebuild provenance. No pin, artifact, or product byte changes.

## Fix (narrow compatibility delta)

1. `.github/workflows/ci.yml`, job `generated-project-credential-free`:
   `runs-on: macos-15` -> `macos-26` (arm64 label, so the arm64 Mise
   checksum pairing is unchanged), plus a step running
   `sh ./scripts/select-native-xcode.sh` before the credential-free gate.
2. `scripts/select-native-xcode.sh` (new): reads both manifest pins, refuses
   on missing/disagreeing pins (exit 2) and on builds with no supported
   hosted Xcode (exit 2, fail closed), selects the mapped Xcode via
   `xcode-select -s` (skipped when already selected), then verifies
   `xcodebuild -version` contains `Build version <pin>` (exit 1 on
   mismatch, same wording as the downstream gate).
3. `scripts/tests/test_native_toolchain_alignment.py` (new, 12 tests) and
   `scripts/tests/test_native_toolchain_mutants.py` (new harness).

Not changed: manifest pins, native artifacts, strict version checks,
`verify_xcode_build`, product sources, other CI jobs (relay jobs never run
native packaging). No VPN, no weakened checks.

## Prerequisite stack identity (reused bytes, NOT new scope)

- PR6 head: `d45c85d67b78b6578b5cb0821bd2e78217124d30` (verified via
  rev-parse; also origin PR #6 head `delivery/STORY-260715-1y04r0-rev3`).
- Worktree HEAD (unmoved, nothing committed):
  `b3422b05226253a17676b9b84c764071fe3dbe74` on
  `task-board/story/STORY-260916-19w99a`.
- Overlay: all 59 tracked non-board paths checked out from PR6 head;
  every staged blob byte-equal to PR6 head; staged stat 59 files,
  8970 insertions, 65 deletions (same set as BUG-260916-2764p8).
- Candidate layout: staged = prerequisite overlay; unstaged = ci.yml
  delta; untracked = 3 new files (snapshot-captured); `.task-board`
  artifact untouched.

## New delta identity (vs PR6 head, non-board)

- `.github/workflows/ci.yml`: 10 insertions, 2 deletions;
  blob `740e64f93cc34a3e55e5141502fe58012f0973a2` ->
  `205b10013422af7e43ead2a0fcd1b20ac627a4eb`.
- `scripts/select-native-xcode.sh` (new, +x): blob
  `2489aa2dc776d5266ea68f45282b4493c356e2d6`.
- `scripts/tests/test_native_toolchain_alignment.py` (new): blob
  `d53f9a42bc9eb2a49d039ff53dae429a997b1188`.
- `scripts/tests/test_native_toolchain_mutants.py` (new): blob
  `75dc0d05a6e6dea6c3864c5c4b778919d0a4e19a`.
- Prospective PR composition: PR6 head `d45c85d` + the 4 paths above.
  The handoff publishes the exact candidate CR (tree OIDs + patch).

## Validation (exit codes observed on the composed candidate)

- New suite `test_native_toolchain_alignment.py`: 12/12 pass, exit 0.
  Pre-fix it failed on the overlay tree (`runs-on: macos-26` not found,
  no selection step) — authentic defect reproduced before the change.
- Mutant harness `test_native_toolchain_mutants.py`: baseline 12/12
  green, both mutants killed, exit 0 (see below).
- `make check-native-dependencies` (exact hosted failing command):
  exit 0 — strict gate passes where the toolchain matches (local
  Xcode 26.5, build 17F42).
- Downstream strictness preserved: `DEVELOPER_DIR=<Xcode 26.6>`
  `libssh2-fork-tool.py verify` fails exit 1 with
  `expected Build version 17F42, got Xcode 26.6 / Build version 17F113`
  (no system state mutated; override only). The macos-26 default is
  rejected, proving explicit selection is necessary, not just the move.
- Real `sh scripts/select-native-xcode.sh`: exit 2 fail-closed
  (`/Applications/Xcode_26.5.app is not installed`) — this dev machine
  names its install `Xcode_26_5.app`; hosted runners use the documented
  dotted name. Refusal precedes any system change. See bounds.
- Workflow YAML parses (`yaml.safe_load`, same check CI runs).
- `swift build`: exit 0 on the composed candidate.
- Neighbor `test_macos_build_diagnostics.py`: 3/3 pass, exit 0.
- `git diff --check`: clean. No linter configured in repo (no Makefile
  lint target, no hidden linter configs) — nothing to run.

## AC coverage: 4 of 6 rows driven through production entry

Production call sites: `.github/workflows/ci.yml`
(`generated-project-credential-free` job) -> `scripts/select-native-xcode.sh`
-> downstream `scripts/libssh2-fork-tool.py verify` (`verify_xcode_build`).

1. Narrow reproducible fix — DRIVEN: ci.yml runs-on + selection step;
   covered by `test_workflow_runs_credential_free_job_on_macos26`,
   `test_workflow_selects_pinned_xcode_before_gate`, and 7 behavioral
   selection tests through the production script.
2. Independent review — STATED BOUND: reviewer stage, not producer-driven.
3. Exact prospective PR composition identity — DRIVEN: identities above;
   reviewer verifies staged tree == PR6 head minus board, then 4-path delta.
4. Targeted validation — DRIVEN: 12-test suite + mutant harness + gates
   above, all with observed exit codes.
5. Honest hosted validation requirements handed to parent — DRIVEN: this
   outcome + toolchain-evidence resource + bounds below.
6. Real hosted publication/landing — STATED BOUND: parent delivery
   obligation, explicitly out of producer scope.

## Negative tests and narrowing mutants

Production call site for all: `scripts/select-native-xcode.sh`
(invoked as `sh <script>` with `RELUX_NATIVE_MANIFEST` /
`RELUX_XCODE_ROOT` fixtures and PATH shims for `xcode-select`,
`xcodebuild`, `sudo`).

- `test_selection_rejects_xcode16_default`: 16F6 output -> nonzero exit +
  `mismatch` (mirrors run35091586150).
- `test_selection_rejects_macos26_default_build`: 17F113 (macos-26
  default) -> nonzero exit + `mismatch`.
- `test_selection_refuses_disagreeing_manifest_pins`,
  `test_selection_refuses_unmapped_build`,
  `test_selection_refuses_missing_pin`,
  `test_selection_refuses_missing_install`: exit 2 refusals.
- Mutant `admit-macos26-default-only` (gate stays present, additionally
  admits 17F113): killed by `test_selection_rejects_macos26_default_build`
  (exit 1, AssertionError).
- Mutant `select-wrong-app-preserves-token` (every `17F42` literal kept,
  mapped app changed to Xcode_26.6.app): full 12-test behavioral suite
  run, killed by `test_selection_maps_manifest_pin_to_documented_app`
  and `test_selection_is_idempotent_when_already_selected` on the
  recorded selection path (exit 1).

## Toolchain / proof bounds (honest)

- Hosted proof (macos-26 + selection => native-packaging green) requires
  publishing the prospective PR and observing run35091586150's successor;
  that is a parent delivery gate, not claimed here.
- The image move upgrades the whole credential-free job from Xcode 16.4
  (Swift 6.1) to Xcode 26.5 (Swift 6.3.2-class). Currently-passing
  stages (macos targets, swift tests) are expected to pass — local
  Swift 6.3.2 + Xcode 26.5 builds and tests green — but hosted
  confirmation is pending by construction.
- Local real-run of the selection script cannot go green: this machine
  installs the pinned toolchain as `/Applications/Xcode_26_5.app`
  (underscores) while hosted runners use `/Applications/Xcode_26.5.app`
  (documented). Hermetic behavioral tests stage the documented layout.
- Full `credential-free-validate` not run locally (needs the legacy
  relux-proxy checkout and ~11 hosted minutes); focused native gate
  (`check-native-dependencies`), build, and contract suites are the bound.
- Alternative rejected: repinning the manifest to a macos-15 Xcode and
  rebuilding artifacts would churn artifact provenance and break local/CI
  parity; explicitly out of scope per brief.

## Prospective composition boundary

Uncommitted candidate = exact PR6 prerequisite bytes (staged, 59 files)
+ ci.yml toolchain delta (unstaged) + selection script and 2 test files
(untracked). Review: verify staged tree equals PR6 head minus board,
then review the 4-path delta and this outcome. No publication, branch
commit, VPN operation, or unrelated fix performed. Ready for review.
