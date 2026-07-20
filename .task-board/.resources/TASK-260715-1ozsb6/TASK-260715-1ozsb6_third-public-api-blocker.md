# TASK-260715-1ozsb6 — third libssh2 public-API stop-line

## Decision boundary

The accepted libssh2 fork now exposes client rekey, typed server-KEX
observation, and a reply-correlated global request. During adapter design
against that exact public artifact, three additional mandatory contract
results remain impossible to implement without another fork extension:

1. consumer-driven receive-window credit with an immutable advertised cap;
2. candidate-neutral channel-open rejection reason categories; and
3. exact exec exit metadata (`status(0)` versus `notReported`, plus the
   `coreDumped` bit for exit signals).

The prerequisite TASK-260720-2sltje explicitly says a third blocker round must
escalate the M0-versus-M3 scope decision. TASK-260715-1ozsb6 also requires a
stop-line result instead of private-symbol calls, message parsing, or mock-only
conformance.

## Exact artifact and source evidence

Inspected the accepted static XCFramework built from libssh2 commit
`a34302491c164d53c900fec9b3cbb050ecebe719`, OpenSSL `3.5.7`, and the single
allowlisted six-file patch accepted by TASK-260720-2sltje.

- macOS public header SHA-256:
  `aa542cff4e0e64927983da8c50b0315cd24c6d097fcdd42809d2e3b0878625bf`
- fork patch SHA-256:
  `79e2464813e3c3add9486b2fb8c9e50004b48b246bbc771b5dd1675a152fa30e`
- `Dependencies/ReluxLibSSH2/PATCH_MANIFEST.json` permits exactly six changed
  files and exports only the four rekey/KEX/global-request symbols. It does not
  expose channel window mode, open-failure metadata, or typed exec-exit
  metadata.

### 1. Reads silently return receive credit before consumer delivery

Pinned patched `src/channel.c:1903-1904` says the user maintains the receive
window, but `ssh2_channel_read` contradicts that statement at
`src/channel.c:1921-1938`: before copying any channel bytes to the caller it
automatically computes an adjustment when remaining credit is below
`initial * 3/4 + requestedReadLength`, clamps it to at least
`LIBSSH2_CHANNEL_MINADJUST`, and calls the private
`ssh2_channel_receive_window_adjust`.

This violates contract section 9 in two independent ways:

- credit is returned on engine read entry, before `SSHByteChannel.read`
  delivers bytes to the consumer;
- the engine computes `initial + requestedReadLength - remaining`, so when the
  immutable cap equals the initial window it can advertise beyond that cap.

The public header offers `libssh2_channel_read_ex`, window inspection, and an
explicit adjust call, but no manual-window mode and no read operation that
suppresses the automatic adjustment. The adapter cannot undo a window already
advertised on the wire.

### 2. Channel-open failure categories are collapsed

Pinned patched `src/channel.c:259-289` parses the exact RFC 4254 reason code and
recognizes administratively prohibited, connect failed, unknown channel type,
and resource shortage. Every branch is then mapped to the same public
`LIBSSH2_ERROR_CHANNEL_FAILURE`. The numeric reason and packet are freed before
`libssh2_channel_open_ex` returns `NULL`.

No public accessor returns the parsed reason. The only remaining distinction is
candidate-owned diagnostic text in `libssh2_session_last_error`. Parsing that
free-form English string would be a version-fragile forced fit and would make
diagnostic text part of control flow, contrary to the common typed error
contract.

Therefore the adapter cannot populate `SSHTransportError.channelOpenReason`
reliably as required by section 7.1 and E-ERRORS.

### 3. Exec exit metadata loses required information

Pinned patched `src/libssh2_priv.h:452-468` stores only an integer
`exit_status` initialized to zero and an optional signal-name pointer. It has no
`exitStatusWasReceived` flag and no `coreDumped` field.

- `src/packet.c:1106-1128` overwrites `exit_status` when an `exit-status`
  request arrives. An explicit status `0` therefore has the same state as no
  exit-status request.
- `src/channel.c:1645-1650` simply returns that integer. The public API cannot
  distinguish `.status(0)` from `.notReported` after remote close.
