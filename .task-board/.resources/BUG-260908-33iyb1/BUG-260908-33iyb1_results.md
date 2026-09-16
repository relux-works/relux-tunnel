# BUG-260908-33iyb1 — diagnostic candidate, hosted gate still open

## Finding and scope

Hosted run 34167625590 / job 101881722247 failed with exit 65. The supplied
artifact 10034792775 contains only successful generation in the macOS child
log: individual xcodebuild logs were redirected outside the uploaded tree.
The actual compiler/build cause remains unknown. Fetch verified revision
3279036094620772262dbd04a6d8930ec7691e75 has parents b3422b0 and 87451b5;
its tree exactly equals PR6 head 87451b53960ceabe88a01c44c287fee7f9ebf386.

The minimal candidate puts all seven Xcode logs under the existing always-upload
credential-free log directory, prints complete failure context inline, and
returns the original child status. No workflow/toolchain pin or runtime product
bytes changed. docs/generated-workspace-foundation.md specifies Swift tools 6.1;
the hosted Swift 6.1.2 satisfies that prerequisite. Local Xcode 26.5 / Swift 6.3.2
success does not establish why Xcode 16.4 failed. An exact Xcode baseline change
is deliberately deferred until the real diagnostic supplies evidence.

## Updated diagnostic AC coverage: 2 of 6 AC rows driven

This recovery supersedes the old five-row coverage and handoff refusal after the
parent split the original hosted repair into BUG-260908-shki8p (verified backlog).

| AC row | Production call site / evidence | Stated bound |
| --- | --- | --- |
| Failure status | validate-macos-targets.sh build_unsigned and target test -> run_logged_command; test_each_failing_build_and_test_retains_status_and_context | Driven for exit 65 and exit 1 at all five build/test calls. Named test_exit_one_stops_each_build_and_test_with_exact_status adds exact-status and no-later-invocation assertions for exit 1. Other status values remain a stated bound; no exhaustive status claim. |
| Bounded diagnostic tail | validate-credential-free.sh run_step -> tail -n 80 | Existing outer entry point is unchanged and inspected; no named behavioral boundary test. Direct macOS validator emits the complete child log, so its output is not bounded; bound applies to the outer CI entry point only. |
| Full logs retained | run_logged_command; test_successful_child_retains_both_streams and test_each_failing_build_and_test_retains_status_and_context | Both streams retained in uploaded artifact root. Five negative build/test call sites driven; two build-settings call sites have real positive evidence only. |
| Named narrowing tests | test_macos_build_diagnostic_mutants.py invokes the production-entry behavioral suite | admit-exit-1-only, admit-exit-65-only and hide-exit-65-diagnostic-only all killed with assertion failures (inner exit 1, harness exit 0). Diagnostic mutant preserves cat token. No new source-text gate. |
| Real macOS candidate and exact PR6 composition | RUN-260907-f967aa attached macos-build-01.log and composition-build-02.log | Both passed on local Xcode 26.5 / Swift 6.3.2; accepted prior evidence, not rerun here. Hosted Xcode 16.4 is not locally reproduced. |
| Immutable review / original repair open | Parent-owned reviewer and BUG-260908-shki8p | Review pending; this producer does not approve itself or claim hosted green/root cause. |

The ratio counts the two AC behavior rows directly driven by named production
entry tests; the remaining four rows have explicitly stated operational/test
bounds above. Negative invocation coverage is 5 of 7 Xcode call sites (five
build/test calls, two later build-settings calls not negatively injected).
Tests are in the uncommitted candidate as required by managed worktree policy;
immutable handoff and later signed delivery must preserve them.

## Recovery verification and provenance

- All eight candidate files matched RUN-260907-f967aa candidate-sha256.log
  before the sole recovery documentation correction in LOGBOOK.md.
- HEAD remains signed sibling dc68c1584f7cc4ddcdf770acd8ace79790f0b404.
  No product/workflow/toolchain bytes changed; no manual commit or publication.
- Re-ran two diagnostic behavioral tests successfully and the narrowing harness
  successfully; expected inner mutant failures remain failures, not successes.
- Accepted prior attached real macOS validation, exact PR6 composition validation,
  contracts and signature checks. Prior initial composition trust failure remains
  recorded. No redundant broad suite rerun, HEV/SSH determinism claim, VPN action,
  or hosted validation performed.
- Recovery logs are attached as BUG-260908-33iyb1_recovery-evidence.log.

## Review and next hosted step

The diagnostic-only leaf is ready for independent immutable review with the
explicit coverage bounds above. The parent owns final signed composition and
publication. Then run generated-project-credential-free on that exact head,
inspect logs/macos-targets/*.log from its always-upload artifact if it fails,
and pursue only the evidenced repair under BUG-260908-shki8p. This outcome
supersedes the earlier lifecycle refusal caused by the unsplit hosted-green
checklist; it does not turn that old failed handoff into success.

## F1 rework evidence

Reviewer rev1 withheld acceptance solely because exit-1-only admission survived.
This revision changes only the two Python diagnostic test files relative to rev1;
production, README, LOGBOOK, sibling and runtime bytes are preserved.

Production entry: scripts/validate-macos-targets.sh build_unsigned and target
test -> scripts/logged-command.sh run_logged_command. The new named
test_exit_one_stops_each_build_and_test_with_exact_status injects exit 1 at each
of five build/test calls, asserts exact status, counter (no later invocation),
diagnostic stderr, and retained artifact logs. Existing exit 65 coverage remains.

Coverage remains **2 of 6 AC rows driven**, with status now driven for 1 and 65;
negative invocation coverage is **5 of 7 Xcode call sites** for each status.
The unchanged bounds in the table still apply. The new admit-exit-1-only mutant
inserts '[ "$command_status" -ne 1 ] || return 0' before the original return;
all other status handling and original tokens remain. Its named production-entry
test exits 1 with assertion failures; harness exits 0. Both prior mutants also
exit 1 with assertion failures. No static-only checker substitutes for behavior.

Rerun here: Python behavioral suite (3 named tests, exit 0); all three narrowing
mutants (harness exit 0, each child exit 1); git diff --check (exit 0).
Logs attached as BUG-260908-33iyb1_f1-tests.log. Real macOS candidate and exact
PR6 composition evidence above is reused, not rerun for this test-only delta;
reviewer explicitly accepted that bound. Managed publication validation remains
mandatory and its result is recorded by handoff separately.

BUG-260908-shki8p was re-read as backlog. Original hosted failure/root cause is
not fixed or claimed green. Reviewer-owned checklist and acceptance remain with
the reviewer. Parent owns signed delivery; no manual Story commit or integration.
