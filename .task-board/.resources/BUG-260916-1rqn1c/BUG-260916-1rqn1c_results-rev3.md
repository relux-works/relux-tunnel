# BUG-260916-1rqn1c rev3: rework of the two review-rev2 findings

Only `review-verdict-rev2.md` findings 1 and 2 are addressed. Diagnosis,
official toolchain evidence, runner choice (`macos-26` + explicit `17F42`
selection), and the rev1/rev2 outcomes are unchanged and not repeated here.

## Finding 1 — selector substring attestation (fixed)

`scripts/select-native-xcode.sh` matched `*"Build version $expected_build"*`,
so `Build version 17F420` was falsely attested as `17F42`. Reproduced pre-fix
via the existing PATH-shim harness: exit 0,
`using .../Xcode_26.5.app (Build version 17F42)`.

Fix: extract the complete token after the trailing `^Build version ` line and
compare exactly (`[ "$actual_build" != "$expected_build" ]`). Post-fix the
same probe exits 1 with the unchanged `mismatch` message. The legacy
`libssh2-fork-tool.py verify_xcode_build` substring behavior is pre-existing
and untouched (outside this slice per brief).

New named negative: `test_selection_rejects_build_with_pin_as_prefix`
(production call site: `scripts/select-native-xcode.sh` verification gate).
New suffix-only narrowing mutant `admit-suffix-build-only` (gate kept,
additionally admits exactly `17F420`), killed by that named test (exit 1).

## Finding 2 — source-text-only workflow guard (fixed)

`test_workflow_selects_pinned_xcode_before_gate` only greps the workflow.
Reproduced pre-fix: `run: echo sh ./scripts/select-native-xcode.sh` in the
copied workflow (token preserved, execution disabled) still exits 0 over the
full 12-test suite.

Fix: new test `test_workflow_selection_command_executes_and_selects_pin`
extracts the exact `run:` command of the selection step from the
credential-free job (asserts exactly one invocation), executes it with the
same PATH shims, and proves selection effects (exit 0, recorded path is the
pinned `Contents/Developer`, `(Build version 17F42)` reported). Post-fix the
reviewer's echo-bypass fails the suite (exit 1, exactly that test; the static
guard still passes, proving the token is preserved). Shared fixture setup was
factored into `selection_fixture`; all pre-existing behavioral tests run
through it unchanged. The static ordering test is kept.

New token-preserving mutant `workflow-selection-echo-preserves-token`
(target `.github/workflows/ci.yml`), killed by the full 14-test behavioral
suite. Plus narrowing mutants for the three refusal gates the reviewer called
out (each gate kept, admits exactly one member):
- `admit-one-disagreeing-pin-pair` (admits 17F42/17C529) -> killed by
  `test_selection_refuses_disagreeing_manifest_pins`
- `admit-one-unmapped-build` (admits 17C529 via the staged decoy app, so the
  kill proves mapping-gate admission, not the install gate) -> killed by
  `test_selection_refuses_unmapped_build`
- `admit-one-missing-install` (admits missing Xcode_26.5.app) -> killed by
  `test_selection_refuses_missing_install`
Existing `admit-macos26-default-only` was re-anchored to the rewritten gate
(admits exactly 17F113); still killed by its named test. The harness is now
target-aware (script or workflow per mutant).

## Identities (vs PR6 head d45c85d, non-board)

- HEAD unmoved at `b3422b05226253a17676b9b84c764071fe3dbe74`; nothing committed.
- Overlay: 59/59 staged entries byte-equal to PR6 blobs (checked=59 mismatch=0).
- Unchanged from rev2: ci.yml `205b10013422af7e43ead2a0fcd1b20ac627a4eb`,
  contract `0163045f360692a9940938d7e34b4f376cf5df03`.
- New bytes: select-native-xcode.sh
  `0575eaddec932b6f100ca5e60431a30061ce324f` (100755),
  alignment `22d2c1edfac56a717b67c2220c1548c568139fdc`,
  mutants `0d67c482239e0b52db1f50168bdfb04aee07ee76`.
- Prospective PR composition: PR6 head + these 5 paths (modes included) =
  tree `008148dc2967e563f973234d3e944f51b120f456`; prospective diff is exactly
  the 5 paths (496 insertions, 3 deletions). Layout: staged = prerequisite
  overlay; unstaged = ci.yml + contract deltas; untracked = selector + 2 tests.
- `NativeDependencies/manifest.json` identical across HEAD/index/worktree/PR6
  (`31e39df3...`); no manifest/artifact/product/deployment-target change.

## Validation (exact exit codes, no tail masking)

- Pre-fix probes: 17F420 -> script exit 0 (false accept); echo-bypass ->
  suite exit 0, 12 OK (blind). Both authentic failures observed before editing.
- `python3 scripts/tests/test_native_toolchain_alignment.py`: exit 0, 14 OK.
- `python3 scripts/tests/test_native_toolchain_mutants.py`: exit 0; baseline
  exit 0; all 7 narrowing mutants killed (2 re-anchored/pre-existing + 5 new),
  each by its documented test; token-preserving mutants run the full suite.
- `sh scripts/tests/test-credential-free-validation.sh`: exit 0 (scheme
  fixtures, macos-26/mise/arm64/gate assertions, provider-graph guard, macos
  diagnostics + 3 mutants, native alignment 14/14 + 7 mutants, pass banner).
- `sh -n` on the selector clean; `git diff --check` clean.
- No linter configured (no Makefile lint target, no hidden linter configs).
- Not rerun: full `make credential-free-validate` and `check-native-dependencies`
  (owned by the handoff automatic CR gate; their paths are untouched since the
  rev2 green, and the brief forbids redundant exhaustive runs).

## AC coverage: 2 of 6 rows driven by executable tests (corrected per reviewer)

Production call sites: `.github/workflows/ci.yml`
(`generated-project-credential-free` selection step) ->
`scripts/select-native-xcode.sh` -> shimmed `xcode-select`/`xcodebuild`;
contract entry `scripts/tests/test-credential-free-validation.sh` (wired via
`Makefile credential-free-validate` -> `scripts/validate-credential-free.sh`).

1. Narrow reproducible fix -- DRIVEN: exact-match selector + executable
   workflow-command test, 14/14 green through the production gate lane.
2. Independent review -- STATED BOUND: reviewer stage.
3. Exact prospective PR composition identity -- STATED BOUND: manual identity
   computation above, not an executable test (corrected from rev2).
4. Targeted validation -- DRIVEN: contract lane exit 0 incl. 7-mutant harness.
5. Honest hosted validation requirements -- STATED BOUND: this outcome + rev1,
   rev2, toolchain-evidence prose (corrected from rev2).
6. Real hosted publication/landing -- STATED BOUND: parent delivery duty.

Negative/narrowing evidence: 16F6, 17F113, and 17F420 rejections (exit 1 +
`mismatch`); disagreeing/unmapped/missing-pin and missing-install refusals
(exit 2); 7 narrowing mutants each killed by a named/full behavioral suite
through the production entry points above.

## Bounds

- Hosted proof still requires publishing the prospective PR (parent duty).
- No global xcode-select change: every selector execution in this run used
  PATH shims (sudo intercepted); `xcode-select -p` was only read
  (`/Applications/Xcode_26_5.app/Contents/Developer`). No commits, branch
  operations, publication, VPN, nested workers, or root LOGBOOK writes.
- Existing task-local mise trust already resolved; not redone.

Ready for review: uncommitted candidate + this outcome handed to review.
