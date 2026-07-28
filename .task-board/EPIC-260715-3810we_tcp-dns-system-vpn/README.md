# M1 — TCP and DNS system VPN

## Description
Deliver the shared packet-tunnel core for full-device TCP and leak-free DNS over an authenticated SSH host on iOS and macOS.

## Scope
Shared tunnel core, host/extension boundary, verified SSH authentication, TCP direct-tcpip forwarding, IPv4/IPv6 routing, leak-free DNS, and baseline system VPN control on iOS and macOS.

## Acceptance Criteria
One configured SSH profile provides stable full-device TCP and leak-free DNS on the physical Apple-silicon Mac; the physical-iPhone row is a named deferred gap under ADR-024, never inferred from Mac results and never a pass; external IP follows the exit host; route loops and UI-process dependency are absent; validation evidence is attached.
