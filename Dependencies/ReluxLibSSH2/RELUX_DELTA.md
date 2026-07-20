# Relux delta and rebase procedure

## Delta

The fork contains one patch and changes exactly six upstream files:

| Path | Change |
| --- | --- |
| `include/libssh2.h` | Declares the client-rekey, typed server-KEX observation, and bounded reply-correlated global-request APIs. |
| `src/session.c` | Adds the client-rekey wrapper, observer/status accessors, and outstanding-request cleanup. |
| `src/packet.c` | Records inbound server KEXINIT start and increments its generation. |
| `src/kex.c` | Records success/failure when the existing KEX state machine terminates. |
| `src/keepalive.c` | Adds one bounded want-reply global-request state machine over the existing transport and ordered reply queue. |
| `src/libssh2_priv.h` | Holds the bounded observation and one-outstanding-request state. |

There are no changes to KEX algorithms, cipher, MAC, host-key, random, OpenSSL,
channel, allocator, or algorithm-list behavior. The `packet.c` and `kex.c`
changes only publish lifecycle observation around behavior already performed.
The global request still uses `ssh2_transport_send` and
`ssh2_packet_requirev`; encryption, MAC, and packet ordering are unchanged. The
public artifact excludes `src/libssh2_priv.h`.

## Rebase

1. Select a signed upstream libssh2 release and repeat the candidate security
   audit before changing the pin.
2. Update the revision/archive/license hashes in `UPSTREAM.md`,
   `PATCH_MANIFEST.json`, and `NativeDependencies/manifest.json`.
3. Run `scripts/libssh2-fork-tool.py prepare` against the new clean archives.
   A checksum mismatch or patch conflict fails closed.
4. Inspect whether upstream now has an equivalent public API. If it does,
   remove this patch and migrate callers to upstream. Do not retain two rekey
   entry points.
5. If the patch is still required, refresh only the existing patch. Any delta
   outside the six allowlisted files requires a new architecture/security
   decision rather than expanding the allowlist opportunistically.
6. Rebuild twice, compare artifact locks, regenerate notices, run
   `make validate-libssh2`, `make validate-core`, and the Apple matrix before
   review.
