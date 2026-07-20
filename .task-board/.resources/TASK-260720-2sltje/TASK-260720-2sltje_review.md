# Review verdict: ACCEPTED (done)

Reviewer independently re-verified the implementation against all five AC.

## AC verification
1. Server-KEX observation: hook placement checked against pristine pinned source (archive SHA matches UPSTREAM.md). The packet.c hook sits inside the branch guarded by msg==SSH_MSG_KEXINIT && !(state & SSH2_STATE_EXCHANGING_KEYS) — fires only for server-initiated KEXINIT, once per exchange, riding on the same guard as upstream's own state reset. kex.c completion hook is unreachable on EAGAIN (all three EAGAIN paths return before the tail) and explicit on both -1 early-failure returns; state==STARTED guard keeps initial handshake and client-initiated rekey silent (live test asserts NONE/generation 0 after handshake + client rekey). Live fixture: 14 transitions in STARTED->terminal pairs with generation increments incl. a deliberate FAILED path. Swift packaging tests call all four APIs with no private-symbol import.
2. Global request: bounded (255/1024, INVAL on violation), nonblocking (EAGAIN observed), one-outstanding with argument-consistency check (BAD_USE on mismatch), reply via existing ssh2_packet_requirev over the ordered brigade (verified pristine packet.c has no competing REQUEST_SUCCESS/FAILURE special-casing). Reviewer re-run: RTT=33ms, 1 deterministic timeout/miss, late-reply correlation proven by completing the same request after TIMEOUT. Cleanup on error paths and session_free.
3. Observation-only: 222 insertions, 6 files, no crypto/algorithm change; fork tool prohibits openssl.c/crypto/crypt.c/mac.c/hostkey.c and requires transport/requirev routing; PATCH_MANIFEST (sha256, allowed_paths, symbols, max paths 2->6) + RELUX_DELTA.md updated; BSD-3-Clause + OpenSSL notices present; priv header excluded from artifact.
4. Rebuild: all three slices rebuilt, identical header SHA across slices, nm shows the four public symbols, artifact lock verified, byte-identical rebuild locks in reproducibility log.
5. Gates re-run by reviewer: make check-libssh2 PASS; make test-libssh2 PASS (live sshd); make validate-core PASS (boundary + 64 tests + swift build); swift format lint exit 0.

## Non-blocking observations
- Patch file name 0001-public-client-rekey.patch is now broader than its name; subject line inside is accurate. Cosmetic only.
- Adapter contract note for TASK-260715-1ozsb6: do NOT enable built-in libssh2_keepalive_config(want_reply=1) concurrently with libssh2_session_global_request — SSH global replies are unnumbered, so a builtin-keepalive reply would be miscorrelated. Header's one-outstanding rule covers this; the adapter must own it.
- validate-native Apple matrix stops on the pre-existing HEV deployment-target mismatch, correctly filed as BUG-260720-2zh86a; outside this task's delta.