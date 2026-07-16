# Implement the public socket-pair PacketFlowBridge

## Description
Implement the Swift bridge that exchanges packet batches between NEPacketTunnelFlow and the HEV descriptor endpoint through a nonblocking AF_UNIX SOCK_DGRAM socket pair, following the approved contract exactly.

## Scope
In scope: socket-pair creation; close-on-exec and nonblocking configuration; socket-buffer request and effective-value readback; endpoint transfer; four-byte network-order AF_INET and AF_INET6 headers; batch reads and writes; count and time budgets; reason-specific counters; cancellation; privacy-safe failures; dependency injection. Out of scope: HEV startup, SSH, routes, DNS, private APIs, retries after bounded-queue drops, unbounded buffering, final tuning constants, and product UI.

## Acceptance Criteria
1. Static inspection and tests show that the implementation references only NEPacketTunnelFlow and documented Darwin socket APIs and never discovers or reopens utun descriptors. 2. Each packet read from packetFlow is sent as one datagram with the correct family header, and each valid reverse datagram becomes one packet with the matching protocol family. 3. Socket buffer requests and effective readbacks are exposed in metrics; EAGAIN, EWOULDBLOCK, and ENOBUFS increment distinct drop counters without retry or side storage. 4. EMSGSIZE fails the current start with attempted datagram size and effective limit; persistent failures produce bounded privacy-safe errors. 5. All descriptors, read sources, continuations, and tasks close exactly once under normal stop, start failure, and cancellation.
