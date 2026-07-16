# Leak-free DNS and compatible IPv4/IPv6 routing

## Description
Implement baseline compatible-mode IPv4 and IPv6 settings plus a tunnel-owned DNS service whose client UDP and TCP requests leave through SSH as DNS-over-TCP. Connect SSH before default routes, exclude only its actual endpoint, prevent loops, and prove no physical fallback in deterministic integration before physical acceptance owned by the lifecycle story.

## Scope
In scope: resolver-policy decision, virtual address and route contract, pre-route SSH bootstrap integration, actual endpoint exclusions, compatible settings, local UDP and TCP DNS service, tunneled DNS-over-TCP, truncation, bounded caching, safe startup and failure ordering, unit and harness leak tests, external-IP fixtures, and operational documentation. Out of scope: general UDP, remote relay, fake DNS, fail-closed includeAllNetworks, path migration, captive recovery, NAT64 transition resilience, QUIC, M3 reconnect, and physical provider execution owned by STORY-260715-eto58m.

## Acceptance Criteria
1. The actual SSH endpoint is captured before default routes and only the required endpoint host exclusion is derived. 2. IPv4 and IPv6 application TCP settings use compatible mode without routing SSH into itself. 3. Installed DNS points only to the tunnel service and all client UDP or TCP queries use the approved SSH exit resolver policy with bounded protocol semantics. 4. Resolver or tunnel failure never produces a physical DNS query and instead fails explicitly or stops safe forwarding. 5. Deterministic captures prove external-IP, route, and no-fallback behavior, and the physical iPhone and Mac acceptance is executed by TASK-260715-2qr5aj and TASK-260715-2wqffe.
