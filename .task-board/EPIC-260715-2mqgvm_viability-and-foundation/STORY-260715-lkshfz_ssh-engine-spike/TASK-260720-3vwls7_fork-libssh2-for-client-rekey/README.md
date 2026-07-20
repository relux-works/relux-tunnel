# TASK-260720-3vwls7: fork-libssh2-for-client-rekey

## Description
Minimal libssh2 fork exposing a PUBLIC client-initiated rekey (key re-exchange) operation, discovered required by TASK-260715-1ozsb6 (see libssh2-rekey-blocker.md). libssh2 ALREADY implements KEX re-exchange for server-initiated rekey (src/packet.c calls ssh2_kex_exchange(session,1,...) on inbound KEXINIT), but ssh2_kex_exchange is declared only in private src/libssh2_priv.h and absent from include/libssh2.h. This is the libssh2 analogue of the NIOSSH _rekey() fork (nzdzv3): a SINGLE bounded patch exporting the existing client-rekey trigger, packaged via the ADR-019 XCFramework seam (1g9cyt). This is the last blocker for the libssh2 adapter, which otherwise composes cleanly with the neutral contract (unlike NIOSSH). Keep concrete libssh2 inside the fork/adapter boundary.

## Scope
(define task scope)

## Acceptance Criteria
1. A minimal patch to pinned libssh2 (a34302491c164d53c900fec9b3cbb050ecebe719) exports a PUBLIC client-initiated rekey op (e.g. libssh2_session_rekey) driving the existing ssh2_kex_exchange(session, reexchange=1); declared in a public header, callable from the adapter with NO private-header/symbol import. 2. The exported op performs a real KEX (not a no-op/counter reset); a deterministic test proves a client rekey completes and re-establishes session keys AND server-initiated rekey still works. 3. libssh2 crypto/algorithms otherwise unchanged; patch minimal + allowlisted + documented (patch manifest + delta/rebase doc); BSD-3-Clause + OpenSSL notices preserved. 4. Forked libssh2 rebuilds into the static XCFramework via the ADR-019 seam (1g9cyt), checksum-verifying pinned source before patching; passes extension-safety/static gates. 5. make validate-core passes (libssh2/OpenSSL do not leak into ReluxTunnelCore); swift build + the fork rekey test pass.
