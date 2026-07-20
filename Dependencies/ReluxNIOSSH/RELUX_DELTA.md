# ReluxNIOSSH delta

## Scope

The fork changes only the five audited capability gaps required by the SSH
transport contract:

1. configurable, capped, observable per-child-channel receive windows;
2. supported client rekey requests plus optional automatic protected-byte and
   monotonic elapsed-time thresholds;
3. public-key authentication backed by an asynchronous external signer that
   receives NIOSSH's constructed payload and never receives a private key;
4. bounded reply-observing global requests through NIOSSH's protected packet
   and ordered response path;
5. client KEX/host-key allowlists and an immutable exact negotiated-algorithm
   snapshot.

The `NIOSSH` product and module name remain unchanged for source compatibility.
The package identity changes to `ReluxNIOSSH`. Existing callers that do not set a
window option or rekey policy retain the upstream 16 MiB receive window,
half-window adjustment trigger, and disabled automatic client rekey.

No cipher, MAC, KEX, host-key, authentication, packet format, or server rekey
algorithm implementation was added or changed. Caller allowlists only filter
and order the algorithms already implemented by the pinned upstream source.

## Logical patch and commit inventory

The repository workflow deliberately leaves commits to the human reviewer. The
recommended focused commit sequence is:

| Patch | Purpose | Files |
| --- | --- | --- |
| `0001-relux-package-provenance` | Rename only the SwiftPM package identity, track and lock the audited resolved graph, and record the pin/license. | `.gitignore`, `Package.swift`, `Package.resolved`, `UPSTREAM.md`, `NOTICE-RELUX.txt` |
| `0002-configurable-child-receive-window` | Add immutable window policy, pre-open channel option, snapshots, adjustment events, cap accounting, and upstream-compatible default. | `ReluxPolicies.swift`, `ChildChannelOptions.swift`, `ChildChannelWindowManager.swift`, `SSHChildChannel.swift` |
| `0003-supported-automatic-rekey` | Add manual production-path request, byte/time policy, injected monotonic clock, safe coalescing, generation/counters, events, and server-trigger observation around the existing KEX state machine. | `ReluxPolicies.swift`, `NIOSSHHandler.swift`, `SSHConnectionStateMachine.swift` |
| `0004-adapter-conformance-public-apis` | Add external async signing, reply-observing bounded global requests, client KEX/host-key allowlists, and exact negotiation snapshots without changing packet protection or crypto implementations. | `ReluxPolicies.swift`, `UserAuthenticationMethod.swift`, `UserAuthenticationStateMachine.swift`, `NIOSSHHandler.swift`, `SSHClientConfiguration.swift`, `SSHKeyExchangeStateMachine.swift`, `SSHConnectionStateMachine.swift` |
| `0005-relux-policy-tests-and-maintenance` | Add deterministic Swift Testing coverage and fork comparison/rebase documentation. | `ReluxPolicyTests.swift`, `EndToEndTests.swift`, `PATCH_MANIFEST.json`, `RELUX_DELTA.md`, `REBASE.md` |

`PATCH_MANIFEST.json` is the machine-readable authority for the exact changed
file allowlist. The adapter-conformance extension grows the audited delta from
16 to 20 files: four newly patched upstream files and no new fork-only files.
`make check-reluxniossh` downloads the pinned archive, verifies both hashes, and
fails if any delta exists outside that allowlist.

## Public API delta

- `SSHChildChannelOptions.receiveWindowConfiguration` sets policy only before
  the local open/confirmation advertises receive credit.
- `SSHChildChannelOptions.receiveWindowSnapshot` reports initial value, cap,
  remaining protocol credit, unread bytes, delivered/unreturned credit, and
  adjustment totals.
- `NIOSSHChannelWindowAdjustedEvent` reports each adjustment without payload or
  endpoint data.
- `NIOSSHHandler` accepts optional `NIOSSHRekeyPolicy` and
  `NIOSSHRekeyClock` initializer arguments, both with upstream-compatible
  defaults.
- `NIOSSHHandler.requestRekey(reason:promise:)` is the supported production
  request path. Concurrent requests share the active KEX and their promises
  resolve together.
- `NIOSSHHandler.rekeySnapshot`, `NIOSSHRekeyStartedEvent`, and
  `NIOSSHRekeySucceededEvent` expose common state without reflection or access
  to the internal test-only `_rekey()` symbol.
- `NIOSSHUserAuthenticationOffer.Offer.externalPublicKey` accepts an SSH
  wire-format public key, its algorithm, and an asynchronous raw-signature
  callback over NIOSSH's complete RFC 4252 payload. It stores no private key.
- `NIOSSHHandler.sendGlobalRequest(_:promise:)` sends a bounded request with
  `want-reply` through the existing encrypted/MACed write queue and resolves an
  ordered success/failure response for RTT measurement.
- `SSHClientConfiguration.keyExchangeAlgorithms` and `hostKeyAlgorithms`
  restrict the already-bundled client algorithms; `nil` retains upstream
  defaults while empty/unsupported policies fail closed.
- `NIOSSHHandler.negotiatedAlgorithmsSnapshot` exposes the exact selected KEX,
  host-key, cipher, and MAC strings from `NegotiationResult`, never configured
  lists.

## Upstream comparison

Generate the exact unified source diff from the audited pin:

```sh
python3 scripts/reluxniossh-fork-tool.py diff \
  --output .temp/TASK-260715-nzdzv3/ReluxNIOSSH-upstream.patch
```

All additions are confined to the paths and logical patches above. The full
generated patch is attached to board task `TASK-260715-nzdzv3` as an outcome
resource; it is not duplicated inside the source package.

## Candidate upstreaming plan

Submit independent upstream proposals so each capability can be reviewed
without adopting Relux policy:

1. receive-window proposal: child-channel option, immutable cap, snapshot, and
   adjustment event, retaining the current default;
2. rekey proposal: safe public request/coalescing first, followed by optional
   byte/time policy and monotonic-clock seam if upstream accepts policy in the
   engine rather than its caller;
3. external-signer proposal: wire public key plus future-based signer offer;
4. generic global-request proposal: bounded request value plus ordered reply;
5. negotiation proposal: client algorithm filters plus exact result event.

Keep Relux naming out of proposed upstream API. Split tests by proposal and
retain the existing upstream XCTest suite while offering the new Swift Testing
coverage. Drop each fork patch after an equivalent released upstream API is
adopted and the shared SSH conformance suite passes unchanged.
