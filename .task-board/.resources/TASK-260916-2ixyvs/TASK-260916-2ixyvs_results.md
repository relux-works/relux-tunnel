# TASK-260916-2ixyvs results: reviewed weak-var delta published, exact-head CI red on new distinct Xcode-pin failure

Run: RUN-260916-be8d87 (developer/implementer, Muse Spark max). No landing performed.
PR6 remains OPEN. Incomplete state preserved; green gate NOT claimed.
CI failure is the honest observed outcome for this publication task.
Parent nudge b06510 (persist scoped outcome, honest handoff, no green requirement) satisfied.

## Published head

- Branch `delivery/STORY-260715-1y04r0-rev3` advanced `310a560..d45c85d` by
  fast-forward plain push (exit 0, no force). Remote re-verified before push.
- New head: `d45c85d67b78b6578b5cb0821bd2e78217124d30`
  `fix(harness): declare M1 host-owner probe as weak var`
- Tree: `c8d2b249b9bf8875b2309320c70b64e0e3e12ac5` — byte-equal to the
  independently reviewed prospective tree from BUG-260916-2764p8 rev 2 review
  (staged tree verified equal BEFORE commit; scratch-index reproduction
  independently yields the same tree).
- Signatures: local `git verify-commit` good for `oparin@me.com` (ECDSA
  SHA256:V6JiKG7J29mjsvikcLoSVp0bLa77VTsFy12gnLO81cM); GitHub commit
  verification `verified:true, reason:valid, verified_at:2026-09-16T11:40:28Z`,
  payload tree/parent match.
- Author/committer: Ivan Oparin <oparin@me.com>, current timestamps
  (Wed Sep 16 15:40:00 2026 +0400). Signing key /Users/iv/.ssh/ivanopcode.
- Ancestry: `d45c85d -> 310a560 -> a46e2ba -> 018c9d9 -> 87451b5 -> 6e8a198
  -> b3422b0`; `310a560..d45c85d` is exactly 1 commit; all prior signed
  objects retained, no rewrite (`verify-commit` on `310a560` and `a46e2ba`
  still good).
- Delta vs old head is exactly 1 path, 1 line, blob equals the reviewed fix:
  `Sources/ReluxTunnelHarnessSupport/M1RuntimeCommand.swift`
  (`bcd8961` -> `d868eb7`, `weak let` -> `weak var` at line 138). Full
  `ls-tree -r` comparison of old-head vs prospective tree: 3421 of 3422
  entries identical; only the fixed file differs.
- Composition: isolated detached worktree at freshly fetched remote head
  `.temp/TASK-260916-2ixyvs/delivery`; fixed bytes extracted read-only from
  candidate tree `766824884cac85078199779dbe9c67c9bcbf1be9` (`git cat-file`
  blob `d868eb7`, `cmp` exit 0, `hash-object` match). Managed candidate NOT
  copied wholesale (candidate-vs-PR diff is 354 files of board/packaging
  scope plus this line). Prior fixes preserved in staged tree: mapper
  `6fdffde` (wifiAware guard intact), test `3add91a`, fixtures unchanged.
- Preserved refs: root `main` still `87451b5`; local stale
  `delivery/STORY-260715-1y04r0-rev3` (`87451b5`) deliberately NOT moved —
  push used an explicit refspec from the detached worktree. No landing:
  `origin/main` still `b3422b0` after publication.
- Fresh remote verification (twice: pre-act and immediately pre-push):
  `origin/HEAD -> main @ b3422b0`; PR6 branch and `refs/pull/6/head` both
  `@ 310a560` (matched expected review input, so no renewed-composition
  routing was needed). Post-push: branch and `refs/pull/6/head` both
  `@ d45c85d`; `gh pr view` confirms PR6 OPEN at new head.

## Exact-head hosted CI (run 35091586150, head d45c85d)

- Status `completed`, conclusion `failure`. 6/7 jobs pass; only
  `generated project credential-free validation` (job `104778924295`, 11m11s)
  fails. Job identities (all personally fetched via `gh run view --json`):
  board+spec `104778924627` success; linux/arm64 `104778924551` success;
  darwin/amd64 `104778924555` success; darwin/arm64 `104778924647` success;
  pinned toolchain `104778924467` success; linux/amd64 `104778924669`
  success; credential-free `104778924295` failure.
