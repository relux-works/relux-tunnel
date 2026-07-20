# ReluxLibSSH2

This directory carries the bounded Relux patch set for libssh2 commit
`a34302491c164d53c900fec9b3cbb050ecebe719`. Upstream source is not silently
vendored or fetched at runtime. The build command accepts the two audited source
archives, verifies both SHA-256 values before extraction or patching, applies the
single allowlisted patch in a disposable directory, and produces the checked-in
static XCFramework.

The public additions are:

```c
int libssh2_session_rekey(LIBSSH2_SESSION *session);
void libssh2_session_server_kex_observer_set(...);
int libssh2_session_server_kex_status(...);
int libssh2_session_global_request(...);
```

The rekey operation drives the existing `ssh2_kex_exchange(session, 1, ...)`
state machine. The observer reports server-initiated start/success/failure with
a monotonic generation, directly from inbound KEXINIT and the existing KEX
completion paths. The global-request operation sends one bounded, want-reply
request through libssh2's normal transport and correlates the ordered
success/failure reply. A timed-out request remains pending so a late reply
cannot be mistaken for a newer request. In nonblocking mode callers repeat
after `LIBSSH2_ERROR_EAGAIN` (and repeat the same request after
`LIBSSH2_ERROR_TIMEOUT`). No private header is distributed by the XCFramework.

See `UPSTREAM.md` for exact source inputs and `RELUX_DELTA.md` for the delta and
rebase procedure.
