# TASK-260715-nzdzv3 — Review verdict: ACCEPTED

Reviewer: reviewer (claude), run RUN-260720-6f9cdd, 2026-07-20.

## Verdict

Accepted → `done`. All five acceptance criteria are met; all validation gates were
independently re-executed by the reviewer, not taken from implementer logs.

## Acceptance criteria

1. **Exact pin, traceable patches — PASS.** `make check-reluxniossh` (fork-tool
   `verify`) re-downloaded the pinned archive
   `31cdc3c3391a10460dedf1170530cf651d2ca496` (tag 0.14.1), reproduced archive
   SHA-256 `0b135087…d06e6a` and LICENSE SHA-256 `cfc7749b…23d30`, and confirmed
   the delta is exactly the 16-file allowlist in `PATCH_MANIFEST.json`. Every
   hunk of the attached unified patch was read; each maps to one of: package
   provenance (`Package.swift` name, `.gitignore` un-ignoring `Package.resolved`),
   configurable child windows, supported automatic rekey, or tests/docs for those
   behaviors. No crypto, algorithm, packet-format, or unrelated engine change.
2. **Test matrix — PASS.** Parameterized 32 KiB / 64 KiB / 512 KiB-in-1 MiB-cap
   initial-window-on-wire tests; adjustment suppression (unread bytes withhold
   credit + `nil` threshold suppresses); outbound and inbound protected-byte
   thresholds; elapsed-time threshold with injected fake monotonic clock;
   simultaneous byte+time thresholds coalescing into one KEX with a merged reason
   set; concurrent explicit `requestRekey` promises resolving on one shared KEX;
   active channels during rekey with byte-exact payload preservation;
   server-initiated rekey observed via started/succeeded events. 10/10 pass
   deterministically (no sleeps; embedded channels + injected clock).
3. **Source compatibility — PASS.** New `NIOSSHHandler` init parameters are
   defaulted (`.disabled` policy, system clock); legacy
   `ChildChannelWindowManager(targetWindowSize:)` maps to a configuration whose
   adjust math is equivalent to upstream's half-window rule for even window sizes
   (upstream default `1<<24` is even; verified analytically). All 323 unmodified
   upstream XCTest cases pass; the only upstream test-file change adds defaulted
   harness parameters.
4. **Maintenance artifacts — PASS.** Patch manifest (machine-readable,
   fail-closed via `make check-reluxniossh`), license/provenance review +
   `NOTICE-RELUX.txt`, full unified upstream diff (attached, SHA-256 verified),
   rebase procedure with stop-the-line rule, working `conflict-test` command
   (re-run at the pin, exit 0), and a two-proposal upstreaming plan.
5. **No fragile access — PASS.** `_rekey()` now delegates into the production
   `startOrCoalesceRekey` path; no reflection or test-only symbol use anywhere;
   root product code has no NIOSSH reference at all (adapter task 1af33i will be
   the first consumer).

## Reviewer-executed gates

| Gate | Result |
| --- | --- |
| `make validate-reluxniossh` (verify + 323 XCTest + 10 Swift Testing + build) | exit 0 |
| `swift format lint` on `ReluxPolicies.swift`, `ReluxPolicyTests.swift`, `Package.swift` | exit 0 |
| `python3 scripts/reluxniossh-fork-tool.py conflict-test --upstream-ref 31cdc3c…` | exit 0 |
| `make validate-core` (boundaries + 49 tests + root build) | exit 0 |

## Correctness review (beyond AC)

- Protected-byte boundary matches contract §10.1: outbound counted after SSH
  packet encoding, before `context.write` (`NIOSSHHandler.swift:266`); inbound
  counted after socket read, before decode (`NIOSSHHandler.swift:205`). All
  outbound frames flow through the single `writeMessage` path; the directly
  written client KEXINIT is separately counted. Counters gate on
  `keyExchangeGeneration > 0`, so only protected traffic counts and auth traffic
  (post-NEWKEYS) is correctly included.
- Window-manager invariant: `remaining + buffered + deliveredUnadjusted ==
  initialWindowSize` at all times, so `remainingBefore + adjustment ≤ cap` holds
  unconditionally and an advertised window is never revoked. Credit is earned
  only after pipeline delivery (`fireChannelRead` precedes `unbufferBytes` in
  `deliverSingleRead`), and the adjustment event fires after delivery — matching
  contract §9.
- KEX transition detection brackets both the inbound processing loop and each
  outbound message, so client-triggered, server-triggered, and coalesced KEX all
  produce one started event, one succeeded event, counter reset, generation
  increment, and promise resolution. The rekey timer is cancelled on
  `handlerRemoved` and pending promises fail with `eof` — no leak or hang path
  found.

## Non-blocking findings (recorded in LOGBOOK 2026-07-20 0908)

1. **Adapter must gate writes during KEX.** Upstream's state machine rejects
   outbound `channelData` during any KEX with `protocolViolation`
   (`SSHConnectionStateMachine.swift:1060-1076`), failing the child write
   promise. Pre-existing upstream behavior, out of minimal-fork scope, but
   automatic byte/time rekey makes the collision likely under bulk traffic —
   exactly the tunnel workload. TASK-260715-1af33i must queue/gate child writes
   using `rekeySnapshot.keyExchangeInProgress` and the started/succeeded events
   the fork now exposes.
2. **Threshold footgun.** `windowAdjustmentThreshold` is only validated against
   `maximumWindowSize`; a value above `initialWindowSize` can never trigger
   (delivered credit is bounded by the initial window), permanently withholding
   WINDOW_ADJUST. Likewise remaining credit never grows beyond
   `initialWindowSize` even with a larger cap. Adapter policy must keep
   threshold ≤ initial.
3. Cosmetic: `.serverInitiated` means "remote-initiated"; `requestRekey` in a
   non-active state fails the promise and also fires `errorCaught`.

Deep functional/rekey/scale matrices (5 GiB transfer, E-WINDOW/E-REKEY rows)
remain owned by TASK-260715-3ikonq per the task inputs; nothing here pre-empts
them.
