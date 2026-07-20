# ReluxLibSSH2

This directory carries the bounded Relux patch set for libssh2 commit
`a34302491c164d53c900fec9b3cbb050ecebe719`. Upstream source is not silently
vendored or fetched at runtime. The build command accepts the two audited source
archives, verifies both SHA-256 values before extraction or patching, applies the
single allowlisted patch in a disposable directory, and produces the checked-in
static XCFramework.

The public addition is:

```c
int libssh2_session_rekey(LIBSSH2_SESSION *session);
```

It drives the existing `ssh2_kex_exchange(session, 1, ...)` state machine. In
nonblocking mode callers repeat after `LIBSSH2_ERROR_EAGAIN`; blocking mode uses
libssh2's normal socket-wait adjustment. No private header is distributed by the
XCFramework.

See `UPSTREAM.md` for exact source inputs and `RELUX_DELTA.md` for the delta and
rebase procedure.

