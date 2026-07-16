# Add UDP hostile-input, pressure, fuzz, and soak tests

## Description
Stress the composed UDP path with malformed inner and outer data, hostile addresses, association and queue exhaustion, socket stalls, resolution pressure, process loss, mixed DNS load, and long-running churn while proving bounded resources and privacy.

## Scope
In scope: mutation corpus for protocol and HEV frames; arbitrary chunking; invalid association IDs and reuse; domain and sockaddr edge cases; oversize and truncation; many associations; per-association and global queue pressure; stalled SSH and UDP receivers; DNS priority abuse; resolver timeout; socket errors; relay exit; cancellation; allocation ceilings; deterministic seeds; hours-scale controlled soak; log redaction scans. Out of scope: public-target fuzzing, denial of service against shared infrastructure, physical path transitions, product analytics, real traffic capture, optimizing after failed tests, and waiving hard caps.

## Acceptance Criteria
1. Fuzz and mutation cases cause no crash, hang, recursion blowup, unbounded allocation, cross-association delivery, stale-generation use, or divergence from declared association-versus-session failure scope. 2. Association, socket, timer, resolver, frame, and byte exhaustion never exceeds configured ceilings and control or DNS priority cannot create an unbounded starvation or priority-abuse path. 3. Deliberate SSH and UDP stalls, queue saturation, EAGAIN, process exit, partial frames, and cancellation produce expected drops or errors without busy-spin and return resources after release. 4. A mixed IPv4, IPv6, domain, DNS, open or close, and expiry soak records duration, traffic shape, limits, peak memory, descriptors, queues, drops, errors, CPU, and cleanup with no monotonic growth. 5. Deterministic seeds and redacted evidence are retained, and automated scans confirm no payload, query name, destination address, domain, credential, or full local address appears in default logs.
