# TASK-260715-1q4qhw — system VPN configuration and lifecycle contract

Status: autonomous draft for agent review  
Scope: shared host contract plus thin iOS/macOS Packet Tunnel Provider adapters; macOS-first v1  
Normative language: MUST, MUST NOT, SHOULD, and MAY are binding in this document.

## 1. Accepted inputs and authority

This contract consumes the accepted runtime ownership contract from
`TASK-260715-30zng6`, the accepted runtime models and coordinator on `main`
through commit `54bcc5e`, and the accepted deployment floors iOS 18.0/macOS
15.0 from `TASK-260715-3r0993`. It does not reopen packet, SSH, DNS, routing,
reconnect, fail-closed, product-copy, signing, or release decisions.

Authority is deliberately split:

| Fact/action | Sole authority | Consequence |
|---|---|---|
| persisted VPN configuration | freshly loaded `NETunnelProviderManager` owned by the current containing app | cached managers are never treated as current after save, external change, timeout, or cancellation |
| system session state and system VPN indicator | `NETunnelProviderSession.status` plus `NEVPNStatusDidChange` | app memory and provider snapshots cannot synthesize connected/disconnected |
| runtime lifecycle, health, routes, and TCP/DNS/UDP capability | current provider `RuntimeLifecycleSnapshot` / `RuntimeCapabilitySnapshot` | `.connected` alone never means full or degraded capability |
| live forwarding and resource cleanup | extension-owned `TunnelProviderAdapter` and `TunnelRuntimeCoordinator` generation | containing-app suspension, quit, or termination has no teardown role |
| preference permission/authorization | NetworkExtension and the OS | the app reports the returned result and never claims permission before a successful save/reload |

Both containing apps implement the same contract. Each app has its own
app-scoped NetworkExtension preference view and owns at most one configuration
for its platform provider. There is no cross-platform shared manager object.

## 2. Identifier and entitlement binding

The following symbols are required production inputs:

| Symbol | Meaning | Authoritative owner |
|---|---|---|
| `iosHostBundleID` / `iosProviderBundleID` | iOS containing app and embedded Packet Tunnel Provider IDs | accepted output of `TASK-260715-ypo7yo` |
| `macHostBundleID` / `macProviderBundleID` | macOS containing app and embedded Packet Tunnel Provider IDs | accepted output of `TASK-260715-ypo7yo` |
| `appGroupID(platform)` | non-secret profile/configuration sharing group | accepted output of `TASK-260715-ypo7yo` |
| `keychainAccessGroup(platform)` | opaque credential-reference target shared only as approved | accepted output of `TASK-260715-ypo7yo` |
| `networkExtensionEntitlements(target)` | least-privilege provider capability/entitlement values and placement for each target/signing mode | accepted outputs of `TASK-260715-ypo7yo` and, for macOS release packaging, `TASK-260715-1tzaed` |

No exact four-target values are accepted on the board as of this contract.
Production target composition therefore MUST fail closed when any symbol is
absent, placeholder, unaccepted, or does not match the signed embedded provider.
Shared repository/controller/provider implementation MAY proceed with an
injected, validated `PlatformVPNIdentity` and deterministic test fixtures. It
MUST NOT embed guessed production identifiers or entitlement strings.

The accepted matrices must give every host/provider only the approved public
NetworkExtension provider capability, app group, Keychain group, and signing-
mode-specific placement it actually needs. This contract does not name the
entitlement's exact serialized value or assume that development, embedded app
extension, Developer ID, or system-extension packaging use identical placement.
The managed-VPN Keychain group `com.apple.managed.vpn.shared` is not used or
written by this product. Portal/provisioning evidence remains outside this task.

## 3. Exact manager ownership and canonical configuration

### 3.1 Stable constants

```text
ownerKey                 = "works.relux.tunnel.owner"
ownerValue               = "relux-tunnel"
managerContractKey       = "works.relux.tunnel.manager-contract-version"
managerContractVersion   = 1  (NSNumber/Int, not String)
configurationReferenceKey= "works.relux.tunnel.configuration-reference"
serverAddressSentinel    = "relux.invalid"
startRequestKey          = "works.relux.tunnel.start-request"
```

`relux.invalid` is a technical non-routable sentinel, not an SSH endpoint and
not final product copy. `localizedDescription` is injected localized display
text and is never an identity field.

### 3.2 Owned-manager predicate

