# Add integrated tunneled DNS, external-IP, and no-leak harness tests

## Description
Exercise the composed M1 runtime in controlled harness and macOS development contexts with dual-stack TCP traffic, client UDP and TCP DNS, SSH DNS-over-TCP, route settings instrumentation, external-IP endpoints, forced resolver or SSH failures, and physical-path DNS monitors. Prove correctness before the physical-device matrices.

## Scope
In scope: controlled IPv4 and IPv6 web or echo destinations, external address observation, authoritative DNS fixture, UDP and TCP client queries, cache and TC behavior, selected exit resolver, SSH endpoint exclusion, route-order events, simulated physical resolver sentinel, mandatory failure, repeated start and stop, diagnostics reconciliation, and privacy-safe captures. Out of scope: general UDP forwarding, public resolver benchmarking, path transitions, captive recovery, fail-closed mode, QUIC, final physical iPhone evidence, and production traffic.

## Acceptance Criteria
1. Representative TCP and DNS fixture traffic succeeds through one authenticated SSH host for IPv4 and IPv6, and observed external addresses and resolver source match the exit fixtures. 2. UDP and TCP client DNS both traverse the SSH DNS-over-TCP transport, cache and TC cases behave correctly, and the physical resolver sentinel observes zero ordinary post-settings queries. 3. SSH endpoint traffic remains outside its own default route while all synthetic application TCP uses the tunnel, with no recursive route loop or broad bypass. 4. Resolver timeout, malformed reply, SSH loss, settings failure, and DNS component failure produce bounded explicit failure and zero physical fallback. 5. Repeated runs reconcile runtime, packet, TCP, DNS, channel, route, and drop counters and return resources to baseline.
