# Integrate safe routing and DNS startup and failure ordering

## Description
Integrate authenticated SSH endpoint evidence, prepared packet plane, private TCP adapter, ready tunnel DNS service, compatible settings builder, Network Extension settings application, packet reads, and capability publication into the shared runtime in the exact leak-safe order. Roll back routes and DNS on every mandatory failure.

## Scope
In scope: coordinator dependency hooks, DNS readiness before settings, settings apply completion, packet-read start, capability publication, failure before and after settings, stop ordering, DNS or SSH mandatory health loss, route teardown, generation safety, diagnostics, and both provider adapters. Out of scope: implementing component internals, reconnect and reasserting, live endpoint exclusion change, fail-closed includeAllNetworks, UDP relay, lane pools, and path transitions.

## Acceptance Criteria
1. Runtime order is profile and SSH bootstrap, packet and TCP preparation, DNS readiness, settings construction and apply, packet reads, then TCP and safe-DNS capability publication. 2. No packet read or usable capability begins before settings apply succeeds, and no settings apply occurs without authenticated SSH and a ready no-fallback DNS path. 3. Failure or cancellation before settings leaves no tunnel route, while failure after settings stops new forwarding and removes or invalidates settings through the provider contract before reporting terminal failure. 4. Mandatory SSH, packet, TCP, or DNS health loss cannot silently preserve a connected-capable snapshot or fall back to physical DNS. 5. Cross-component fault tests cover every boundary, late callback, duplicate stop, and repeated generation with exact ordering and resource baselines.
