# Verify Gate P0 on a physical iPhone

## Description
Install and exercise the disposable iOS probe on the designated physical iPhone. Capture a repeatable end-to-end record that the containing app can save the VPN configuration, the system can launch the signed provider, app messaging works, and repeated stops leave no stale configuration or process state.

## Scope
In scope: named physical iPhone and current supported iOS release; development install; trust and VPN approval steps; configuration save and reload; start, provider message, stop, host termination, uninstall and reinstall where relevant; entitlement and device-log correlation; repeated lifecycle loops. Out of scope: simulator-only evidence, packet forwarding, performance or memory gates, TestFlight, App Store review, and collecting unrelated personal device logs.

## Acceptance Criteria
1. Evidence records privacy-safe device model and identifier, exact iOS, Xcode, source revision, profile UUID and expiry, bundle versions, and test timestamp. 2. The containing app installs, saves and reloads its manager, starts the provider, receives the expected versioned message, observes connected or expected probe state, and stops cleanly. 3. At least ten start and stop cycles plus one host termination and one reinstall path show no stale manager duplication, crash, or unexplained provider-launch failure. 4. Device logs are filtered and redacted yet correlate host request, provider start, app message, and stop reason. 5. A TASK-ID-scoped runbook and result bundle lets another authorized operator repeat the test.
