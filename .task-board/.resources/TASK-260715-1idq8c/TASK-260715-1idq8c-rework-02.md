# Rework 02 — fail closed on screenshot extraction

Address the independent reviewer finding in `TASK-260715-1idq8c_review-results.md` only, plus directly necessary evidence updates.

- `scripts/run-apple-ui-test-smoke.sh` must explicitly capture and propagate `extract_apple_ui_test_artifacts.py` failure even when `run_ui_test` is invoked in an `if` conditional under POSIX shell semantics.
- Before a runtime row can succeed, validate the required `screenshots.json` and the expected step-named PNG artifacts. Missing/empty/malformed evidence must make the row and aggregate gate nonzero.
- Add a deterministic negative regression test that injects extractor failure and proves the aggregate build-host gate is nonzero. Avoid a test that merely reimplements the same control flow without invoking the production seam.
- Keep macOS runtime deferred to `TASK-260822-3q4grm`; do not sign or launch it here. Preserve all build-only/no-VPN boundaries.
- Re-run focused positive and negative gates, syntax/lint/diff checks, and the relevant build/test matrix. Update task-scoped outcome and hand off to review only when checklist is complete.
- Do not commit or push.