For the current platform, `isOwned(manager)` is true if and only if all of:

1. `manager.protocolConfiguration` is an `NETunnelProviderProtocol`;
2. `protocol.providerBundleIdentifier == platform.providerBundleID` using
   exact, case-sensitive equality;
3. `protocol.providerConfiguration?[ownerKey]` is a `String` exactly equal to
   `ownerValue`.

No other field participates. In particular, localized description,
`serverAddress`, enabled state, profile UUID, manager-contract version, array
position, and current session status do not establish ownership. A manager
whose bundle ID matches but whose marker is absent or malformed is a
`legacyOrForeignCandidate`: it is never edited, disabled, or removed by v1.

The proof obligation is mechanical: every mutation/removal entry point MUST
accept only an object returned by a fresh `loadAllFromPreferences` call and
MUST re-evaluate `isOwned` immediately before the mutation. Tests provide mixed
manager arrays covering other providers, other protocol classes, lookalike
labels, missing/wrong/type-confused markers, and future schema versions; mocks
must record zero setter/save/remove calls for every false row.

### 3.3 Canonical v1 fields

An owned current manager has:

- a newly constructed `NETunnelProviderProtocol` (never merge arbitrary keys);
- `providerBundleIdentifier = platform.providerBundleID`;
- `serverAddress = "relux.invalid"`;
- `disconnectOnSleep = false`;
- `includeAllNetworks = false`, `excludeLocalNetworks = false`, and
  `enforceRoutes = false`; reconnect/fail-closed policy remains reserved;
- `providerConfiguration` containing exactly `ownerKey`,
  `managerContractKey`, and `configurationReferenceKey`;
- `configurationReferenceKey` as `Data` produced by
  `RuntimeConfigurationCodec.encode(TunnelConfigurationReference)` and bounded
  to 4 KiB; it contains schema v1 and one opaque profile UUID only;
- `onDemandEnabled = false`, no On Demand rules, no app rules;
- caller-provided localized description; and
- no username/password, private key, passphrase, host-key bytes, raw profile,
  destination, packet, log, or diagnostic payload.

The owner marker determines ownership across supported schema upgrades. The
manager contract and reference schema determine whether an owned manager is
current. Version `> 1` yields `updateRequired` and MUST NOT be downgraded.
Version `< 1`, wrong types, missing reference, invalid UUID, or codec failure
yields `ownedConfigurationCorrupt`; repair requires an explicit current desired
profile and replaces the complete protocol object. Without that input, no
write occurs.

## 4. Repository operations and persistence outcomes

All repository calls are serialized per process. Each Apple preference call
has a 15-second local deadline. NetworkExtension completion callbacks cannot
be cancelled; cancellation/timeout retires the local operation token, ignores
its late callback, marks cache state unknown, and forces a fresh load before
the next action.

### 4.1 Discover/ensure

1. Call `NETunnelProviderManager.loadAllFromPreferences`.
2. On load error, return a stable mapped error; create nothing. A nil managers
   collection is also failure even when Apple supplies nil error:
   `preferencesLoadReturnedNoCollection`. Only a non-nil successful collection
   may be partitioned; nil never means zero configurations and permits no
   create/save/remove.
3. Partition with the exact predicate without mutating any manager.
4. Zero owned and no legacy/foreign candidate: create a new disabled manager,
   assign the canonical protocol, and save.
5. One owned: validate; when desired fields differ, replace the complete
   protocol object while preserving its current enabled state, then save.
6. More than one owned: return `duplicateOwnedManagers(count)` with no writes.
   Normal ensure never chooses by array order and never silently deletes.
7. Any bundle-ID lookalike lacking the marker: return
   `legacyOrForeignCandidate` instead of creating a second lookalike.
8. After every successful save, discard the instance, load all again, require
   exactly one matching owned manager, validate the persisted fields, and
   return that reloaded object only. Save success without reload success is
   `savedButReloadFailed`; callers must not start from the stale object.

Repeated create/update with zero or one owned manager is idempotent. Duplicate
repair is a distinct explicit operation. First decode every exact-owned
manager's manager-contract and configuration-reference schema without mutation.
If any is newer than supported or cannot be proven current/explicitly repairable,
return `futureOwnedConfigurationConflict` / `updateRequired(version)` and make
no change; future-owned data is never removed or downgraded. Otherwise, only
while every supported exact-owned session is `.disconnected` or `.invalid`,
remove the freshly revalidated supported duplicates, reload to prove zero, then
call ensure to create one. If any is connecting, connected, reasserting, or
disconnecting, return `duplicateOwnedManagersActive` and make no change. Every
removal rechecks ownership, supported schema, and terminal session state against
the fresh load.

