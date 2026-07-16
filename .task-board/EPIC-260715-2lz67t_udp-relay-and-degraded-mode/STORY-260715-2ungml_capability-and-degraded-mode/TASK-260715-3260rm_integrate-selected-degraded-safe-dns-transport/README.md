# Integrate the selected degraded safe-DNS transport

## Description
Wire the approved safe-DNS upstream into degraded startup, runtime health, cache generation, and shutdown using the existing M1 DNS listener and SSH DNS-over-TCP path or the explicitly approved tunneled DoH implementation.

## Scope
In scope: consume M1 DNS listener, transaction, cache, resolver, and SSH upstream components; selected transport construction; authenticated SSH dependency; readiness probe; UDP and TCP client queries; TC and length semantics; bounded connections, requests, bytes, timeouts, and retries; cache invalidation on resolver or generation change; health loss; cancellation; typed failure; metrics without query data. Out of scope: relay UDP, physical resolver fallback, new resolver selection, recursive server implementation, fake DNS, general HTTP client outside approved DoH scope, path reconnect, and final UI.

## Acceptance Criteria
1. Degraded DNS accepts the existing virtual-network UDP and TCP clients and sends every upstream request only through the selected authenticated tunneled transport to the approved resolver. 2. Readiness is not published until transport construction and a deterministic safe health condition succeed, and runtime loss emits a typed mandatory failure before any physical fallback. 3. TCP framing or approved DoH request and certificate behavior, correlation, maximum message size, TC, timeout, cancellation, cache generation, and retry rules match the recorded policy and M1 transaction contract. 4. Connections, channels, requests, response buffers, cache entries, timers, and retries remain within fixed ceilings and return to baseline on mode change, profile change, SSH loss, and stop. 5. Controlled resolver and fake-channel tests cover both client transports, IPv4 and IPv6 resolver endpoints where approved, success, malformed response, timeout, certificate failure if applicable, cancellation, repeated cleanup, and zero physical sentinel observations.
