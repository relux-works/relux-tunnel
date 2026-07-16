# Add VPN manager and provider lifecycle automation

## Description
Build automated host and provider test suites that exercise owned-manager persistence, session control, status projection, versioned app messaging, both platform adapters, stop cleanup, and containing-app recreation using protocol seams and generated-target integration tests.

## Scope
In scope: unrelated manager fixtures, save or reload conflicts, permission and invalid states, connect and disconnect races, provider start failures, app-message versions, app recreation, stop reasons, completion once, repeated lifecycle loops, and resource baselines. Out of scope: physical system permission dialogs, final UI tests, packet throughput, DNS leak capture, reconnect, UDP, TestFlight, and notarization.

## Acceptance Criteria
1. Manager tests prove idempotent single-owned configuration and preservation of unrelated configurations under success, conflict, and corruption cases. 2. Session tests cover every Network Extension status plus out-of-order notification and snapshot combinations. 3. Shared provider conformance tests run for iOS and macOS adapters and cover cancellation at each startup step, duplicate calls, messages, errors, and cleanup. 4. At least one hundred simulated start, host recreation, message, and stop cycles show no monotonic task, observer, descriptor, manager, or runtime growth. 5. Generated host and provider integration tests compile and run with deterministic fixtures and publish commands and expected results.
