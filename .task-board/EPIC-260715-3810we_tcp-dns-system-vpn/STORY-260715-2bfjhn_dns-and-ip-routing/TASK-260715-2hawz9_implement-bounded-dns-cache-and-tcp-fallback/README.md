# Implement bounded DNS caching, truncation, and fallback semantics

## Description
Implement the DNS transaction policy around listener and tunneled upstream: bounded positive and negative caching, TTL expiry, request coalescing where safe, client UDP truncation handling, retry over the already TCP upstream where specified, and explicit SERVFAIL or equivalent behavior on safe-forwarding failure.

## Scope
In scope: cache key privacy and canonicalization, entry and byte ceilings, minimum and maximum TTL policy, negative caching from SOA semantics, no caching of malformed or inappropriate responses, LRU or documented eviction, concurrent miss coalescing, client transport size handling, TC behavior, TCP client responses, timeout, cancellation, metrics, and fake clock tests. Out of scope: persistent cache, prefetch, ECS, query rewriting, DNSSEC validation beyond transparency, fake DNS, physical fallback, resolver selection, and destination logging.

## Acceptance Criteria
1. Cache entries and total bytes have fixed configurable ceilings, use injected time, expire by protocol TTL policy, and are cleared on profile or resolver identity change. 2. Positive and negative responses cache only when semantically permitted, negative TTL follows authoritative data bounds, and malformed, truncated, transient-failure, or policy-excluded responses do not poison the cache. 3. Client UDP responses respect the advertised or baseline size and set TC when required so the client can retry TCP, while TCP clients receive the complete permitted response. 4. Concurrent identical misses coalesce without cross-client ID corruption, and cancellation or upstream failure returns a bounded explicit failure with no physical query. 5. Deterministic tests cover TTL boundaries, negative caching, eviction, size pressure, TC retry, mixed UDP and TCP clients, resolver change, malformed data, and query-name-free metrics.
