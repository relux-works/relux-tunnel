# Add HEV bridge integration tests

## Description
Exercise the real unmodified HEV stack through PacketFlowBridge in the macOS harness and Apple-provider test seams, proving IPv4 and IPv6 TCP translation, SOCKS contract behavior, configuration, backpressure propagation, and clean lifecycle before physical performance runs.

## Scope
In scope: real HEV and lwIP; synthetic packet endpoints; local SOCKS adapter fixture; IPv4 and IPv6 TCP handshakes and streams; half-close and reset; mixed small and bulk flows; UDP-in-TCP request framing exposure; internal endpoint rejection; induced stalls; startup and stop loops; observable counters. Out of scope: real SSH, remote UDP relay, default routes, system DNS, production internet destinations, and final throughput claims.

## Acceptance Criteria
1. Deterministic integration tests complete IPv4 and IPv6 TCP handshake, bidirectional stream, half-close, reset, and independent concurrent-flow scenarios through the real HEV binary. 2. The adapter fixture observes the expected SOCKS CONNECT and UDP-in-TCP contract, and an unowned client cannot use the internal endpoint. 3. Receiver stalls cause only bounded socket drops and recorded counters; no unbounded application queue appears. 4. Configuration tests prove the requested MTU and fixed low-memory and UDP settings reach HEV. 5. At least one hundred harness start, traffic, and stop cycles return tasks, descriptors, sessions, and allocated test resources to baseline.