### 4.2 Enable/disable and permission

Ensure never changes disabled to enabled. `enableOwnedManager` requires
explicit foreground user intent (and the separate disclosure gate when added),
fresh discovery, exactly one current owned manager, and no active transition.
It sets `isEnabled = true`, saves, reloads, and succeeds only if the reloaded
manager is still owned/current/enabled.

This separation is required because Apple documents that enabling an
enterprise VPN configuration can disable another app's enterprise VPN. Relux
does not call setters/save/remove on unrelated managers, but the OS may change
which enterprise VPN is enabled. The host must present this as a system-level
enable effect, not claim that unrelated configurations are preserved enabled.

Disable is also explicit, fresh-loads and rechecks ownership, requests session
stop first, waits up to 15 seconds for `.disconnected`/`.invalid`, then sets
`isEnabled = false`, saves, reloads, and verifies. On timeout it does not save.

There is no preflight permission boolean. The first valid save/enable is the
permission/authorization operation. iOS and macOS use framework-managed public
NetworkExtension behavior; v1 does not manufacture or persist an
`AuthorizationRef`. Success is known only after save and reload. A non-NEVPN
authorization/cancellation error maps to `authorizationFailed(platformDomain,
platformCode)` rather than falsely asserting a public `permissionDenied` code.

### 4.3 Remove

Removal occurs only for explicit delete/uninstall/reset intent. It fresh-loads,
requires exactly one exact-owned manager, stops an active session and observes
terminal status, rechecks ownership, calls `removeFromPreferences`, then reloads
and succeeds only when no exact-owned manager remains. Stop timeout, ownership
change, duplicate conflict, or remove/reload error leaves the configuration in
place. No bulk “remove all VPN” operation exists.

### 4.4 Stale configuration

On `NEVPNError.configurationStale`, retire the object, reload, recompute
ownership, rebuild the intended mutation from immutable desired input, and
retry save once. A second stale result becomes `concurrentModification`; no
loop and no mutation of the old instance. `NEVPNConfigurationChange` invalidates
the cache and triggers debounced rediscovery, never an automatic write.

## 5. Host session control

The controller retains observers/tasks only while its host-side instance is
alive. Destroying the controller or containing app cancels app waits and removes
observers; it never calls `stopTunnel` from deinit/termination/backgrounding.

### 5.1 Start

Start requires a freshly reloaded, exact-owned, current, enabled manager and a
`NETunnelProviderSession` connection. The controller reads current status first:

| Status | Start result |
|---|---|
| `.disconnected` | encode and call `startTunnel(options:)` once |
| `.connecting` | `alreadyStarting`; no second call |
| `.connected` | `alreadyConnected`; refresh provider snapshot |
| `.reasserting` | `systemReasserting`; no restart in M1 |
| `.disconnecting` | `sessionBusyDisconnecting` |
| `.invalid` | reload once; if still invalid, `sessionInvalid` |

Options contain exactly `startRequestKey: Data`, encoded as a bounded 4 KiB
`RuntimeStartRequest` duplicating the stored configuration reference. No secret
or free-form option is allowed. The provider treats its stored protocol
reference as authoritative; present start data must decode and exactly equal it.
Nil options (system start) use the stored reference. A mismatch fails start.

`startTunnel` returning without throw means only “request accepted.” The host
waits up to 60 seconds for session status to reach `.connected` or a terminal
failure. Cancellation after acceptance issues `stopTunnel` once and reconciles
status. Timeout also issues stop and returns `startTimedOut`; it never reports
connected. Provider startup has the same 60-second deadline enforced with the
injected monotonic clock.

### 5.2 Status and capability projection

Observe `NEVPNStatusDidChange` for the exact session and immediately read
`session.status` on receipt; notification order itself is not state. On initial
subscription/relaunch, read current status before waiting for notifications.