- Failing-job steps: only `Run the local credential-free gate` fails
  (exit code 2). `Exercise validation boundary narrowing mutants` passed;
  `Upload privacy-safe validation evidence` passed (artifact
  `credential-free-generated-project-35091586150`, ID 10444742927, 18 files).
- WEAK-VAR COMPILATION PASSED ON HOSTED CI: the 620-line failing-job log
  (fetched via `gh run view --job ... --log`, exit 0) contains zero mentions
  of `weak`, `wifiAware`, `has no member`, or `M1RuntimeCommand` errors
  (all greps exit 1 / count 0), and zero `error:` lines. Gate shards:
  relay-tool-bootstrap, relay-packaging, validation-contract-tests,
  deterministic-generation, macos-target-builds-and-contracts,
  core-boundaries, swift-testing, swift-release-build all PASS. Hosted
  swift-testing log shows `[94/110] Compiling ReluxTunnelHarnessSupport
  M1RuntimeCommand.swift` with no error and `Test run with 516 tests passed
  ... with 25 known issues` (all 14 `failed`-word lines are passing test
  names). The published delta resolved the exact error that failed run
  35087910852.
- NEW DISTINCT FAILURE (native-packaging shard, NOT Swift compilation):
  `FAIL: native-packaging (exit 2; ...)` then
  `libssh2-fork-tool: Xcode build mismatch: expected Build version 17F42,
  got Xcode 16.4` / `Build version 16F6`, `make[1]: *** Error 1`,
  `make: *** [credential-free-validate] Error 2`. Chain: PR6
  `NativeDependencies/manifest.json` pins `xcode_build 17F42` (blobs
  identical at `310a560` and `d45c85d`: `31e39df`); tool
  `scripts/libssh2-fork-tool.py` (`9433293`, identical both heads) rejects
  the runner's Xcode 16.4. Pre-existing and outside this delta: no file in
  the failing path differs between old and new head (manifest, tool,
  Makefile `b7056d6` all identical); previously masked by the earlier
  Swift compile failure. No source repair attempted per publication scope.
- Toolchain EVIDENCED (from downloaded artifact `environment.log`, not
  inferred): host macOS 15.7.9 arm64; `xcode=Xcode 16.4;Build version 16F6`;
  `swift=... Apple Swift version 6.1.2 (swiftlang-6.1.2.1.2
  clang-1700.0.13.5)`; macOS SDK 15.5. The single `arm64-apple-macosx`
  string in the job log is a mutants-step build path, not a toolchain claim.
  Gate validated `source_revision=352226ed...` which equals live
  `refs/pull/6/merge` — the exact-head merge commit, as expected for
  pull_request checkout.
- Full failing-job log attached as
  `TASK-260916-2ixyvs_ci-35091586150-failed-job.log` (620 lines).
  No synthetic statuses; no local mirror substituted for hosted results.

## Local validation (delivery worktree, exact new head)

Personally rerun in this run (all exit 0 unless noted):
- Fresh `git ls-remote --symref origin HEAD`, delivery/main ls-remote (twice:
  pre-act and immediately pre-push), `refs/pull/6/head` ls-remote + exact
  object fetch; `verify-commit` on input head (good); candidate tree and
  fixed-blob object checks; pre/post blob diff (exactly the `weak let` ->
  `weak var` line).
- Detached delivery worktree create at `310a560` (clean); fixed-blob
  `cat-file` composition + `cmp` + `hash-object`; `diff --check` (exit 0);
  staged `write-tree` equality with `c8d2b24...`; `diff-tree` one-path proof;
  full 3422-entry `ls-tree -r` diff (1 entry differs); independent
  scratch-index reproduction (`c8d2b24...`); prior-fix blob checks
  (`6fdffde`/`3add91a`/wifiAware guard).
- New-head `verify-commit` (good), `--show-signature` log, author/committer
  dates (current), parent rev-parse, full 7-commit log, `merge-base
  --is-ancestor`, `rev-list --count` (=1), `diff --name-only`/`--stat` vs
  parent, prior-head `verify-commit`s (good).
