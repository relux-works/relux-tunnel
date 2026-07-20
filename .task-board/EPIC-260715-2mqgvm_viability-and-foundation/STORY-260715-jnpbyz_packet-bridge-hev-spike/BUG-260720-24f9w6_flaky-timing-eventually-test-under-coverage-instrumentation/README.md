# BUG-260720-24f9w6: flaky-timing-eventually-test-under-coverage-instrumentation

## Description
Surfaced by TASK-260715-52h8i3 verification: one swift test --enable-code-coverage run (first coverage-instrumented invocation) reported 105 tests with 1 issue while the (serialized, deterministic) fuzz suite passed; re-runs were 105/105 green. The flake is OUTSIDE the fuzz suite — most likely a timing-sensitive eventually-style expectation elsewhere that fails under first-run instrumentation overhead. A flaky test causes intermittent CI failures. FIX: find the timing-sensitive expectation (likely an eventually/polling assertion in a lifecycle/harness/bridge test), make it deterministic (inject clock / await a signal instead of wall-clock polling, or raise/remove the time bound), and prove stability under swift test --enable-code-coverage across repeated runs. Low severity but must be fixed before the CI quality gate to avoid flaky reds.

## Scope
(define bug scope / affected area)

## Acceptance Criteria
(define fix acceptance criteria)
