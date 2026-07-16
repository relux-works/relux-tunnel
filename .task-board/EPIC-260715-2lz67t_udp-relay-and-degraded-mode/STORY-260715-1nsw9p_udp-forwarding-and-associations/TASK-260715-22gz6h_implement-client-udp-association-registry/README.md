# Implement the client UDP association registry

## Description
Implement the extension-owned mapping between one HEV UDP association handle and one nonzero client-allocated protocol associationID, with bounded admission, generation isolation, idle and close states, wraparound safety, and deterministic cleanup.

## Scope
In scope: nonzero UInt32 ID allocation; active, closing, expired, and closed states; HEV association handle ownership; relay session generation; maximum association count; injected clock; activity updates; local and remote close; expiry completion; ID reuse only after terminal cleanup; wraparound and collision search bound; cancellation; aggregate metrics. Out of scope: parsing HEV frames, SSH channel I/O, relay-side sockets, domain resolution, choosing idle timeout values before the protocol-limit decision, DNS priority, and storing destination history.

## Acceptance Criteria
1. Each admitted HEV association receives one unique nonzero ID scoped to the active relay generation and no active or closing ID is reused. 2. Admission, activity, local close, remote close, error, expiry, session loss, and provider stop follow one explicit state table and invoke the HEV and relay cleanup callbacks once. 3. Configured association and allocator-search ceilings prevent wraparound, collision, or exhaustion from causing unbounded loops or memory growth and return a typed fast failure. 4. Old-generation timers, replies, errors, and closes cannot resolve to a new association even if the numeric ID is later reused after permitted terminal cleanup. 5. Fake-clock and property tests cover concurrency, wraparound, duplicate close, crossed close, expiry races, session replacement, cancellation, and return entries, timers, and callbacks to baseline.
