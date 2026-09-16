# TASK-260916-39riah: synchronize-operational-model-and-signing-policy

## Description
Synchronize stale root task-board config with the explicitly authorized operational policy in a separate reviewed delta.

## Scope
Inspect current root config and operational .temp/resume-20260916/task-board.config.json. Preserve unrelated valid configuration; replace obsolete Sol-only admission and cancelled commit windows with Muse Spark1.3 max, Astra low, Fable5.1 low, max_parallel1, lite context, current timestamps and configured Ivan signed delivery. Do not copy task-scoped absolute paths or enable unrelated tooling. Update only directly affected documentation. Use native configuration validation and fresh spawn preflight proof. No installations or VPN actions.

## Acceptance Criteria
Root policy admits exactly authorized model/effort pairs with one worker and lite context; obsolete timing restrictions removed; unrelated config retained; focused validation and independent review pass; signed delta delivered through real PR gates.
