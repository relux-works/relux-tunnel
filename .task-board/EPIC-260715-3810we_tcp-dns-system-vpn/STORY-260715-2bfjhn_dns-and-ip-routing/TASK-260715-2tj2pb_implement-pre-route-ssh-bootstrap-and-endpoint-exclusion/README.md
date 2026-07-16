# Integrate pre-route SSH bootstrap and narrow endpoint exclusions

## Description
Implement the routing-layer orchestration that invokes the authenticated SSHBootstrapService while the physical path is still available, consumes its actual connected endpoint evidence, validates it against the selected profile and path, and derives only the host exclusion required to keep that transport outside upcoming default routes.

## Scope
In scope: bootstrap invocation before network settings, candidate versus actual endpoint tracking, IPv4 and IPv6 endpoint normalization, synthesized endpoint evidence passed through from the SSH layer, host-prefix exclusion derivation, tunnel-server address field where required by Apple, validation, cancellation, metrics, and handoff to settings builder. Out of scope: reimplementing SSH resolution or authentication, reconnect after endpoint change, broad subnet exclusions, physical DNS use after settings, general route application, and path migration.

## Acceptance Criteria
1. The orchestration cannot call the network-settings builder until authenticated bootstrap returns one actual connected endpoint. 2. IPv4 and IPv6 actual endpoints produce exactly one narrow host exclusion per active transport endpoint using platform-correct prefix length. 3. A candidate address that differs from the actual remote cannot silently remain the sole exclusion, and malformed, unspecified, multicast, loopback, or tunnel-conflicting endpoints fail before settings. 4. Cancellation or bootstrap failure installs no default route or tunnel DNS configuration and releases all candidate state. 5. Tests capture invocation order, endpoint normalization, candidate or actual mismatch, both families, invalid endpoints, and privacy-safe endpoint-family metrics.
