# Verify Mac IPv4, IPv6, routing, external-IP, and DNS leak behavior

## Description
Run the M1 routing and leak matrix on a named physical Apple-silicon Mac with a configured authenticated SSH profile. Capture supported IPv4, IPv6, and dual-stack application TCP, UDP and TCP DNS clients, external address observations, exact SSH endpoint exclusion, host-app exit continuity, resolver failures, and no ordinary physical DNS fallback.

## Scope
In scope: supported physical Mac and macOS, stable Ethernet or Wi-Fi starting paths without transition testing, controlled exit host and resolver, browser and representative TCP tools, dig or equivalent UDP and TCP queries, authorized packet capture on physical and exit interfaces, system VPN state, normal and forced host exit, repeated runs, memory and drop counters, and redacted evidence. Out of scope: network transitions, sleep or wake resilience, captive recovery, general UDP, QUIC, fail-closed mode, Developer ID distribution, notarization, legacy app traffic, and unrelated system traffic capture.

## Acceptance Criteria
1. Evidence records Mac class, macOS and Xcode, source and dependency revisions, profile generation, exit and resolver fixture identity, route mode, MTU, network type, timestamp, duration, counters, and authorized capture points. 2. Representative application TCP works for supported IPv4 and IPv6 paths and external observations match the selected SSH exit host. 3. UDP and TCP DNS clients resolve through the tunnel, exit-side observation matches policy, and physical-interface capture shows zero ordinary queries to local resolvers after settings apply. 4. Route inspection and capture show only the actual SSH endpoint bypass, no recursive loop, application traffic in the tunnel, and uninterrupted forwarding after host quit or termination. 5. Resolver and SSH failure rows fail safely without physical DNS fallback, repeated runs clean up routes and DNS, and a TASK-ID-scoped redacted bundle supports repetition.
