# M2 — UDP relay and degraded mode

## Description
Deliver the rootless remote relay, full UDP forwarding, and an explicit safe degraded mode when relay capability is unavailable.

## Scope
Versioned rootless relay protocol and binaries, exec upload/install, UDP association forwarding, DNS over relay, capability negotiation, and TCP plus safe-DNS fallback.

## Acceptance Criteria
Representative IPv4/IPv6 UDP traffic exits through the user host; relay failures enter an explicit degraded mode without DNS leak; protocol/resource/conformance and portable asset tests pass.
