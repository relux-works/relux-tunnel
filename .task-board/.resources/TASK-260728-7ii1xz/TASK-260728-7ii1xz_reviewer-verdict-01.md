# TASK-260728-7ii1xz — reviewer verdict 01

Verdict: **changes requested → analysis**.

The selected transport remains technically plausible: a root-context macOS
packet-tunnel provider owns a file-based System-keychain item, and the
user-context host supplies the secret over the Network Extension app-message
channel. The artifact compares five candidates across every AC2 dimension,
states the two Apple-sourced premise facts, records privacy-safe physical
evidence and its limitations, gives a provider entitlement verdict, and maps all
five named downstream tasks.

Acceptance is withheld because the contract and downstream mapping contain one
material lifecycle error and two precision defects.

## F1 — provider-stopped revocation is incorrectly declared asynchronous

Artifact §§5.1 and 8 say the user-context app cannot delete a provider-owned
System-keychain item while the provider is stopped, so revocation must be
eventually reconciled by a future provider-start sweep. That conclusion
conflicts with Apple's current `NETunnelProviderSession.sendProviderMessage`
contract:

> "If the extension is not running, it should be launched to handle the
> message."

Source:
<https://developer.apple.com/documentation/networkextension/netunnelprovidersession/sendprovidermessage(_:responsehandler:)>

The same API chosen for seeding can therefore launch the provider to handle a
bounded `RevokeCredential(ref)` message without first establishing the tunnel.
The artifact must re-evaluate and test/design the lifecycle before declaring
synchronous deletion impossible. At minimum it must distinguish:

1. installed/enabled provider not currently running, where app-message launch
   is documented;
2. disabled, unapproved, missing, or failed provider, where synchronous
   revocation may genuinely be unavailable;
3. host absent, where no app-originated revoke can occur.

This correction must flow into `TASK-260715-379cpk`,
`TASK-260715-29ws8l`, and `TASK-260715-2hhh7x`. It should also reconsider
pre-seeding before `startTunnel` instead of making the first connect wait in an
`awaitingCredential` state under the 60-second startup budget. Preserve a
start-time reconciliation sweep as crash-recovery defense if desired, but do
not present it as the only possible deletion path.

## F2 — the transport contract hard-codes a deprecated System-keychain path

Artifact §5.1 requires an explicit `kSecUseKeychain` reference pointing at
`/Library/Keychains/System.keychain`. Apple DTS explicitly advises not to hard
code that path and recommends resolving the system-domain keychain with
`SecKeychainCopyDomainDefault` or `SecKeychainCopyDomainSearchList`.

Sources:

- <https://developer.apple.com/forums/thread/738542>
- <https://developer.apple.com/forums/thread/704034>

Revise the contract to resolve the system-domain keychain through the supported
system-domain API available to this file-based-keychain compatibility path.
Retain an explicit `kSecUseKeychain` in each query so the provider never relies
on a mutable search list. Record that the whole file-based `SecKeychain` /
`SecAccess` path is deprecated but remains Apple's documented daemon option;
keep physical V1 as the release gate.

## F3 — the exact ypo7yo row amendment is incomplete

The verdict correctly says:

- target: `works.relux.tunnel.mac.tunnel`;
- `keychain-access-groups`: `prohibited-pending-decision` → `prohibited`;
- no value, no portal capability, no provider keychain entitlement;
- applying owner: `TASK-260715-ypo7yo`.

However, the current matrix row also contains:

- `resolutionOwner: "TASK-260728-7ii1xz"`; and
- an `amendmentRule` saying that direct provider keychain access changes the
  row to `required` with the shared group literal.

The selected transport does give the provider direct keychain access, but the
file-based keychain does not use access groups. Leaving those fields unchanged
would preserve a contradictory reopening rule on a settled row. The amendment
packet must explicitly instruct ypo7yo to remove the now-resolved
`resolutionOwner` and replace/remove that stale `amendmentRule`, in addition to
updating status, rationale, OC-1, revision, and revision log.

## Evidence and gates

| gate | observed result |
| --- | --- |
| `swift test` | exit 0; 335 tests in 29 suites passed |
| `swiftc -O .../TASK-260728-7ii1xz_kcprobe.swift` | exit 0 |
| `zsh .../TASK-260728-7ii1xz_collect-evidence.sh` | exit 0; reproduced uid-0 shipping sysex, entitlement metadata, sandbox rules, and file modes; intended root-container `ls` step recorded exit 1 |
| `task-board validate` while leaf is `reviewing` | process exit 0 but reported `PARENT_STATUS_MISMATCH` because hard-blocked parent `STORY-260715-2wjwuf` remained `analysis` while child aggregate was `reviewing`; rerun after verdict routing |

The physical evidence remains privacy-safe. No secret value was read, written,
or printed by this review.

## Required rework

1. Correct the app-message launch/revocation lifecycle and all affected
   downstream assumptions.
2. Replace the hard-coded System-keychain path with system-domain resolution.
3. Make the ypo7yo amendment exhaustive over the row's stale decision fields.
4. Correct the matching `LOGBOOK.md` claims and refresh
   `TASK-260728-7ii1xz_results.md`.
5. Re-run the existing gates and hand off for a new independent review.
