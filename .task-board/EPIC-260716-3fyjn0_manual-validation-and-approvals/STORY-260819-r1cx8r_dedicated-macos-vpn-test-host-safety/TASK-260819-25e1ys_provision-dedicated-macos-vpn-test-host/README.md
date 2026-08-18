# TASK-260819-25e1ys: provision-dedicated-macos-vpn-test-host

## Description
Human gate: provide a dedicated Mac for all tests that install or activate the packet-tunnel system extension, save a VPN configuration, change routes or DNS, or call startVPNTunnel.

## Scope
A separate Intel or Apple-silicon Mac running supported macOS 15 or newer; never the current development/build host.

## Acceptance Criteria
The test Mac hostname is recorded without secrets; SSH reachability is available; the human has completed required GUI approvals; a harmless preflight proves the orchestrator is not targeting the current build host.
