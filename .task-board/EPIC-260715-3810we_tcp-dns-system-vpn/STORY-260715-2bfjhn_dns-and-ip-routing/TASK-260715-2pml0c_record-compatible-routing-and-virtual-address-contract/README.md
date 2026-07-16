# Record the M1 compatible routing, virtual address, and DNS contract

## Description
Produce the task-scoped network contract for baseline compatible mode. Select collision-conscious virtual IPv4 and IPv6 addresses, tunnel DNS listener addresses, accepted M0 MTU, included default routes, actual SSH endpoint exclusions, settings application ordering, and failure behavior for iOS and macOS.

## Scope
In scope: address plan and prefix sizes, IPv4 and IPv6 default included routes, endpoint host routes, DNS server and match-domain configuration, M0 MTU decision consumption, Apple automatic tunnel-server exclusion validation, packet protocol family mapping, settings atomicity, rollback, compatible-mode exceptions, and test matrix. Out of scope: fail-closed includeAllNetworks, path-change exclusion rebuild, captive recovery, general UDP, fake DNS, NAT64 transition resilience, implementation, and re-deciding M0 MTU.

## Acceptance Criteria
1. A TASK-ID-scoped contract records exact candidate address ranges and collision checks against common local, VPN, documentation, and reserved ranges, with a deterministic conflict response. 2. IPv4 and IPv6 included routes, endpoint exclusions, DNS addresses, match domains, MTU, and platform-specific settings fields are fully enumerated. 3. The contract shows SSH connect and actual endpoint capture before settings, network settings before packet reads, and rollback when any mandatory step fails. 4. Automatic versus explicit endpoint exclusion behavior is a platform-testable rule rather than an assumption, and exclusions are host routes only. 5. Compatible-mode Apple system exceptions and the handoff to M3 fail-closed and reconnect work are explicit without claiming an absolute kill switch.
