# TASK-260715-1rsqrh accepted inputs

Implement host-side VPN session control and truthful status projection against the already accepted lifecycle, runtime-codec, manager-repository, and provider-message contracts.

Authoritative inputs:

- `TASK-260715-1q4qhw_runtime-lifecycle-contract.md`, especially sections 5 and 7, plus its accepted review.
- Accepted `TASK-260715-lovbdz` versioned runtime request/response models, codecs, size bounds, and fail-safe projection rules.
- Accepted `TASK-260715-15vkvz` owned-manager repository. Every command must use a freshly reloaded exact-owned current manager/session; do not duplicate persistence or ownership logic.
- Accepted `TASK-260715-1bp6eu` read-only provider message routing and once-only provider response semantics.
- The task description, scope, and AC are normative.

Execution constraints:

- `NETunnelProviderSession.status` is sole system-session authority. Provider snapshots are sole capability/runtime authority. Never synthesize either from app memory or the other authority.
- Start options contain exactly the bounded v1 start request matching the stored opaque configuration reference; no secrets or free-form options.
- Preserve the accepted deadlines using injectable monotonic time: 60 seconds to connect, 15 seconds to observe disconnect, 3 seconds for read-only provider messages and last-disconnect-error fetches.
- Start/stop/message work must be generation-retired, cancellation-safe, exactly-once, observer-leak-free, and deterministic across callback/notification orderings. Cancellation after accepted start issues stop once; controller/app retirement never stops the system tunnel merely because the host went away.
- Every non-connected system state clears capability. Connected with missing, stale, unsupported, corrupt, timed-out, nil, wrong-request, or out-of-order provider facts stays capability-unknown.
- Map all public `NEVPNConnectionError` cases, provider domain codes 1001-1009, unknown/provider/nil errors exactly as the accepted lifecycle contract specifies. Disconnect reason supplements but never overrides system status.
- Keep implementation shared and injectable; iOS/macOS adapters are thin public-NetworkExtension translations. Do not couple to provisioning, signed workspace execution, UI, analytics, auto-reconnect, UDP implementation, or app-owned forwarding state.
- Add deterministic tests for all AC rows, including relaunch recovery, every status, start/stop races, initial-read/registration races, timeouts/cancellation, late callbacks, observer/task release, protocol/schema/generation/sequence freshness, and nil/late provider responses. Run focused normal and TSan tests, full core/boundary validation, strict formatting/diff/board checks, and both platform adapter builds.
- Work through producer handoff to `to-review`; do not self-accept.
