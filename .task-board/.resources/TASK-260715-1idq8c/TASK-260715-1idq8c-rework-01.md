# Rework 01 — split build-host and signed-host evidence

The orchestrator accepts Option B from the producer outcome to preserve the binding build-only rule.

- The current workstation must remain unsigned and must not install or launch a provider, create/save/enable/start a VPN, or mutate network state.
- `TASK-260822-3q4grm` now owns the native signed macOS fixture-host/XCUITest runtime proof on the dedicated test Mac and is blocked by host provisioning plus this infrastructure task.
- Update docs, smoke-gate semantics, task outcome, and residual-risk text so the current task proves: shared-source compilation, native macOS build-for-testing, iOS Simulator runtime, screenshot extraction/diff, and visual-review workflow. Do not claim a native macOS runtime pass here.
- Keep the isolated fixture graph and all existing automated evidence. Ensure the aggregate build-host gate reports the native macOS row as explicitly deferred to `TASK-260822-3q4grm`, not as an unexplained success or failing product test.
- Complete the task checklist and developer handoff only if the revised AC is fully met. Do not commit or push.