| System status | Provider snapshot | Truthful projection |
|---|---|---|
| invalid/disconnected/disconnecting | any | the matching system state; no capability claim |
| connecting/reasserting | any | the matching system transitional state; no capability claim |
| connected | missing/timeout/unsupported/stale | `systemConnectedCapabilityUnknown` |
| connected | fresh lifecycle state connecting/stopping/failed/unknown | system connected plus that provider fact; no TCP/DNS/UDP claim |
| connected | fresh, healthy, routes installed, compatible, TCP + safe DNS, UDP false | `connectedDegraded` |
| connected | fresh, healthy, routes installed, compatible, TCP + safe DNS + UDP | capability facts are true; any final “full” product label remains later policy |

Fresh means a response to the current request, supported protocol/schema,
strictly newer `(runtimeGeneration, snapshotSequence)` than the last accepted
snapshot, and received within the 3-second request deadline. A new provider
generation resets the sequence baseline. Cached snapshots surviving app
relaunch are historical only; the relaunched host requests a new snapshot.

### 5.3 App messages

M1 app messages are read-only: `getProtocolCapabilities`,
`getRuntimeSnapshot`, `getCapabilities`, and `getDiagnostics`. Stop uses
`NETunnelProviderSession.stopTunnel`; profile/configuration/trust mutations use
their repositories, never provider RPC. The host first negotiates protocol
capabilities, uses accepted runtime v1 codecs and size limits, adds a request
UUID, and permits one in-flight request per request UUID. It sends messages only
while the freshly read system status is `.connected`; transitional or terminal
states return `providerUnavailable` without calling the message API.

The provider validates size/UTF-8/nesting/duplicate keys/protocol/schema/kind,
serializes against its current generation, and calls a non-nil Apple response
handler exactly once with either the versioned response or
`RuntimeProtocolError`. If the Apple handler is nil, it validates/handles but
does not retain a response. Host timeout is 3 seconds. A synchronous send throw,
nil response, timeout, cancellation, wrong request ID, corrupt/unsupported
response, or retired controller generation cannot update capability state.

Apple documents that messaging may launch a provider that is not running. The
host therefore does not use messaging as a liveness probe and never infers
connected from a successful message; system session status remains authority.

### 5.4 Stop

`stopTunnel` is asynchronous and has no host completion callback. For
`.connecting`, `.connected`, or `.reasserting`, issue it once and wait up to 15
seconds for `.disconnected` or `.invalid`. For `.disconnecting`, join the same
wait. For terminal states, return idempotent success. Cancellation retires the
host wait but does not attempt to cancel the system stop. Timeout returns
`stopTimedOut` while continuing truthful status observation; it never claims
cleanup occurred.

## 6. Provider adapter lifecycle (identical contract on both platforms)

Each `NEPacketTunnelProvider` subclass is a translation/composition shell. It
owns Apple completion-handler gates and delegates policy/lifecycle to the shared
adapter/coordinator. It contains no second packet, SSH, TCP, DNS, route,
capability, reconnect, or cleanup state machine.

### 6.1 Start completion ownership

For every Apple `startTunnel(options:completionHandler:)` invocation:

1. create a once-only gate owned by the provider instance;
2. decode stored protocol data and optional matching start request;
3. create/start exactly one shared generation;
4. wait for the accepted M1 usable point: configuration/trust/auth and mandatory
   consumers healthy, network settings successfully applied, packet reads
   active, and the usable snapshot published;
5. then and only then call the Apple handler once with `nil`;
6. on validation/start/timeout/cancellation, stop/join rollback, clear uncertain
   or committed routes per `TASK-260715-30zng6`, then call once with a stable
   provider NSError.

The deadline is 60 seconds total. Duplicate start while `.starting`, `.running`,
or `.stopping` creates no generation and completes that invocation once with
`lifecycleBusy`. If stop arrives during start, stop wins: cancel startup, join
rollback, complete the pending start once with `startCancelled`, then complete
the stop handler(s). Late runtime/settings callbacks carry a generation token
and cannot complete a retired gate.

### 6.2 Stop completion ownership

For every Apple `stopTunnel(with:completionHandler:)` invocation, register its
own once-only gate against one shared stop operation. Immediately reject new
messages/starts, capture the raw `NEProviderStopReason`, translate it for shared
cleanup, cancel startup/runtime work, clear routes when required, shut down
packet flow and owned components in accepted reverse order, and join cleanup.

The graceful cleanup budget is 10 seconds total. At expiry the cleanup owner
force-closes all closable owned handles, records a bounded redacted
`cleanupDeadlineExceeded`, calls every pending stop handler exactly once, and
leaves late callbacks generation-retired. Completion means the adapter has
released all resources it can control; it must not wait indefinitely. Repeated
stop is idempotent and joins the same cleanup task.

