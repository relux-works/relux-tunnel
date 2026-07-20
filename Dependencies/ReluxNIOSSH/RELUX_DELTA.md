# ReluxNIOSSH delta

## Scope

The fork changes only the two audited capability gaps required by the SSH
transport contract:

1. configurable, capped, observable per-child-channel receive windows;
2. supported client rekey requests plus optional automatic protected-byte and
   monotonic elapsed-time thresholds.

The `NIOSSH` product and module name remain unchanged for source compatibility.
The package identity changes to `ReluxNIOSSH`. Existing callers that do not set a
window option or rekey policy retain the upstream 16 MiB receive window,
half-window adjustment trigger, and disabled automatic client rekey.

No cipher, MAC, KEX, host-key, authentication, packet format, or server rekey
algorithm was added, removed, or reordered.

## Logical patch and commit inventory

The repository workflow deliberately leaves commits to the human reviewer. The
recommended focused commit sequence is:

| Patch | Purpose | Files |
| --- | --- | --- |
| `0001-relux-package-provenance` | Rename only the SwiftPM package identity, track and lock the audited resolved graph, and record the pin/license. | `.gitignore`, `Package.swift`, `Package.resolved`, `UPSTREAM.md`, `NOTICE-RELUX.txt` |
| `0002-configurable-child-receive-window` | Add immutable window policy, pre-open channel option, snapshots, adjustment events, cap accounting, and upstream-compatible default. | `ReluxPolicies.swift`, `ChildChannelOptions.swift`, `ChildChannelWindowManager.swift`, `SSHChildChannel.swift` |
| `0003-supported-automatic-rekey` | Add manual production-path request, byte/time policy, injected monotonic clock, safe coalescing, generation/counters, events, and server-trigger observation around the existing KEX state machine. | `ReluxPolicies.swift`, `NIOSSHHandler.swift`, `SSHConnectionStateMachine.swift` |
| `0004-relux-policy-tests-and-maintenance` | Add deterministic Swift Testing coverage and fork comparison/rebase documentation. | `ReluxPolicyTests.swift`, `EndToEndTests.swift`, `PATCH_MANIFEST.json`, `RELUX_DELTA.md`, `REBASE.md` |

`PATCH_MANIFEST.json` is the machine-readable authority for the exact changed
file allowlist. `make check-reluxniossh` downloads the pinned archive, verifies
both hashes, and fails if any delta exists outside that allowlist.

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

Submit two independent upstream proposals so either capability can be reviewed
without adopting Relux policy:

1. receive-window proposal: child-channel option, immutable cap, snapshot, and
   adjustment event, retaining the current default;
2. rekey proposal: safe public request/coalescing first, followed by optional
   byte/time policy and monotonic-clock seam if upstream accepts policy in the
   engine rather than its caller.

Keep Relux naming out of proposed upstream API. Split tests by proposal and
retain the existing upstream XCTest suite while offering the new Swift Testing
coverage. Drop each fork patch after an equivalent released upstream API is
adopted and the shared SSH conformance suite passes unchanged.
