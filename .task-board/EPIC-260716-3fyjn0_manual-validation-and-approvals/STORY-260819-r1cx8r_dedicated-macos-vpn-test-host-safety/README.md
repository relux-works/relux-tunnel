# STORY-260819-r1cx8r: dedicated-macos-vpn-test-host-safety

## Description
Protect the developer build host from system VPN installation or activation and route every network-mutating macOS validation to an explicitly provisioned test Mac.

## Scope
macOS physical VPN validation only; the current build host remains build/unit/integration-test only.

## Acceptance Criteria
All network-mutating macOS validation is gated on a dedicated test host; the build host never installs, activates, saves, or starts a system VPN configuration.
