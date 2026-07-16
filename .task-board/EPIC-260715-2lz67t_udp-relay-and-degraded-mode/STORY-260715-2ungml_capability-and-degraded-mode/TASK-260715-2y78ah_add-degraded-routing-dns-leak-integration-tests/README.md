# Add degraded routing, DNS leak, and recovery integration tests

## Description
Exercise the composed M2 runtime in controlled harness and macOS development contexts across startup full or degraded, relay failures, UDP rejection, TCP continuity, safe DNS, mandatory DNS loss, reprobe restoration, and physical-path sentinels.

## Scope
In scope: composed M1 packet, TCP, DNS, SSH, and provider seams; M2 bootstrap and relay fixtures; controlled TCP, UDP, and DNS endpoints; access-side physical DNS and UDP sentinels; full startup; unsupported asset; checksum or version failure; process and lane failure; general UDP rejection; safe DNS-over-TCP or approved DoH; TCP continuity; DNS loss; recovery; stop; counters; repeated runs; redaction. Out of scope: physical iPhone acceptance, path switching, NAT64 transition, captive portal, includeAllNetworks, lane pool scheduling, final QUIC policy, and public resolver benchmarking.

## Acceptance Criteria
1. Full startup carries TCP, general UDP, and DNS through the intended SSH paths, while startup relay failure publishes degraded only after TCP and safe DNS are usable. 2. Every full-to-degraded trigger stops and invalidates UDP before the snapshot, preserves controlled TCP according to M1 policy, and keeps client UDP and TCP DNS on the approved tunneled fallback. 3. Physical DNS and UDP sentinels observe zero ordinary fallback during connected, transition, degraded, failed, reprobe, and stop fault rows; safe-DNS loss produces mandatory failure. 4. Reprobe restores full only after a fresh validated relay generation and subsequent UDP and DNS traffic uses new associations with no late old-generation delivery. 5. Repeated scenarios reconcile system session, capability snapshots, TCP flows, DNS transactions, relay generation, associations, queues, channels, timers, routes, drops, and memory and return resources to baseline.
