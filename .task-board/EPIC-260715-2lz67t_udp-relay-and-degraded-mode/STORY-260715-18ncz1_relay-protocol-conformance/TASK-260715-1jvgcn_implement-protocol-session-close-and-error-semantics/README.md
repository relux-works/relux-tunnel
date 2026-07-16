# Implement protocol session close, error, and direction semantics

## Description
Implement protocol behavior above raw decoding for allowed message direction, association-scoped versus session-scoped failure, PING or PONG, bounded UDP_ERROR, CLOSE_ASSOCIATION, CLOSE_SESSION, and generation-safe termination.

## Scope
In scope: per-type direction checks; zero and nonzero associationID rules; bounded opaque health payload; stable UDP error code and optional bounded metadata policy; graceful and abrupt close ordering; one close acknowledgement policy; unknown v1 type; reserved flags; malformed datagram escalation; idempotent cleanup callbacks; session generation identity. Out of scope: maintaining UDP sockets or timers, health scheduling, transport reconnect, user-facing capability state, protocol v2 extensibility implementation, and payload destination logging.

## Acceptance Criteria
1. A transition table implemented by both peers defines legal direction, associationID use, payload bounds, response, and close effect for every v1 message. 2. Unknown v1 types, nonzero reserved flags, illegal direction, invalid session-level association IDs, and unrecoverable framing state close the session; safely attributable malformed datagrams reject only the association. 3. PONG echoes only a bounded PING payload, UDP_ERROR uses only generated finite codes, and no remote-controlled diagnostic string reaches default logs or UI. 4. CLOSE_ASSOCIATION and CLOSE_SESSION are idempotent under duplicates, crossed closes, EOF, cancellation, and late callbacks and invoke owned cleanup once per generation. 5. Deterministic paired-peer tests cover nominal, crossed, duplicate, hostile, and abrupt-close sequences and reconcile all close and error counters.
