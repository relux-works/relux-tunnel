# TASK-260715-1ozsb6 — libssh2 client-rekey stop-line evidence

## Constraint

The reviewed common `SSHTransport` contract requires byte-threshold,
time-threshold, and explicit client-initiated rekey through the same production
path. Rekey failure or timeout is connection-fatal, and the adapter must expose
the public `requestRekey(reason:)` behavior without candidate-private types.

The task explicitly excludes patching libssh2 without a separate recorded
decision and requires work to stop when a contract clause cannot be satisfied by
the pinned public API.

## Reproduced evidence at the exact pin

- Downloaded the exact libssh2 source archive for commit
  `a34302491c164d53c900fec9b3cbb050ecebe719`.
- Recomputed SHA-256:
  `744ba3e9a8e7a877038e94a74459340052a105ad599605a5b6d0d6bc5ec2c87c`,
  matching the accepted candidate audit.
- `include/libssh2.h` exports `libssh2_session_handshake`, but exports no rekey
  or key-reexchange operation.
- `src/session.c` calls `ssh2_kex_exchange(session, 0, ...)` only from the
  initial startup state. Calling the public handshake again cannot request a
  reexchange and is not a client-rekey API.
- `src/packet.c` handles inbound `SSH_MSG_KEXINIT` by calling
  `ssh2_kex_exchange(session, 1, ...)`, proving server-initiated rekey exists.
- `ssh2_kex_exchange` is declared only in private `src/libssh2_priv.h` and
  defined in `src/kex.c`; it is absent from the public header.

This independently reproduces the accepted TASK-260715-28ok1k audit finding.

## Failed assumption and rejected workarounds

The adapter can count protected bytes and schedule elapsed-time triggers, but it
has no supported engine operation to start the required KEX. Scheduling alone
therefore cannot implement the contract.

Rejected approaches:

1. Call private `ssh2_kex_exchange` from the adapter. This binds product code to
   an unexported private header/symbol and violates the named public boundary.
2. Patch/export the private function inside this task. The task explicitly
   forbids such a forced pass without a separate reviewed decision.
3. Call `libssh2_session_handshake` again. Its implementation uses
   `reexchange=0` and the completed startup state; it does not express client
   rekey.
4. Return success from `requestRekey` while only resetting counters, or wait for
   a server KEX. Either silently weakens the mandatory cryptographic behavior.
5. Implement all other adapter features and mark only rekey unsupported. The
   supplied task instruction says a genuinely unsatisfied contract clause is a
   stop-the-line boundary; a partial adapter would misleadingly resemble a
   conforming candidate.

## Impact

Acceptance criterion 4 cannot be satisfied at the pinned, unmodified libssh2
public API. Consequently the adapter cannot conform to `SSHTransport`, and the
requested E-REKEY client byte/time/explicit rows must be red. Packaging,
provider/harness builds, and the remaining adapter implementation were not
started after this stop-line finding.

## Viable options

1. **Fail the libssh2 candidate at this pin (recommended).** Record E-REKEY as
   red, withdraw the adapter from conformance/harness registration, and keep
   ADR-014 selection based on the remaining conforming candidate. This has the
   smallest maintenance and private-API risk.
2. **Authorize a separately audited minimal libssh2 fork.** Add a supported
   public nonblocking rekey API around the existing internal state machine, pin
   and checksum the fork delta, define upstream/rebase policy, and test
   EAGAIN/cancellation/coalescing/active-channel behavior. This retains the
   candidate but creates a C fork and supply-chain maintenance obligation.
3. **Move to a future upstream pin with a public rekey API.** Re-run the source,
   security, license, build, and capability audit before adapter work. No such
   API exists at the required pin, so this depends on external upstream state.
4. **Revise the common contract to make client rekey optional.** This would
   weaken an accepted mandatory security gate and is not recommended without an
   explicit product/security architecture decision.

## Exact decision needed to resume

Choose one of these directions:

- accept the libssh2 candidate as failed/red at commit `a343024...` and stop its
  adapter implementation; or
- authorize a separate fork/pin decision task that may expose and maintain a
  public client-rekey API (or provide an audited upstream replacement pin).

Do not resume adapter code under the current unmodified-pin and mandatory-rekey
constraints.
