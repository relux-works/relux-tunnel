# Document M1 TCP forwarding and reserved M3 scheduler seams

## Description
Document the implemented packet-to-HEV-to-private-SOCKS-to-direct-tcpip TCP path, security boundary, wire and state contracts, limits, backpressure, close behavior, diagnostics, test commands, measured ceilings, and the interface M3 may use for lane selection without migrating live flows.

## Scope
In scope: component and sequence diagrams, endpoint admission, CONNECT forms, remote resolution, channel mapping, buffer budget, admission limits, EOF and half-close table, errors, privacy-safe metrics, troubleshooting, test and matrix reproduction, and M3 seam. Out of scope: implementing lane pools, recommending final performance tuning beyond evidence, UDP, end-user documentation, engine comparison, and code changes.

## Acceptance Criteria
1. Diagrams show original TCP termination in HEV and the distinct destination connection opened by sshd with trust boundaries. 2. Tables document every supported SOCKS form, SSH open mapping, buffer and admission ceiling, terminal event, application-visible result, and metric. 3. Security documentation proves the internal endpoint is not a general proxy and names the admission mechanism on both platforms. 4. Reproduction commands cover parser fuzz, fake conformance, HEV integration, and concurrency or rekey matrix with fixture requirements. 5. The M3 seam accepts new-flow lane selection inputs but explicitly forbids moving an established flow or changing M1 correctness.
