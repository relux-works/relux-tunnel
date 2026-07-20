# TASK-260715-1ozsb6 — server-rekey and keepalive stop-line evidence

## Decision boundary

The accepted TASK-260720-3vwls7 fork adds one public, nonblocking
`libssh2_session_rekey` entry point. That resolves the previous inability to
initiate client byte/time/manual rekey, but it does not expose server-initiated
KEX lifecycle or a reply-correlated keepalive/global-request operation.

The reviewed common contract makes both behaviors mandatory:

- server `SSH_MSG_KEXINIT` must be recorded as `serverInitiated`, participate in
  the one-KEX state/generation model, and emit start/success/failure events;
- keepalive must require and observe a reply, return measured monotonic RTT,
  enforce reply timeout and consecutive-miss policy, and allow only one
  outstanding request.

The task instruction requires a stop-the-line result when a mandatory clause
cannot be satisfied by the public API. A test double or inferred success is not
conformance evidence.

## Exact pinned evidence

Inspected the accepted static XCFramework rebuilt from libssh2 commit
`a34302491c164d53c900fec9b3cbb050ecebe719`, OpenSSL `3.5.7`, and the reviewed
two-file client-rekey patch. The installed macOS public header SHA-256 is
`27da2886742f5d20c169a88b9fad43a25fabd9fd509d8a74ff41bcf877e5badd`;
the patch SHA-256 is
`873b3c2bad8ba481f7122922d075333f736853f8efab6cd39edc35098d111924`.

### Server-initiated KEX is not observable

- `include/libssh2.h` exports `libssh2_session_rekey` but no rekey callback,
  KEX-in-progress query, KEX generation, or server-KEX notification.
- Pinned `src/packet.c:1336-1369` recognizes inbound `SSH_MSG_KEXINIT`, resets
  private packet/KEX state, and directly calls private
  `ssh2_kex_exchange(session, 1, &session->startup_key_state)`.
- Pinned `src/transport.c:407-425` and `1039-1048` redirect reads/writes into the
  same private exchange while `SSH2_STATE_EXCHANGING_KEYS` is set.
- The application sees only the enclosing public operation's eventual result.
  It cannot distinguish ordinary EAGAIN from server-KEX start, identify the
  reason, or know when generation changed.
- The public trace handler is not a protocol API; the header explicitly notes
  that tracing has no effect in builds without debug enabled. Parsing optional
  diagnostic text would be an unsupported, privacy-fragile forced fit.

Therefore the adapter cannot truthfully implement `serverRekeys`,
`activeKeyExchange`, the server reason set, or KEX generation/events.

### Keepalive does not observe a reply

- `libssh2_keepalive_config(session, want_reply: 1, interval)` only stores
  interval and a boolean.
- Pinned `src/keepalive.c:52-96` constructs
  `keepalive@libssh2.org`, sets the final `want-reply` byte, queues it with
  `ssh2_transport_send`, updates `keepalive_last_sent`, and returns.
- It does not register an outstanding request, wait for
  `SSH_MSG_REQUEST_SUCCESS`/`SSH_MSG_REQUEST_FAILURE`, expose acknowledgement,
  or calculate RTT. It even treats transport `EAGAIN` as a non-error.
- The public header exports no generic global-request function and no reply
  retrieval/correlation function. The relevant archive symbol check finds only
  `libssh2_keepalive_config`, `libssh2_keepalive_send`, and
  `libssh2_session_rekey`; no global-request or keepalive-reply API exists.

Therefore `sendKeepalive()` cannot return reply RTT, enforce reply timeout or
miss allowance, or reconcile acknowledged/timed-out metrics. Treating queued
send as acknowledgement would silently weaken the accepted liveness contract.

## Other confirmed seams (not blockers)

- Custom send/receive callbacks can return `-EAGAIN`; a bounded synchronous
  callback buffer plus async `SSHTCPConnection` readiness/read/write driver is
  implementable without blocking provider executors.
- The external public-key sign callback explicitly accepts
  `LIBSSH2_ERROR_EAGAIN`, so it can capture the RFC 4252 payload, await the
  injected async signer outside C, and resume with the signature without
  exporting private key bytes.
- A direct-tcpip request can use generic `libssh2_channel_open_ex` with a
  caller-encoded RFC 4254 payload, avoiding the helper's fixed 2 MiB receive
  window.
- Raw host key bytes and negotiated method names are available through public
  session APIs.
- Custom transport still requires a valid dummy descriptor during public
  handshake because `session_startup` validates and changes descriptor flags
  before using callbacks. A private, promptly released socketpair can satisfy
  this and must be included in resource-baseline accounting; it does not replace
  or bypass the injected TCP connection.

## Rejected forced fits

1. Count any public-operation EAGAIN burst as server rekey. EAGAIN is used for
   ordinary socket backpressure and provides no reason or completion boundary.
2. Parse trace strings. Trace is build-optional diagnostic text, not a stable
   callback contract, and does not provide a safe production generation model.
3. Treat `libssh2_keepalive_send == 0` as acknowledgement. It means only that
   the function accepted/queued the request or that the interval was not due.
4. Infer liveness from unrelated channel traffic. The reviewed contract
   explicitly separates SSH keepalive replies from application traffic.
5. Implement the rest against a fake engine and mark these paths supported.
   That would make tests avoid the exact production limitation and mask red
   gates.
6. Extend the already accepted fork in this adapter task. The task authorizes
   no additional libssh2 patch without a separate recorded decision and review.

## Viable options

1. **Authorize a second minimal fork extension (recommended if the candidate is
   still desired).** Expose typed server-KEX start/success/failure observation
   and a nonblocking, reply-correlated generic global request or keepalive
   operation. Keep the delta allowlisted, checksum-locked, rebased, and proven
   against server-initiated KEX plus success/failure/timeout keepalive fixtures.
   This preserves the common contract but adds maintenance surface.
2. **Fail the libssh2 candidate red.** Record E-REKEY server observability and
   E-KEEPALIVE as mandatory red rows, withdraw this adapter from conforming
   harness registration, and continue ADR-014 with the remaining candidate.
   This adds no fork maintenance.
3. **Revise the common contract.** Make server-KEX observability/generation and
   reply-confirmed keepalive optional or redefine their semantics. This weakens
   accepted security/liveness evidence and requires explicit architecture and
   security approval.
4. **Move to an upstream pin providing both APIs.** Re-run the full source,
   security, license, packaging, and capability audit. No such API exists at
   the required pin.

## Recommendation and exact input needed

Recommend option 1 only if keeping libssh2 in the candidate matrix justifies a
second maintained patch; otherwise option 2 is cleaner.

To resume implementation, provide one reviewed decision:

- authorize a separately owned minimal fork task with the two exact public
  seams above and make it a dependency of this adapter; or
- declare libssh2 failed/red for mandatory server-rekey observability and
  reply-confirmed keepalive; or
- approve the precise common-contract revision.

Until then, no production adapter or mock-only conformance tests should be
added.
