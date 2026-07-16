# Add composed M1 runtime integration scenarios to ReluxTunnelHarness

## Description
Extend the M0 harness with black-box scenarios that construct the production shared factories against controlled packet, SSH, TCP, DNS, and route substitutes and drive one complete M1 runtime generation without a containing app or Network Extension process.

## Scope
In scope: versioned configuration input, selected dependency composition, successful startup and traffic-ready snapshot, injected SSH or DNS loss, stop, repeated generations, aggregate diagnostics, fixture manifests, and CI-suitable deterministic execution. Out of scope: physical Network Extension behavior, real user credentials, performance claims, UDP relay, path migration, final routing captures, and application UI.

## Acceptance Criteria
1. A harness command starts the composed runtime from a fixture profile, observes the ordered states, exchanges representative TCP and DNS fixture traffic, requests diagnostics, and stops cleanly. 2. Separate scenarios inject authentication, packet, DNS, route-apply, and mid-session mandatory failures with stable expected exit codes. 3. The harness verifies no live forwarding dependency on a simulated host-app lifetime after start. 4. Repeated runs report zero monotonic descriptor, task, channel, socket, or native-runtime growth. 5. Fixture versions, dependency revisions, commands, expected outputs, and privacy-safe logs are documented and runnable in CI.
