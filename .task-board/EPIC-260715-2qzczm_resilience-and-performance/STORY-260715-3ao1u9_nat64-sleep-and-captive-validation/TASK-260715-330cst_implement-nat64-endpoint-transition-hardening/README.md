# Implement NAT64 and endpoint-family transition hardening

## Description
Harden reconnect and settings replacement for IPv6-only NAT64 and native address-family changes so cached candidates, required-interface resolution, actual synthesized or native endpoints, exact exclusions, DNS, and capabilities remain current and leak-safe.

## Scope
In scope: IPv4, IPv6, dual-stack, and IPv6-only path evidence; cached candidate invalidation; hostname reconnect; synthesized actual endpoint capture; v4-to-v6 and v6-to-v4 change; Happy Eyeballs ordering only as approved by existing endpoint service; exact /32 or /128 exclusion replacement; settings generation; safe DNS; relay and association invalidation; diagnostics and tests. Out of scope: implementing a DNS64 resolver, manually synthesizing addresses without the approved network stack, broad prefix exclusions, host-key bypass, physical matrix execution, path monitor internals, or final preference tuning.

## Acceptance Criteria
1. On IPv6-only paths fresh hostname connection can return and record the actual synthesized IPv6 endpoint and no code assumes an original IPv4 literal is directly reachable. 2. Family changes invalidate incompatible cached candidates, preserve canonical host identity, retry through the selected physical interface, and install exactly the current /32 or /128 exclusion before usable capability. 3. Old endpoint routes, relay associations, DNS generation, and optional lanes cannot survive into the replacement generation or receive late traffic. 4. No transition performs ordinary DNS lookup through the stale tunnel, falls back to a physical resolver after tunnel DNS applies, installs a NAT64 prefix exclusion, or loops the SSH connection into the tunnel. 5. Controlled fake-network and resolver tests cover IPv6-only start, synthesized endpoint, native v6, v4 to NAT64, NAT64 to v4, address change, stale cache, same identity, host change, failure, stop, and cleanup.
