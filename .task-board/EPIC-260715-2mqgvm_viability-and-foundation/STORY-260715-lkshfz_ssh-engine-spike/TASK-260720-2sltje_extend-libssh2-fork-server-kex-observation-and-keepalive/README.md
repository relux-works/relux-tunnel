# TASK-260720-2sltje: extend-libssh2-fork-server-kex-observation-and-keepalive

## Description
Second minimal libssh2 fork extension (after the client-rekey export TASK-260720-3vwls7), required by TASK-260715-1ozsb6 round 2 (see server-rekey-keepalive-blocker.md). Expose two more PUBLIC observation seams pinned libssh2 keeps internal, over behavior it already performs: (1) typed server-initiated KEX start/success/failure observation + a generation counter, so the adapter can truthfully emit server-rekey state/events; (2) a nonblocking, reply-correlated generic global-request/keepalive operation exposing reply completion, so the adapter can emit keepalive RTT/timeout/miss. These are the LAST known contract clauses for libssh2; if a THIRD round appears, the orchestrator escalates the M0-vs-M3 contract-scope question to the human. Per ADR-019 (libssh2 locally-rebuilt static XCFramework).

## Scope
(define task scope)

## Acceptance Criteria
1. Public typed server-KEX observation (start/success/failure + a monotonic generation counter) callable from the adapter with NO private-symbol import; a deterministic test proves a server-initiated rekey is observed with correct state transitions and generation increment. 2. Public nonblocking reply-correlated global-request/keepalive op exposing request name, bounded payload, and reply completion (for RTT), preserving packet ordering; a test proves a request->reply RTT and a timeout/miss path. 3. Both hooks are OBSERVATION over existing libssh2 behavior (no crypto/algorithm change); patch minimal + allowlisted, PATCH_MANIFEST + delta doc updated, BSD-3-Clause + OpenSSL notices preserved. 4. Rebuilds into the static extension-safe ReluxLibSSH2 XCFramework via the TASK-260715-1g9cyt seam, checksum-verifying pinned source; passes static/extension gates. 5. make validate-core passes (no libssh2/OpenSSL leak into ReluxTunnelCore); swift build + the new fork tests pass.
