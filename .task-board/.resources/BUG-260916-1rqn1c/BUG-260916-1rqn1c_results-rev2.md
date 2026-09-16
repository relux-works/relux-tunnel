# BUG-260916-1rqn1c rev2: recovery from CR rev1 gate failure (authoritative handoff evidence)

Supersedes rev1 validation only. Diagnosis, official toolchain tables, and the
four-path delta are unchanged from `BUG-260916-1rqn1c_results.md` (rev1) and
`BUG-260916-1rqn1c_toolchain-evidence.md`; all four rev1 blobs re-verified
byte-identical in this run (see identities).

## Why rev1 failed the CR gate (two distinct causes, separated)

CR rev1 ran the exact candidate gate
`LEGACY_ROOT=.../relux-proxy make credential-free-validate` and stopped at
`validation-contract-tests`, exit 1, with an EMPTY inner log
(`validation-contract-tests.log`, 0 bytes).

Cause A -- mise trust noise (NOT the failure): the outer log showed
`mise ERROR ... mise.toml ... not trusted`. Source: the metadata block of
`scripts/validate-credential-free.sh` runs `mise exec -- tuist version` with
stdout redirected but stderr leaking to the console; under `set -u` (no `-e`)
the empty substitution does not fail the gate (`relay-packaging` PASSes
after it). Fix: inspected the exact worktree config (`[tools]
tuist = "4.202.5"`, byte-identical in HEAD, PR6 head, and worktree) and ran
the brief-authorized `mise trust` BEFORE rerunning the gate. Trust errors
are now gone from the gate log (only a version-update WARN remains).

Cause B -- the actual failure (this fix caused it, this fix repairs it): the
rev1 runner move (`runs-on: macos-15` -> `macos-26`) tripped the hardcoded
in-repo contract `runner_label="    runs-on: macos-15"` in
`scripts/tests/test-credential-free-validation.sh:55`. `test 0 -eq 1` exits 1
with no output, which is exactly the observed empty-log exit-1. Reproduced
pre-edit in this run: `sh scripts/tests/test-credential-free-validation.sh`
-> exit 1, 0 bytes. The old expectation is wrong because macos-15 cannot
provide the manifest-pinned Xcode 17F42 (official inventory: macos-15 tops
at Xcode 26.3/17C529, default 16.4/16F6 -- the hosted failure itself), so the
contract must track the supported runner. Both causes are now fixed; the
inner log is no longer empty.

## Recovery delta (one path, in scope)

`scripts/tests/test-credential-free-validation.sh` (staged PR bytes stay
staged; recovery is unstaged, like ci.yml):
1. `runner_label`: `macos-15` -> `macos-26` plus a 2-line rationale comment.
   All other contract assertions unchanged (mise action pin, version
   2026.3.10, arm64 checksum, install:false, single gate invocation,
   runner<miseline<checksum/gate ordering). The arm64 checksum pairing is
   preserved because macos-26 is the arm64 image.
2. Wired the rev1 regression suites into this existing gate, mirroring the
   adjacent macos-diagnostics precedent (suite + mutant harness, no new job):
   `test_native_toolchain_alignment.py` and
   `test_native_toolchain_mutants.py`. They now run on every local and hosted
   gate invocation. No product, manifest, artifact, or deployment-target
   change; relay matrix runners untouched.

## Identities (vs PR6 head d45c85d, non-board)

- Overlay: 59 staged paths, re-verified byte-equal to PR6 head
  (checked=59 mismatch=0). HEAD unmoved at
  `b3422b05226253a17676b9b84c764071fe3dbe74`; nothing committed.
- Rev1 four paths re-verified: ci.yml `205b1001...`,
  select-native-xcode.sh `2489aa2d...`, alignment `d53f9a42...`,
  mutants `75dc0d05...` (full hashes in rev1 outcome).
- Recovery fifth path: `scripts/tests/test-credential-free-validation.sh`
  `156fc56167320226ec6f07fb4bd12d0d35e1d320` ->
  `0163045f360692a9940938d7e34b4f376cf5df03` (+6/-1 lines).
