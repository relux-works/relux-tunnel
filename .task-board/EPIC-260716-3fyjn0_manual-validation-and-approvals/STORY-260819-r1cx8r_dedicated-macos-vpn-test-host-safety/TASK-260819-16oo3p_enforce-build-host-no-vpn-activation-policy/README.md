# TASK-260819-16oo3p: enforce-build-host-no-vpn-activation-policy

## Description
Implement a fail-closed repository and board policy that prevents real VPN installation or activation on the current development Mac and requires an explicit separate test-host identity for physical validation.

## Scope
Specs, spawn policy, physical-test preflight guard, negative tests, and dependency audit. Build, compile, unit, harness, and unsigned provider tests remain allowed locally. No real system extension install, VPN preference save, startVPNTunnel, route or DNS mutation on this host.

## Acceptance Criteria
1. The current host is documented and machine-checkably treated as build-only. 2. Physical scripts fail closed unless an explicit remote test host is configured and proven distinct from the build host. 3. Negative tests cover missing host, localhost/current-host aliases, and absent opt-in. 4. Every macOS physical VPN validation task is blocked by the dedicated-host human gate. 5. No test installs or activates a VPN while implementing this task.