Apple reason mapping:

- `.userInitiated` -> shared `.userInitiated`;
- `.providerFailed` -> shared `.providerFailure`;
- `.configurationFailed` or `.connectionFailed` during startup -> shared
  `.startupFailure`;
- all remaining known/future reasons -> `.platform(code: rawValue)`.

The raw numeric reason is privacy-safe diagnostic metadata. A provider-detected
fatal failure calls `cancelTunnelWithError` once with a stable redacted NSError;
it never directly invokes its own `stopTunnel`. The later system stop callback
joins the already-running cleanup.

### 6.3 Sleep, wake, and process independence

`disconnectOnSleep` is false. `sleep(completionHandler:)` owns a once-only gate,
performs no reconnect or policy transition, and calls the handler immediately
(hard local guard: 2 seconds). `wake()` does not create/restart a generation;
normal health reporting either continues or a fatal runtime failure cancels the
tunnel. Path reconnect remains a later milestone.

Containing-app suspension/termination/normal macOS quit removes only host-side
observers and pending UI commands. The extension continues under the OS with
its existing generation. Provider/extension termination by the OS is reported
through session status and last-disconnect error; v1 does not auto-reconnect.

## 7. Stable error mapping

Never expose raw localized platform error strings as identifiers. Retain
redacted domain/code for diagnostics.

| Source | Stable result |
|---|---|
| `NEVPNError.configurationInvalid` | `configurationInvalid` |
| `NEVPNError.configurationDisabled` | `configurationDisabled` |
| `NEVPNError.connectionFailed` | `connectionFailed` |
| `NEVPNError.configurationStale` after one retry | `concurrentModification` |
| `NEVPNError.configurationReadWriteFailed` | `preferencesReadWriteFailed` |
| `NEVPNError.configurationUnknown` | `preferencesUnknown` |
| non-NEVPN error during save/enable authorization | `authorizationFailed(domain, code)` |
| preference deadline / local cancellation | `preferencesTimedOut` / `operationCancelled` |
| more than one owned manager | `duplicateOwnedManagers(count)` |
| marker absent with expected bundle ID | `legacyOrForeignCandidate` |
| owned schema corrupt/future | `ownedConfigurationCorrupt` / `updateRequired(version)` |
| synchronous start/message rejection | mapped NEVPN result, otherwise `platformRejected(domain, code)` |
| connected not observed in 60 s | `startTimedOut` |
| disconnect not observed in 15 s | `stopTimedOut` |
| message throw/nil/3 s deadline | `providerUnavailable` / `providerNoResponse` / `providerMessageTimedOut` |
| provider validation/runtime failure | stable NSError domain `works.relux.tunnel.provider`, code below |

Provider NSError integer codes/results are stable: 1001
`providerConfigurationInvalid`, 1002 `providerConfigurationSchemaUnsupported`,
1003 `providerStartReferenceMismatch`, 1004 `providerLifecycleBusy`, 1005
`providerStartCancelled`, 1006 `providerStartupTimedOut`, 1007
`providerRuntimeStartupFailed`, 1008 `providerNetworkSettingsFailed`, and 1009
`providerInternalInvariant`.
The NSError userInfo contains no secrets, endpoints, fingerprints, packets, or
raw underlying error text. Runtime diagnostics retain the accepted redacted
runtime domain/code separately.

Where available (iOS 16/macOS 13+), `fetchLastDisconnectError` supplements but
never overrides session status. Fetch uses a 3-second local deadline. A terminal
status is published immediately; the optional reason is attached when received.
Fetch timeout/cancellation becomes `disconnectReasonUnavailable(timeout|cancelled)`
and never delays or reverses the system state.

Public `NEVPNConnectionErrorDomain` codes map exactly:

