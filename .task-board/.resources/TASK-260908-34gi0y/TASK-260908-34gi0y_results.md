# TASK-260908-34gi0y results: signed PR6 head published, exact-head CI red on new distinct failure

Run: RUN-260916-b63447 (developer/implementer, Muse Spark max). No landing performed.
PR6 remains OPEN. Incomplete state preserved; green gate NOT claimed.

## Published head

- Branch `delivery/STORY-260715-1y04r0-rev3` advanced `018c9d9..a46e2ba` by
  fast-forward plain push (exit 0, no force). Remote re-verified before push.
- New head: `a46e2ba351a81e42f2907805b4cda2c313af7bd1`
  `fix(runtime): require Sendable mapped result for Swift 6.1`
- Tree: `45826b72e05e2accac7c7165691c8a1d1ecf701f` — byte-equal to the
  independently reviewed prospective tree from BUG-260908-shki8p rev 2 review.
- Signatures: local `git verify-commit` good for `oparin@me.com`; GitHub commit
  verification `verified:true, reason:valid`, payload tree/parent match.
- Ancestry: `a46e2ba -> 018c9d9 -> 87451b5 -> 6e8a198 -> b3422b0`; all 3 prior
  PR commits retained, no rewrite of any signed object.
- Delta vs old head is exactly 2 paths, blobs equal the accepted candidate
  (`6b843d1`, `c0cc562`):
  `Sources/ReluxTunnelCore/TunnelRuntimeCoordinator.swift` (`mapped<T>` to
  `mapped<T: Sendable>`) and its tests (five-case `callerCancellation(point:)`).
  PR fixture blob `156fc56` unchanged; diagnostic runner lines intact.
- Composition: isolated detached worktree at freshly fetched remote head
  `.temp/TASK-260908-34gi0y/delivery`; files copied read-only from the managed
  CR worktree (whose 3 modified paths were verified byte-identical to rev 2
  candidate blobs before use). No hand commit on any managed Story branch.
  Managed STORY-260908-23tefs worktree left untouched with its 3 modified paths.
- Preserved refs: root `main` still `87451b5` (ahead 2 of `origin/main`
  `b3422b0`, dirty board state untouched); local stale
  `delivery/STORY-260715-1y04r0-rev3` (`87451b5`) deliberately NOT reset or
  moved — push used an explicit refspec from the detached worktree.

## Exact-head hosted CI (run 35048178384, head a46e2ba)

- Status `completed`, conclusion `failure`. 6/7 jobs pass; only
  `generated project credential-free validation` (job `104642534222`) fails.
- Original failure ABSENT: the 685-line failing-job log contains zero mentions
  of `TunnelRuntimeCoordinator`; the `:687` non-sendable-T diagnostic is gone on
  declared Xcode 16.4 / Swift 6.1 / macOS SDK 15.5. The build now progresses
  through `ReluxTunnelCore` into `ReluxTunnelMacOSAdapter`.
- New distinct failure (only failing step is `Run the local credential-free
  gate`; mutant step passed — its AssertionErrors are designed killed-mutant
  output):
  `Sources/ReluxTunnelMacOSAdapter/MacOSSSHBootstrapErrorMapper.swift:37:11:
  error: type 'NWError' has no member 'wifiAware'`
  `** BUILD FAILED **` (ReluxProxyMac Debug), `make: Error 65`, job exit 2.
- Pre-existing and outside this delta: file blob `5b47bd80` identical at base
  `b3422b0`, old PR6 `018c9d9`, and new head `a46e2ba`; introduced by `d742a60`
  `Implement privacy-safe SSH bootstrap diagnostics`. Previously masked by the
  earlier `ReluxTunnelCore` failure. Local Swift 6.3.2 accepts it (newer SDK).
- Full failing-job log attached as
  `TASK-260908-34gi0y_ci-35048178384-failed-job.log` (685 lines, fetched via
  `gh run view --job ... --log`, exit 0). Original failure evidence retained
  under BUG-260908-shki8p resources; no synthetic statuses; no local mirror
  substituted for hosted results.

## Local validation (delivery worktree, exact new head)

Personally rerun (Swift 6.3.2, arm64 macOS — NOT Swift 6.1 proof):
- `swift test --filter TunnelRuntimeCoordinatorTests`: exit 0, 22 tests pass.
- `swift format lint --strict` on both changed files: exit 0.
- `git diff --check`: exit 0.
- `bash scripts/tests/test-credential-free-validation.sh`: exit 0 after
  inspecting `mise.toml` (only `tuist = "4.202.5"`) and `mise trust`, same as
  prior accepted evidence. First attempt exit 1 on untrusted config only.
- Reused without rerun (byte identities match): CR rev 2 managed validation
  exit 0, 494-test gate, narrowing-mutant exit 1 evidence, reviewer 22-test run.

## Checklist truth table

1. Green-gate requirement: UNCHECKED — exact-head CI is red on the new
   `wifiAware` failure. No resolution claim, no landing, no approval posted.
2. Code per task description/AC: checked — recovered accepted delta published
   byte-exact; no new product code authored, as instructed.
3. Outcome artifact: checked — this file plus the attached CI log.
4. Logbook: checked — two entries appended to root `LOGBOOK.md` under
   `2026-09-16` (milestone + blocker).

## Handoff state and recommendation

- Ready for independent exact-head review of `a46e2ba` (separate Astra low
  review). Reviewer must re-verify head/tree/signatures and the red gate.
- The `wifiAware` defect needs a fresh scoped repair route (new BUG with its own
  diagnosis/review/green cycle); it is new product work outside this
  verification task and was deliberately not touched here.
- Nudge (cache inventory, nothing deleted): task worktree
  `.temp/TASK-260908-34gi0y` 994M incl. `delivery/.build` 399M (from focused
  `swift test`; worktree preserved as unlanded-head evidence); observed
  `.temp/STORY-260908-23tefs/worktree/.build` 1.6G (foreign managed worktree,
  not mine to clean). No shared caches touched.
- Directives polled at safe checkpoints; only the cache-cleanup nudge observed.
