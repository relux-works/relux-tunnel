# Implement relay UDP I/O, destination resolution, and response mapping

## Description
Implement nonblocking datagram egress and ingress for relay associations, including IPv4, IPv6, bounded domain resolution, source endpoint preservation, UDP error mapping, oversize handling, fair socket work, and cancellation.

## Scope
In scope: sendto and recvfrom or approved equivalents; numeric IPv4 and IPv6 destinations; bounded asynchronous exit-host domain resolution; address result cap and family policy; port validation; maximum UDP payload; truncation detection; source sockaddr conversion; retry only for readiness transitions; finite socket error mapping; per-turn datagram and time budget; association activity; cancellation; counters. Out of scope: DNS recursion by the relay, caching arbitrary destination names beyond bounded resolver needs, splitting one UDP datagram, application protocol parsing, ICMP tunneling, public listener behavior, and logging names, addresses, or payloads.

## Acceptance Criteria
1. Valid numeric and domain datagrams leave through association-owned exit-host sockets and replies encode the exact source family, address, port, and bytes observed by the relay. 2. Domain resolution is cancellable and bounded by name size, result count, time, memory, and concurrent requests and never logs or persists destination names by default. 3. Oversized or truncated datagrams, invalid ports or addresses, unsupported family, resolution failure, unreachable or permission socket errors, and closed associations produce generated bounded errors or documented drops without splitting data. 4. EAGAIN and queue pressure never busy-spin or allocate an unbounded retry buffer; each event-loop turn respects explicit datagram and time budgets across active sockets. 5. Controlled IPv4, IPv6, dual-stack, domain, error, receiver-stall, oversize, cancellation, and reply-source tests verify byte integrity, fairness, cleanup, and privacy-safe counters.
