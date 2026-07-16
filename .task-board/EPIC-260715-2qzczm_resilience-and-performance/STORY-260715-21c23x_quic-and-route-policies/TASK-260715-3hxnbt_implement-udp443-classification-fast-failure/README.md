# Implement destination UDP/443 classification and bounded fast failure

## Description
Implement the owned UDP admission hook that identifies new destination UDP port 443 flows after tunnel-DNS classification, forwards an explicit policy request or produces the stack-supported local unreachable or equivalent fast failure, and leaves unrelated UDP unchanged.

## Scope
In scope: IPv4 and IPv6 destination port classification; tunnel DNS precedence; new association or first-datagram boundary; current policy generation; supported HEV or adapter rejection mechanism; bounded completion; error and aggregate counters; malformed endpoint handling; cancellation; tests. Out of scope: payload or SNI inspection, TCP/443, application identity, Auto health decision, relay forwarding internals, route settings, synthetic behavior unsupported by the stack, destination logging, or silent discard.

## Acceptance Criteria
1. Valid IPv4 and IPv6 destination UDP/443 is classified exactly once before general relay association creation, while tunnel DNS and every unrelated UDP port follow their existing paths. 2. A reject result produces the contract-approved local error or unreachable signal within the configured bounded latency and creates no relay association, SSH channel, physical socket, or retry timer. 3. Allow or evaluate results carry only the normalized endpoint needed by the existing private adapter and one current policy generation and cannot cross a later mode generation. 4. Malformed endpoints, missing family, stale generation, cancellation, failed or stopping capability, and duplicate datagrams have deterministic bounded outcomes. 5. Unit and integrated fake-adapter tests cover v4, v6, DNS, unrelated ports, first and later datagrams, allow, reject, stale, stop, latency, resource cleanup, and aggregate privacy-safe counters.