| Apple code | Stable reason |
|---|---|
| `overslept` | `systemOverslept` |
| `noNetworkAvailable` | `networkUnavailable` |
| `unrecoverableNetworkChange` | `unrecoverableNetworkChange` |
| `configurationFailed` | `configurationFailed` |
| `serverAddressResolutionFailed` | `serverResolutionFailed` |
| `serverNotResponding` | `serverNotResponding` |
| `serverDead` | `serverUnavailable` |
| `authenticationFailed` | `authenticationFailed` |
| `clientCertificateInvalid` | `clientCertificateInvalid` |
| `clientCertificateNotYetValid` | `clientCertificateNotYetValid` |
| `clientCertificateExpired` | `clientCertificateExpired` |
| `pluginFailed` | `providerProcessFailed` |
| `configurationNotFound` | `configurationNotFound` |
| `pluginDisabled` | `providerUnavailableOrUpdateRequired` |
| `negotiationFailed` | `negotiationFailed` |
| `serverDisconnected` | `serverDisconnected` |
| `serverCertificateInvalid` | `serverCertificateInvalid` |
| `serverCertificateNotYetValid` | `serverCertificateNotYetValid` |
| `serverCertificateExpired` | `serverCertificateExpired` |

Provider-domain codes 1001–1009 map to the identically named stable provider
results defined above; an unknown provider code becomes
`providerFailureUnknown(code)`. Unknown system domains/codes become
`systemDisconnectUnknown(domain, code)`. A nil last error becomes
`startTerminatedWithoutError(status)` if a start wait reached
`.disconnected`/`.invalid` before ever reaching `.connected`, or
`systemDisconnectedWithoutReportedError` for an established/observed session.
If a start is pending, its terminal transition consumes the start operation and
returns the mapped start failure. Otherwise the same mapping is retained only
as the last disconnect reason; it never changes `NETunnelProviderSession.status`.

## 8. Public API boundary

Allowed: `NETunnelProviderManager.loadAllFromPreferences`, inherited
load/save/remove APIs, `NETunnelProviderProtocol`, `NETunnelProviderSession`
start/stop/message/status, NetworkExtension notifications,
`NEPacketTunnelProvider` lifecycle, `packetFlow`,
`setTunnelNetworkSettings`, `cancelTunnelWithError`, sleep/wake, and
`fetchLastDisconnectError`.

Forbidden: preference-file access, private utun discovery/control, private
NetworkExtension selectors, process signaling between host/provider, assuming
provider PID/lifetime, system Settings automation, polling private daemons,
placing secrets in manager/options/messages, or app-owned live forwarding.

Primary Apple references:

- https://developer.apple.com/documentation/networkextension/netunnelprovidermanager
- https://developer.apple.com/documentation/networkextension/netunnelprovidermanager/loadallfrompreferences(completionhandler:)
- https://developer.apple.com/documentation/networkextension/netunnelprovidersession
- https://developer.apple.com/documentation/networkextension/netunnelprovidersession/sendprovidermessage(_:responsehandler:)
- https://developer.apple.com/documentation/networkextension/nepackettunnelprovider/starttunnel(options:completionhandler:)
- https://developer.apple.com/documentation/networkextension/nepackettunnelprovider/stoptunnel(with:completionhandler:)
- https://developer.apple.com/documentation/networkextension/nevpnstatus
- https://developer.apple.com/documentation/networkextension/nevpnerror-swift.struct

The Xcode 26.5 SDK headers independently confirm completion semantics, public
error domains, stop reasons, and platform availability.

## 9. Required downstream verification

`TASK-260715-15vkvz` owns manager repository/persistence tests;
`TASK-260715-1rsqrh` owns host commands/status projection;
`TASK-260715-1bp6eu` owns read-only message routing and bounded shared cleanup;
`TASK-260715-3dv8ea` owns the macOS thin provider; and
`TASK-260715-2hiabd` remains the deferred parity adapter, not macOS-v1 execution
scope. `TASK-260715-3lab1f` owns shared conformance and repeated lifecycle tests.

Mandatory tests include the full ownership truth table; zero writes to unrelated
fixtures; save/reload/stale/late callbacks; explicit enable side effects;
duplicate repair; start/stop cancellation and deadlines; all NEVPN statuses;
fresh/stale/wrong-order snapshots; nil/late app-message responses; every Apple
stop reason; stop during every startup phase; once-only completion gates; host
recreation; and 100-cycle resource baselines.

## 10. Reserved decisions

Reconnect/on-demand/path-change recovery, `reasserting` policy, fail-closed
route flags, final full/degraded labels, profile editor UX, final localized
manager labels, exact production identifiers/entitlements, release signing,
TestFlight, notarization, and uninstall UX are not decided here. Human
ratification remains `TASK-260717-1dsqnj`; it does not block implementation of
this agent-reviewed draft.
