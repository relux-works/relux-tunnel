# Review-02 rework

Consume TASK-260715-2ywde4_review-02-verdict.md as authoritative.

Required:
1. Fix ShellCheck 0.11.0 SC1007 in scripts/tests/test-relay-shell-artifacts.sh using an explicit empty CDPATH assignment while preserving script_dir resolution and smoke behavior.
2. Resolve the orphan TASK-260715-2ywde4_review-02-focus.md only through supported task-board resource commands; do not edit board files directly.
3. Run ShellCheck on both changed shell scripts and require exit 0 with no findings.
4. Run task-board validate and require no issues/warnings, plus focused tests and proportionate regression gates.
5. Do not change the accepted manifest-bound identity/security behavior unless a real contradiction is found.
6. Attach a distinct TASK-260715-2ywde4_rework-02-results.md outcome and hand off to to-review.