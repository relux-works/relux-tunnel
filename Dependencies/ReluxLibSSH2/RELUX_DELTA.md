# Relux delta and rebase procedure

## Delta

The fork contains one patch and changes exactly two upstream files:

| Path | Change |
| --- | --- |
| `include/libssh2.h` | Declares `libssh2_session_rekey` as `LIBSSH2_API`. |
| `src/session.c` | Adds a null-checked `BLOCK_ADJUST` wrapper over `ssh2_kex_exchange(session, 1, &session->startup_key_state)`. |

There are no changes to KEX, cipher, MAC, host-key, random, OpenSSL, packet,
channel, allocator, or algorithm-list code. The public artifact excludes
`src/libssh2_priv.h`.

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
   outside the two allowlisted files requires a new architecture/security
   decision rather than expanding the allowlist opportunistically.
6. Rebuild twice, compare artifact locks, regenerate notices, run
   `make validate-libssh2`, `make validate-core`, and the Apple matrix before
   review.

