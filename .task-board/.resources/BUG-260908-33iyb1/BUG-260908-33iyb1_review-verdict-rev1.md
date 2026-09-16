# Independent review: changes requested

CR-BUG-260908-33iyb1-1 revision 1; immutable tree 2c7c37ffdf1f3a5ea8d4392c74e6f9739bb1ce5c. All 16 changed blobs match the working files. Diagnostic delta from signed sibling dc68c1584f7cc4ddcdf770acd8ace79790f0b404 contains only the expected eight files; runtime product and sibling bytes preserved. No candidate edits, commits, publication, integration, VPN actions, or shared-tool changes performed.

## F1 — non-65 failure propagation lacks an effective regression gate

Production site: scripts/logged-command.sh:12, reached by scripts/validate-macos-targets.sh build_unsigned and target-contract test invocation. The AC explicitly includes exit65 AND other failures. In an isolated scratch copy I narrowed the return gate by inserting `[ "$command_status" -ne 1 ] || return 0` immediately before `return "$command_status"`. This admits exactly status 1 while retaining the gate for all other statuses and retaining the diagnostic token. Both shipped behavioral and mutation suites still exited 0. This is a measured surviving narrowing mutant, not a hypothetical concern or a claim that current production already swallows status 1.

Required rework: add a named production-entry regression test injecting at least exit 1 alongside 65, assert unchanged status and no later invocation, and ship the exit-1-only narrowing mutant requiring that named test to fail. Keep candidate scope diagnostic-only. The producer honestly declared this coverage bound; that disclosure does not establish the AC's explicit other-failure regression behavior. No broad build repeat is needed for this test-only correction unless implementation changes.

## Coverage and evidence

2 of 6 AC rows driven by named production-entry tests, consistent with producer outcome:
1. Failure status: test_each_failing_build_and_test_retains_status_and_context -> validate-macos-targets.sh build_unsigned / target test -> run_logged_command. Driven for 65 only; F1 addresses the other-status gap.
2. Full logs: same production-entry test plus test_successful_child_retains_both_streams -> run_logged_command. Negative call coverage 5 of 7 Xcode sites; two build-settings sites have positive real evidence only.
3. Bounded tail: validate-credential-free.sh run_step -> tail -n 80, inspected only. Direct macOS validator deliberately emits complete child output; outer CI tail is the stated bound. No behavioral tail-bound test shipped.
4. Narrowing tests: both shipped mutants killed (inner exit 1, harness exit 0); additional exit-1-only mutant survives (F1).
5. Real macOS evidence: accepted existing evidence.zip macos-build-01.log and composition-build-02.log, plus all four BUILD SUCCEEDED logs and TEST SUCCEEDED target logs for each tree. Composition described as exact PR6 87451b53960ceabe88a01c44c287fee7f9ebf386 plus sibling and diagnostic patch. Initial composition mise-trust failure remains evidence, not success. Local Xcode 26.5 evidence is not hosted Xcode16.4 proof or flake determinism evidence.
6. Immutable review/original repair: this verdict reviews the named tree; BUG-260908-shki8p read as backlog and remains open. No hosted green/root-cause claim.

Reviewer reruns: diagnostic behavioral suite exit 0; shipped narrowing harness exit 0 with expected assertion failures for its mutants; git diff --check exit 0. Reviewer attack: both suites exit 0 with exit-1-only admission. Attached CR validation log ends [exit 0] for the complete credential-free validation; accepted prior evidence, not rerun by reviewer. No new secret source, environment dump, or credential access introduced by the diagnostic delta; child Xcode logs are intentionally added to the existing artifact root. This is a code-path review, not exhaustive secret scanning.

Verdict: changes requested -> to-dev. Acceptance withheld solely for F1. repeat-of: none. Parent retains delivery ownership; original hosted repair remains BUG-260908-shki8p.
