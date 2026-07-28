# Independent review verdict — round 3

Review date: 2026-07-28.

Verdict: **CHANGES REQUESTED**. Route to `analysis`.

The planning and dependency rework is substantively acceptable:

- Ceremony C1 is one live human node, `TASK-260728-q5kjta`, blocked only by
  the approved identifier matrix. Its downstream account, portal, notary, and
  Sparkle evidence tasks are unattended. Approval A1 and sign-off S1 remain
  separate because their artifacts do not exist at C1.
- Notarization readiness is stated truthfully: the named `notarytool`
  Keychain profile, real authentication check, and source-file custody
  disposition are required before readiness. No secret values or private paths
  were exposed during review.
- Sparkle generation is separated from integration.
  `TASK-260728-3bj9bk` is blocked by `ziprhs`, `xempiv`, and `1mt4e7`, and it
  blocks publication and integrity tests.
- Human holds are no longer counted as autonomous. The regenerated plan reports
  226 autonomous tasks and 17 human-input nodes in 9 batches, including the
  previously omitted owner decisions, ratifications, and physical approvals.
- The full dependency ledger accounts for 75 removed and 21 added edges.
  Independent live-board traversal found 400 elements, zero missing blocker
  targets, zero dependency cycles, and exactly 15 explicitly sealed deferred
  tasks.
- `TASK-260715-1u2vpc` is again blocked by Gate P0
  (`TASK-260715-2ayxqn`). `TASK-260715-1ozsb6` remains blocked by
  `TASK-260728-yx2fca`, and `TASK-260728-3cveay` remains blocked by
  `1gjxer`, `3kimon`, and `yx2fca`.
- Canonical goal/spec/board projections encode libssh2 primary, Option A
  viability, macOS-only P0, iOS/A0/Linux deferral, signing-identity
  availability, incomplete notary custody, and the retained security/release
  invariants. Product implementation paths are untouched.

Passing gates:

- `task-board validate`: exit 0, no issues.
- `task-board repair-links`: exit 0, no suspicious container links.
- Independent dependency traversal: exit 0, zero cycles and zero missing
  blockers.
- `git diff --check`: exit 0.
- Product-path status scan over `Sources`, `Tests`, `Protocol`, `relay`,
  `scripts`, `config`, `Package.swift`, and `Makefile`: exit 0 with empty
  output.

Failing gate:

- `swift test`: exit 1. The run executed 332 tests in 29 suites and failed with
  one issue in `ProviderAdapterContractTests.providerFailureHandoff`.
- Focused reproduction
  `swift test --filter ProviderAdapterContractTests.providerFailureHandoff`:
  exit 1. The iOS argument observed error code 1009 where the test requires
  `runtimeStartupFailed` code 1007.

This is reproducible, not a zero-test filter artifact. The producer handoff
claimed this gate passed, but the current independent run is red. The task
cannot be accepted while its Definition of Done requires green tests and the
role contract requires failing gates to stay failing.

Required rework:

1. Diagnose and resolve the reproducible provider-failure ordering test through
   a separately scoped defect/fix if product-code changes are required; this
   planning task itself must continue to contain no tunnel product code.
2. Re-run the focused test and the complete `swift test` suite to real exit 0.
3. Update the task results with the new exact exit codes and return to review.