- Push result (`310a560..d45c85d`, exit 0, no force) + post-push ls-remote;
  GitHub API commit payload (sha/tree/parent/verified:true/reason:valid);
  `gh pr view` head update; local refs untouched (`rev-parse`).
- `gh run list`, `gh run view` identity (`headSha:d45c85d`), 13 bounded
  60s polls to `completed/failure` (one transient API timeout mid-poll,
  recovered next poll), per-job id/conclusion table, `gh pr checks`,
  failing-job step list, full 620-line log fetch (exit 0), and all log
  greps above; artifact download (exit 0, 18 files) with shard,
  environment, and swift-testing log inspection; `refs/pull/6/merge`
  cross-check; failing-path blob-identity proofs across heads.
Reused without rerun (byte identities match the accepted evidence):
- BUG-260916-2764p8 rev 2 managed full-gate log, focused-suite passes,
  ownership fault-injection bounds, and the independent ACCEPT verdict
  (RUN-260916-f3ce0f) with its prospective tree. No Swift build/test was
  executed in this run; no product code was authored or repaired here.

## Build-cache inventory (after publication + CI observation)

- INVENTORY ONLY — nothing deleted in this run. Current `.build` sizes:
  root 2.6G; STORY-260715-1y04r0 1.7G; STORY-260908-h39ajh 1.6G;
  STORY-260916-1du4i1 (accepted weak-fix worktree) 1.6G; STORY-260715-19mjyn
  1.0G; STORY-260715-1zzt0c 387M; STORY-260715-2ungml 378M;
  STORY-260717-1ecq74 194M. Prior task's ~3.6 GiB reclaim is not re-claimed.
- Retained per brief: accepted weak-fix worktree
  `.temp/STORY-260916-1du4i1/worktree/.build` (full SwiftPM layout verified
  present) for upcoming exact-head reviewer reuse, all worktrees, all
  evidence, and the new delivery worktree `.temp/TASK-260916-2ixyvs/delivery`
  at `d45c85d` (clean). No active swift/xcodebuild/tuist builds observed.
- Root LOGBOOK patch (`.temp/resume-20260916/logbook-preserved-07.patch`) and
  stash record (`logbook-stash-08.txt`) intact; root stash preserved; no root
  LOGBOOK write was made — findings live in this artifact per the brief.

## Checklist truth table

1. Exact prospective composition: CHECKED — published tree `c8d2b24...`
   byte-equals the independently reviewed prospective tree; only accepted
   weak-var bytes composed; prior signed ancestry and fixes preserved.
2. Signed commit by Ivan Oparin: CHECKED — single explicit `-S` commit with
   current timestamps and `/Users/iv/.ssh/ivanopcode`; verified locally and
   on GitHub after publication.
3. Hosted CI observed honestly: CHECKED — real exact-head run 35091586150
   observed to completion (`failure`); complete outcome + job identities +
   full log attached; weak-var resolution distinguished from the newly
   exposed Xcode-pin failure; no green claim, no landing, no repair, no
   unchanged-condition retry, no VPN operation.
4. Code per task description/AC: CHECKED — publication-only scope honored;
   no new product code authored.
5. Outcome artifact: CHECKED — this file plus the attached CI log, both
   task-scoped `TASK-260916-2ixyvs_*` outcomes.
6. Logbook: CHECKED — no new root LOGBOOK write per the brief (evidence
   attached here instead); preserved patch/stash verified intact.

## Handoff state and recommendation

- Ready for review (handed off to review). PR6 (`d45c85d`) awaits independent
  exact-head review and owns its green-checks/landing obligations under
  TASK-260908-34gi0y; nothing was landed here.
- The `native-packaging` Xcode-pin defect (manifest expects 17F42, hosted
  runner carries 16.4/16F6) needs a fresh scoped route (policy decision:
  runner image/Xcode selection vs manifest pin), mirroring how the wifiAware
  and weak-let defects were routed. It is new work outside this publication
  task and was deliberately not touched. Note for the follow-up: hosted
  Swift 6.1.2 now compiles and tests the full package green (516 passed),
  so the remaining red is purely the native-dependency Xcode gate.
- Successor note: delivery worktree `.temp/TASK-260916-2ixyvs/delivery` is
  preserved at `d45c85d` (clean, no `.build`) as unlanded-head evidence.