- RFC 4254 `exit-signal` contains a boolean `core dumped` field after the signal
  name. `src/packet.c:1130-1173` reads only the signal name and discards the
  remainder. `libssh2_channel_get_exit_signal` exposes no core-dump output.

Thus `SSHExecExit.status(0)`, `.notReported`, and
`.signal(SSHExecSignal(coreDumped:))` cannot be represented truthfully through
the accepted public fork.

## Confirmed seams that are not blockers

- Custom send/receive callbacks can bridge the injected asynchronous
  `SSHTCPConnection` with bounded synchronous buffers and EAGAIN readiness
  pumping.
- The public-key sign callback accepts `LIBSSH2_ERROR_EAGAIN`, so the adapter
  can copy the signing payload, await the injected external signer, and resume
  without exporting private-key material.
- Generic `libssh2_channel_open_ex` can encode `direct-tcpip` with the caller's
  initial window, avoiding the helper's fixed 2 MiB default.
- The accepted fork now covers client rekey, server-KEX lifecycle/generation,
  and reply-correlated keepalive. Built-in want-reply keepalive must remain
  disabled so unnumbered global replies cannot be miscorrelated.
- Raw host-key bytes and exact negotiated method names are public.

## Rejected forced fits

1. Track delivered bytes in Swift while accepting libssh2's automatic adjust.
   The peer has already received credit, so a Swift counter cannot restore the
   protocol invariant or cap.
2. Avoid reads near libssh2's threshold. This eventually deadlocks or requires
   deliberately never delivering pending data; it does not provide consumer
   semantics.
3. Parse `libssh2_session_last_error` strings to recover channel-open reasons.
   Diagnostic prose is not a stable typed API and may change or be localized.
4. Interpret exit status `0` as always reported or always absent. Either choice
   makes one mandatory result false.
5. Hardcode `coreDumped: false`. That fabricates a value the engine discarded.
6. Add adapter tests that avoid zero/absent exit, core-dump signals, low-window
   reads, or rejection categories. Those tests would mask the exact production
   incompatibility.
7. Patch libssh2 inside this adapter task. The maintained fork delta is a
   separately reviewed supply-chain boundary; expanding it opportunistically
   violates ADR-019 and the task's no-forced-patch rule.

## Viable options and tradeoffs

1. **Fail the libssh2 candidate at M0 (recommended unless its independent value
   justifies more fork maintenance).** Record E-WINDOW, E-CHANNELS, and E-ERRORS
   red, withdraw conforming harness registration, and continue ADR-014 with the
   remaining candidate. This is the smallest security and rebase surface.
2. **Authorize one third, consolidated fork extension.** Preserve upstream
   defaults but add reviewed public APIs for:
   - per-channel manual receive-window mode that suppresses implicit adjustment;
   - typed last/open failure reason retrieval; and
   - typed exec-exit metadata with status-presence, signal, and core-dump flag.
   The patch needs deterministic wire tests for withheld/consumer-earned credit
   and immutable caps, all RFC open reasons, explicit status zero versus absent,
   and exit-signal core true/false. The allowlist, rebase policy, checksums,
   headers, XCFramework, and Apple matrix must be reviewed again.
3. **Move these clauses from M0 to M3 or revise the common contract.** This
   reduces immediate fork work but weakens the already accepted symmetric
   selection gates. It requires explicit architecture/security approval and a
   contract revision before adapter code.
4. **Move to a future upstream release with equivalent public APIs.** Re-run the
   complete source, security, license, packaging, and capability audit. The
   required APIs are absent at the pinned source.

## Exact decision needed to resume

Choose one explicit direction:

- declare libssh2 failed/red for M0 on the three gaps above;
- authorize and review the consolidated third fork extension with the exact
  three public seams and tests listed above; or
- approve the precise M0-to-M3/common-contract revision.

Do not resume adapter implementation against the current public artifact. A
partial implementation would necessarily hide at least one mandatory red gate.

## Verification performed in this run

Read-only source/header/symbol inspection and SHA-256 reproduction were run.
No product code or package graph was changed after the stop-line finding.
Adapter tests, Swift builds, and Apple provider/harness builds were not run
because no conforming adapter can be implemented against the current public
surface; running unchanged baseline builds would not resolve this API/contract
conflict.