- Prospective PR composition: PR6 head `d45c85d` + these 5 paths.
  Layout: staged = prerequisite overlay; unstaged = ci.yml + contract
  deltas; untracked = selection script + 2 test files.

## Validation (exact exit codes, no tail masking, composed candidate)

- Contract step pre-fix: exit 1, 0 bytes (authentic failure reproduced).
- `sh scripts/tests/test-credential-free-validation.sh`: exit 0 --
  scheme fixtures, 1x macos-26 label, mise/arm64/gate assertions,
  provider-graph guard, macos diagnostics 3/3 OK + 3 mutants killed,
  native alignment 12/12 OK + 2 mutants killed, pass banner.
- FULL `LEGACY_ROOT=/Users/iv/Developer/relux-proxy
  make credential-free-validate`: exit 0 -- all 17 stages PASS:
  relay-tool-bootstrap, relay-packaging, validation-contract-tests,
  deterministic-generation, macos-target-builds-and-contracts,
  core-boundaries, swift-testing, swift-release-build, native-packaging,
  legacy-clone, legacy-checkout, legacy-preservation, legacy-guard-tests,
  migration-isolation, migration-isolation-negative-tests,
  legacy-swift-test, legacy-swift-release-build.
- `make check-native-dependencies` (exact hosted failing command): exit 0.
- Strictness preserved: `DEVELOPER_DIR=<Xcode 26.6>`
  `libssh2-fork-tool.py verify` -> exit 1,
  `expected Build version 17F42, got Xcode 26.6 / Build version 17F113`
  (override only, no system mutation; `xcode-select -p` unchanged).
- Workflow YAML parses (same check CI runs); `git diff --check` clean.
- No linter configured in repo (no Makefile lint target, no hidden linter
  configs) -- nothing to run.

## AC coverage: 4 of 6 rows driven through production entry

Call sites: `.github/workflows/ci.yml`
(`generated-project-credential-free`) -> `scripts/select-native-xcode.sh`
-> `scripts/libssh2-fork-tool.py verify` (`verify_xcode_build`); gate
contract `scripts/tests/test-credential-free-validation.sh` runs the
credential-free gate hosted and locally.

1. Narrow reproducible fix -- DRIVEN: runner + selection + tracking
   contract, all green through the production gate (full gate exit 0).
2. Independent review -- STATED BOUND: reviewer stage.
3. Exact prospective PR composition identity -- DRIVEN: identities above.
4. Targeted validation -- DRIVEN: table above, every exit observed.
5. Honest hosted validation requirements -- DRIVEN: this outcome + rev1
   outcome + toolchain-evidence + bounds below.
6. Real hosted publication/landing -- STATED BOUND: parent delivery duty.

Negative/narrowing evidence (unchanged from rev1, re-run green here):
16F6 and 17F113 rejections, disagreeing/unmapped/missing-pin and
missing-install refusals (exit 2), `admit-macos26-default-only` killed by
the named 17F113 test, `select-wrong-app-preserves-token` (17F42 literals
kept) killed by the full 12-test behavioral suite on the recorded path.
The recovery edit changes a gate expectation value, not gate strength
(exact full-line count == 1 + ordering intact); pre-fix exit 1 vs
post-fix exit 0 through the same production script proves it bites.

## Bounds (honest, unchanged plus one)

- Hosted proof (macos-26 + selection => hosted green) still requires
  publishing the prospective PR; a parent delivery gate, not claimed here.
- The image move upgrades the whole credential-free job from Xcode 16.4
  (Swift 6.1) to Xcode 26.5 (Swift 6.3.2-class); all currently-passing
  stages re-verified green LOCALLY on Xcode 26.5 in this run (full gate
  exit 0), hosted confirmation pending by construction.
- No manifest/artifact/product/deployment-target changes; no VPN;
  no global xcode-select change; no publication, commit, or landing.
- New bound: the contract script still fails silently (bare `test`)
  on label mismatch; the empty-log shape is pre-existing and out of
  narrow scope -- diagnosis recorded here instead.

Ready for review: uncommitted candidate + this outcome handed to review.
