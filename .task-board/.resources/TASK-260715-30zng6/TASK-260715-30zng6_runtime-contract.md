# TASK-260715-30zng6 — M1 runtime ownership and sequencing contract

Status: production contract draft for autonomous agent review  
Contract schema: `m1-runtime-contract/1`  
Date: 2026-07-20  
Scope owner: `ReluxTunnelCore` inside the packet-tunnel extension process

## 1. Decision and production permit

This contract fixes the M1 ownership, dependency, concurrency, sequencing,
cancellation, state, failure, and compatibility rules. It does not choose an
SSH engine, packet/HEV pin, MTU, buffers, lanes, UDP behavior, reconnect policy,
or route mode.

`productionCompositionPermitted` is **false** in this revision. The three M0
handoffs mandated by the task precondition have no reviewer-accepted outcome
resource as of 2026-07-20. `TASK-260720-1qhxqa` is the only task allowed to turn
that permit true by binding exact accepted resource names and SHA-256 digests.
No production factory may enter development or resolve a concrete packet/HEV or
SSH implementation before that manifest passes. Candidate-neutral message
models, coordinator logic against fakes, and deterministic contract tests may
proceed from this draft.

Human ratification is outside this contract and remains
`TASK-260717-1dsqnj`; it does not move live runtime ownership to the app and it
does not authorize bypassing the M0 binding permit.

## 2. Authoritative requirements and handoffs

### 2.1 Accepted structural handoff

The following reviewed M0 outputs are authoritative for dependency direction
and the currently implemented injection surfaces:

| Task | Exact accepted resources | Binding use |
| --- | --- | --- |
| `TASK-260715-2nfz7w` | `TASK-260715-2nfz7w_boundary-map.md`, `TASK-260715-2nfz7w_results.md`, accepted by `TASK-260715-2nfz7w_review.md` | `ReluxTunnelCore` is platform-neutral; only iOS/macOS adapter modules import NetworkExtension; provider/harness roots inject the same core protocols; numeric and engine policy stays caller-owned. |
| `TASK-260715-3o0co4` / `TASK-260715-3dn813` | `TASK-260715-3o0co4_results.md`, accepted by `TASK-260715-3o0co4_review.md`; `TASK-260715-3dn813_test-report.md` with the accepted reviewer verdict recorded on the task | Current `PacketFlowBridge` public socket-pair API, descriptor-borrow ownership, bounded-drop/fatal behavior, supervised cleanup and fault coverage. These are current structural/source behaviors only; `TASK-260715-2jatnd` remains the sole authority for production pins and selected configuration. |

Existing public seams preserved by this contract include `TunnelRuntime`,
`TunnelRuntimeFactory`, `TunnelProviderLifecycle`, `TunnelRuntimeContext`,
`PacketFlow`, `PacketBridge`, `SSHTransportFactory`, `SSHTransport`,
`InternalSOCKSComponent`, `TunnelClock`, `TunnelMetrics`, `TunnelLogger`,
`TunnelCancellationChecking`, and `TunnelMemoryPressureSource`. Implementations
may refine these APIs only when their semantics remain compatible with this
contract and the accepted boundary map.

### 2.2 Required but missing M0 production handoffs

| Required task | Current evidence state | Exact missing handoff | Binding conditions when accepted |
| --- | --- | --- | --- |
| `TASK-260715-nphtib` | `backlog`; no outcome resources | Reviewer-accepted generated-project architecture verification matrix | Exact generated graph and scheme revision; dependency direction; Apple build matrix; native linkage; deterministic generation; legacy isolation; any conditions/revalidation triggers. |
| `TASK-260715-2jatnd` | `backlog`; no outcome resources | Reviewer-accepted packet-bridge and HEV decision ADR | Exact bridge/HEV source and binary pins; accepted MTU; requested/effective socket buffers; batch count/time budgets; HEV settings including task stack, TCP buffer, UDP copy buffers and session ceiling; notices; fork disposition; memory and revalidation conditions. |
| `TASK-260715-1gjxer` | `backlog`; no outcome resources | Reviewer-accepted SSH engine selection ADR | Exact selected adapter and dependency pin; approved algorithms/authentication; window and rekey ranges; mandatory capabilities; license/security/upstream obligations; residual risks and revalidation triggers. |

Neither `.spec/decisions.md` open ADR-014/ADR-015, source-tree defaults,
candidate results, task notes, logbook entries, nor this contract substitutes
for those missing accepted outcomes. If a later accepted resource is superseded,
the permit returns false until `TASK-260720-1qhxqa` binds the new revision.

### 2.3 M1 requirement trace

| Contract section | M1 source requirement |
| --- | --- |
| 3–5 ownership and calls | `.spec/architecture.md` runtime components and control/state ownership; `STORY-260715-1y04r0` AC 1–2; accepted `TASK-260715-2nfz7w` boundary map. |
| 6 startup/rollback | `.spec/routing-dns-lifecycle.md` startup order 1–8; `.spec/security-privacy.md` host verification and routing safety; `TASK-260715-3tlgwm` AC 2–5; `TASK-260715-30ugfm` AC 1–5. |
| 7 state/cancellation | `STORY-260715-1y04r0` AC 3–4; `TASK-260715-32virr` failure/race matrix; existing `TunnelProviderAdapter` generation rule. |
| 8 failures | `.spec/packet-plane.md` backpressure/fatal split; `.spec/ssh-transport.md` candidate-neutral failure surface; `.spec/security-privacy.md` fail-safe and privacy rules. |
| 9 messages/versioning | `.spec/architecture.md` app-message snapshot authority; `STORY-260715-1y04r0` AC 2; `TASK-260715-lovbdz` AC 1–5; current `ProviderMessageCodec.currentVersion == 1`. |
| 10 future seams | M1 scope exclusions; ADR-007/008/012; M2 capability task `TASK-260715-30lv40`; `.spec/routing-dns-lifecycle.md` reconnect and fail-closed sections. |
| 11 validation | `TASK-260715-32virr`, `TASK-260715-m8bi8i`, and `.spec/validation.md` M1 TCP/DNS/lifecycle matrices. |

## 3. Component ownership contract

“Owner” means the only component that may create, retain, mutate, stop, or
destroy the named live object. All live objects are extension-process local.

| Component / injected interface | Owner and concurrency domain | Lifetime | May call | Must not call / own |
| --- | --- | --- | --- | --- |
| iOS/macOS provider composition root | Platform adapter; NetworkExtension callback domain | Provider instance | Construct `TunnelProviderAdapter`; inject packet flow, settings applier, snapshot source, factories and environment dependencies | Live forwarding state, engine policy, coordinator transitions, app/UI objects |
| `TunnelProviderAdapter` | One Swift actor per provider instance | Provider instance | Serialize provider start/stop/app messages; create at most one generation through `TunnelRuntimeFactory`; retain last immutable terminal snapshot | Packet/SSH/route internals; blocking native calls; two active generations |
| `TunnelRuntimeCoordinator` (`TunnelRuntime`) | One Swift actor per generation | Start attempt through cleanup | Own generation token, state, cancellation tree, acquisition stack, component sessions and published snapshot sequence | NetworkExtension types, app state, candidate-specific types, detached untracked work |
| `ConfigurationSnapshotSource` | Injected storage adapter; its own serialization | Load call only; returns immutable value | Atomically load one non-secret versioned profile snapshot and opaque Keychain/trust references | Raw credentials, live runtime mutation, route installation |
| `SSHBootstrapSession` / selected `SSHTransport` | Coordinator owns returned session; adapter owns its event loop/executor/socket/channel internals | After configuration validation until final cleanup | Resolve on physical path, connect, expose raw host-key evidence to injected policy, authenticate, return verified identity and actual endpoint, open baseline `direct-tcpip`, snapshot, idempotent close | Route application; UI trust decisions; lanes or reconnect in M1; diagnostics containing endpoints |
| `TCPConsumer` | Coordinator owns one per generation; consumer actor owns accepted TCP flow registry and child flow tasks | Prepared after SSH; active until packet plane stops | Consume validated CONNECT requests dispatched by the packet plane; open one direct-tcpip channel per accepted flow; bounded pump; report typed health/metrics | Own/bind the HEV private SOCKS boundary, accept unauthenticated local clients, lane scheduling, UDP or DNS |
| `DNSConsumer` / `VirtualDNSIngress` | Coordinator owns one; DNS actor owns bounded transactions/cache and the logical virtual-DNS ingress | Prepared before routes; active until teardown | Accept only DNS UDP/TCP traffic dispatched for the approved virtual DNS addresses; forward upstream only through authenticated SSH TCP; expose `ready`; cancel all transactions | Physical resolver after routes, destination/query logging, general UDP, route mutation, private SOCKS credentials/listener ownership |
| `M1PacketPlaneSession` | Coordinator owns session; session is sole owner of `HEVSOCKSBoundary` and per-generation admission credentials; after activation, `PacketFlowBridge` actor owns endpoint A/pumps/run completion, HEV supervisor owns its native thread/global lease, and bridge retains endpoint B and lends it exclusively | Pure/preflight `prepare` before routes; acquire/start on `activateReads` after settings; stopped before SSH | Validate bound config and construct candidate-neutral references during preflight without acquiring bridge/HEV resources; after settings, call existing `PacketBridge.start`, own private admission, dispatch authenticated CONNECT to TCP and only virtual-DNS UDP/TCP to DNS, reject other UDP in M1; stop/join idempotently | utun discovery; transfer/close endpoint B from HEV; call `PacketBridge.start` before settings; choose M0 values; forward general UDP |
| `PacketFlow` | Platform adapter owns wrapper; coordinator generation has exclusive logical use | Provider instance wrapper; reads scoped to active generation | Read/write via public API; shutdown pending read on stop | Route settings; HEV descriptor ownership; callbacks that mutate state without generation check |
| `NetworkSettingsPlanBuilder` | Pure injected dependency | Call-scoped | Build compatible-mode plan from validated virtual-address/DNS contract, bound MTU and actual SSH endpoint | Apply settings; broad exclusions; fail-closed options in M1 |
| `NetworkSettingsApplier` | Platform adapter owns NetworkExtension API call; coordinator owns each request token | Provider instance; one in-flight request max | Apply/clear settings asynchronously and complete exactly once with generation-tagged result | Publish capability, call coordinator synchronously from callback, accept stale completion |
| `RuntimeSnapshotStore` | Coordinator actor is sole writer; provider adapter exposes immutable copies | Provider instance across generation release | Store latest lifecycle/capability/error/diagnostic metadata atomically; monotonically sequence per generation | Component mutation, secrets, payload/destination data, UI-derived state |
| `TunnelMetrics` / logger / clock / pressure source | Injected actors/value types | Provider or process | Aggregate bounded typed observations; supply monotonic time/pressure | High-cardinality identifiers, route/flow control, blocking coordinator |

### 3.1 Dependency direction

The only allowed construction direction is:

`Provider root -> TunnelProviderAdapter -> TunnelRuntimeFactory ->
TunnelRuntimeCoordinator -> injected component factories/sessions`.

Core defines protocols and state semantics. Platform adapters implement
`PacketFlow`, `NetworkSettingsApplier`, and provider callbacks. Native/selected
adapter modules implement HEV and SSH details. TCP and DNS consume only the
candidate-neutral authenticated-session surface. No lower component obtains a
coordinator reference; it emits typed, generation-tagged events to an injected
sink.

## 4. Allowed cross-boundary calls

| Caller -> callee | Allowed operation | Return/callback rule |
| --- | --- | --- |
| Containing app -> system VPN | install/start/stop and send bounded versioned app message | App never receives a live object and is not required after start. |
| Provider callback -> `TunnelProviderAdapter` | `start`, `stop`, `handleAppMessage` | Completion is exactly once; adapter serializes it. |
| Adapter -> coordinator | construct/start/stop/snapshot query | One coordinator per generation; stale object is released after cleanup. |
| Coordinator -> snapshot source | atomic load by opaque reference | Immutable non-secret value or typed error. |
| Coordinator -> SSH bootstrap | start before routes; obtain verified session + actual endpoint | Any host trust/auth error returns before route apply. |
| Coordinator -> TCP/DNS/packet plane | prepare/preflight, activate, stop, health query | Every event includes generation; stop is idempotent and non-cancellable. |
| Packet plane private ingress -> TCP/DNS | Dispatch authenticated SOCKS CONNECT to TCP; dispatch UDP/TCP only when the destination is an approved virtual DNS address to `VirtualDNSIngress` | General UDP is rejected in M1; dispatch carries generation and bounded parsed metadata, never raw diagnostics. |
| Coordinator -> settings builder/applier | pure build; `apply`; `clear` | At most one generation-tagged platform request; late callbacks are ignored after resource cleanup but still complete their own continuation once. |
| TCP/DNS -> SSH | direct-tcpip and bounded channel I/O | No route/state calls; close/cancel remains component-scoped. |
| Components -> event/metrics sinks | typed health, counters and stable error codes | Sink enqueue must not block component executor or expose sensitive values. |
| App-message handler -> snapshot store | read immutable snapshot | M1 app messages cannot mutate forwarding or install routes. |

All calls not listed are forbidden. In particular, the app cannot invoke TCP,
DNS, packet, HEV or SSH objects; callbacks cannot call platform settings from a
component; and engine/HEV types cannot cross into `ReluxTunnelCore` public
runtime contracts.

## 5. Concurrency and cancellation domains

1. The provider adapter actor serializes provider lifecycle and app-message
   reads. It never waits on app/UI liveness.
2. The coordinator actor is the single writer of state, generation, acquisition
   stack, route-installed flag, and snapshot sequence.
3. A generation owns one structured root task. SSH bootstrap, component prepare,
   route apply and read activation are awaited children. Long-running component
   work is owned by its session and joined by `stop`; no fire-and-forget task is
   permitted.
4. `PacketFlowBridge` retains its existing actor supervisor and bounded child
   pumps. `NEPacketTunnelFlow` callbacks are bridged through a continuation with
   the existing late-callback tombstone; a late payload is not inspected.
5. After post-settings activation, HEV runs on exactly one dedicated native
   thread under its process-wide lease. The bridge owns descriptor B and only
   lends it until HEV main returns. Pre-route packet-plane preflight owns no
   bridge descriptor, native thread, or HEV lease.
6. The selected SSH adapter owns its event loop/executor. Observer events are
   copied into bounded typed values and sent asynchronously with the generation;
   the coordinator never executes engine code on its actor.
7. TCP flow tasks belong to a bounded registry in `TCPConsumer`; DNS transaction
   tasks belong to `DNSConsumer`. Component stop closes admission, cancels and
   joins children, then returns.
8. `stop` creates or joins one shielded cleanup task. Cleanup does not inherit
   caller cancellation. Repeated/concurrent stop calls await the same result.
9. Cancellation is checked before and after every awaited acquisition. If stop
   wins after an operation returns, the returned resource is pushed then
   immediately rolled back; it is never published to the stopped generation.
10. Every callback, completion and health event carries the generation. A stale
    event may update only bounded discard metrics; it cannot alter state,
    routes, snapshots, or a newer generation.

## 6. Startup, usable publication, teardown and rollback

### 6.1 Successful M1 start

The order is binding:

1. Adapter accepts start only from idle, increments the generation and creates
   its root cancellation scope. Snapshot becomes `starting/configuration` with
   all capabilities false and `routesInstalled=false`.
2. Decode the bounded configuration envelope; atomically load and validate one
   immutable non-secret snapshot and opaque secret/trust references. Confirm
   supported versions, M1 compatible route mode, and
   `productionCompositionPermitted` for a production root.
3. Resolve/connect SSH on the physical path. Evaluate raw host-key evidence
   before credential retrieval/authentication. Authenticate and retain the
   verified identity plus actual IPv4/IPv6 endpoint. No routes exist.
4. Construct the baseline single-session TCP consumer. It owns flow tasks but
   does not bind or own the HEV private admission boundary. No lanes exist.
5. Prepare the DNS consumer and its logical `VirtualDNSIngress`; verify its
   upstream is SSH-only TCP. It must report ready without physical fallback.
6. `M1PacketPlaneSession.prepare` performs a pure preflight of the bound
   packet/HEV configuration and constructs candidate-neutral references. It
   acquires no descriptor, HEV lease/thread or private listener and does not
   call `PacketBridge.start`.
7. Build compatible-mode settings from the separately approved routing contract,
   bound M0 MTU, virtual addresses, tunnel DNS and the actual SSH endpoint host
   exclusion. Await `NetworkSettingsApplier.apply` completion.
8. Mark `routesInstalled=true`; call `activateReads`. This is the only operation
   that may acquire the HEV/private-boundary resources and call the existing
   `PacketBridge.start`, which installs supervision and the first read chain.
   Activation returns only after the first read registration and mandatory
   packet/HEV supervision are live. The packet-plane dispatcher owns private
   admission, sends CONNECT to TCP, sends only approved virtual-DNS UDP/TCP to
   DNS, and rejects other UDP. Activation does not require the first user packet.
9. Re-check SSH, TCP, DNS and packet health, then atomically publish
   `usableTCPDNS` with `tcp=true`, `safeDNS=true`, `udp=false`,
   `routesInstalled=true`. Only this publication permits provider success.

M1 opens no optional SSH lane. No UDP/full-capability probe participates in M1
base usability.

### 6.2 Stop and mandatory runtime failure

The exact cleanup order is:

1. Transition to `stopping`, close TCP/DNS admission, publish all capabilities
   false, and cancel the generation root.
2. Stop/join packet reads, bridge pumps and HEV; `PacketFlow.shutdown` retires
   or tombstones the outstanding platform read. No new packets/HEV requests can
   reach consumers after this returns.
3. Only if settings were committed or their commit outcome is uncertain, clear
   network settings and await the platform completion. If apply was never
   called or definitively failed without commit, skip clear and preserve
   `routesInstalled=false`. For a required clear, set `routesInstalled=false`
   only on confirmed success. On failure or uncertain completion, keep
   `routesInstalled=true`, set `routeState=clearFailed`, and publish a stable
   safety error through the snapshot/log; do not claim cleanup success.
4. Stop/join DNS transactions/cache, then TCP flow tasks. The packet-plane stop
   in step 2 already closed its solely owned private SOCKS boundary/admission.
5. Idempotently close all SSH channels/session/socket.
6. Release packet/HEV lease, component objects and immutable configuration;
   assert resource counters returned to the generation baseline.
7. If clear was not required because settings never committed, or a required
   clear was confirmed, user/system stop publishes `disconnected` and a
   mandatory failure publishes `failed` with `routesInstalled=false`. Only if a
   required clear failed or remained uncertain, publish terminal `failed` with
   `routesInstalled=true`, `routeState=clearFailed`, the primary error plus the
   safety cleanup error, then return from the nonthrowing stop. The adapter
   completes its provider callback exactly once and retains that immutable
   terminal snapshot even after releasing the runtime and becoming idle.

An unexpected mandatory SSH, TCP, DNS or packet-plane health loss in
`usableTCPDNS` follows this sequence immediately. Reconnect/retry is not owned by
M1.

### 6.3 Partial-start rollback

The coordinator pushes every acquired resource to a LIFO stack before the next
await. Rollback is exactly the reverse of successful acquisition, subject to
the route/read safety ordering above.

| Failure/cancel point | Acquired resources | Required rollback | Routes allowed? |
| --- | --- | --- | --- |
| Decode/load/validate | config copy at most | Zero sensitive references and release copy | Never |
| Resolve/connect/host/auth | transient resolver/TCP/SSH | Close credential handle/session/socket; release config | Never |
| TCP prepare | authenticated SSH, partial TCP admission | Close partial TCP, then SSH | Never |
| DNS prepare/readiness | SSH, TCP, partial DNS | Stop DNS, TCP, SSH | Never |
| Packet preflight | SSH, TCP, DNS, validated configuration/references only | Reset preflight state; stop DNS, TCP, SSH; no bridge/HEV resource exists | Never |
| Settings build | all prepared components | Stop packet plane, DNS, TCP, SSH | Never |
| Settings apply returns failure/cancelled | prepared components; platform may report no commit | If commit is uncertain, issue `clear` and await; then stop components; preserve `clearFailed` if confirmation fails | No usable route; route state remains truthfully uncertain if clear cannot be confirmed |
| Read activation | routes installed, prepared components | Stop packet plane; clear settings; stop DNS/TCP/SSH; if clear fails, publish `routeState=clearFailed` and retain `routesInstalled=true` | Temporarily installed but never published usable; truthfully uncertain on clear failure |
| Final health/publication | routes and reads active | Revoke capabilities; stop reads; clear settings; stop components; preserve truthful clear failure | False after confirmed clear; otherwise terminal failure reports installed/uncertain |

### 6.4 Conditions under which routes may not be installed

`NetworkSettingsApplier.apply` is forbidden while any of these is true:

- production root lacks a true M0 binding permit;
- configuration/command/schema version is unsupported, corrupt or oversized;
- profile generation is stale or contains secret bytes rather than opaque refs;
- host identity is unknown, changed, rejected or not yet evaluated;
- SSH authentication/session/actual endpoint is not ready;
- TCP consumer, DNS consumer, or packet-plane preflight is not ready;
- DNS is not ready with an SSH-only upstream;
- packet/HEV configuration, process lease or preparation failed;
- route mode is not the separately approved M1 compatible mode;
- route plan lacks either IP family, tunnel DNS, bound MTU, or narrow actual
  endpoint exclusion required by its contract;
- the generation is cancelled/stopping/stale; or
- another settings request is in flight.

## 7. State and transition contract

Internal states are more precise than the app projection. All capability bits
are false until `usableTCPDNS`.

| State | Legal entry | Legal exit | Cancellation point / idempotency | Error owner | Route invariant |
| --- | --- | --- | --- | --- | --- |
| `idle` | Initial; cleanup completed | `loadingConfiguration` on one accepted start | Stop is a no-op; duplicate start serialized and rejected as busy once exit begins | Provider adapter | No routes |
| `loadingConfiguration` | `idle` | `authenticatingSSH`, `stopping` | Before/after decode and load | Configuration source/codec; coordinator owns stale-generation error | No routes |
| `authenticatingSSH` | Valid immutable config | `preparingConsumers`, `stopping` | Resolution, connect, host decision, credential lookup, authentication | SSH bootstrap/host/credential domains | No routes |
| `preparingConsumers` | Verified authenticated SSH + actual endpoint | `applyingSettings`, `stopping` | TCP/DNS prepare plus pure packet preflight | Owning TCP/DNS/packet component | No routes and no bridge/HEV resource acquired |
| `applyingSettings` | All mandatory components prepared and route plan valid | `activatingPacketReads`, `stopping` | Before apply; after completion; uncertain commit triggers clear | Platform settings domain | No route before successful completion; committed route not usable yet |
| `activatingPacketReads` | Settings applied | `usableTCPDNS`, `stopping` | Activation and final health check | Packet plane or mandatory health owner | Routes installed; capabilities false |
| `usableTCPDNS` | Routes + read registration + SSH/TCP/DNS/packet health | `stopping` only in M1 | Stop coalesces; mandatory health loss initiates failure cleanup | Component reports cause; coordinator owns transition | Routes installed; TCP and safe DNS true; UDP false |
| `stopping` | Any non-idle state | `idle` after ordinary stop when clear was not required or was confirmed; `failed` after runtime/startup failure or any required settings-clear failure | One non-cancellable cleanup task; every stop joins it; public stop remains nonthrowing | Coordinator owns cleanup; primary operation error remains first | Skip clear when no commit occurred; otherwise attempt it before terminal publication and do not falsify a failed/uncertain result |
| `failed` | Cleanup ended for startup/runtime failure or required settings clear could not be confirmed | New generation begins only through adapter `idle -> loadingConfiguration` after runtime release | Stop after release is no-op; old callbacks stale; terminal snapshot retained | Original failing domain; a required settings-clear safety error is always retained | `routesInstalled=false` when clear was unnecessary or confirmed; true with `routeState=clearFailed` only when a required clear failed/was uncertain |

Illegal direct transitions, including idle-to-usable, applying-to-usable,
usable-to-authenticating, failed-to-usable, and any stale-generation transition,
are runtime invariant errors and trigger cleanup without capability publication.

The provider-facing projection is:

- internal idle -> `disconnected`;
- loading through activating -> `connecting`;
- usableTCPDNS -> current M1 `connectedDegraded` projection with explicit
  `tcp=true`, `safeDNS=true`, `udp=false` (the later M2 capability contract owns
  full/relay reasons); and
- stopping -> `disconnecting`; terminal failure -> `failed`.

M1 never emits `reasserting` and never advertises `connectedFull`.

## 8. Failure propagation and error ownership

1. The first causal error wins and selects the stable public error domain/code.
   Cleanup continues and accumulates bounded secondary codes without replacing
   it, except that a settings-clear failure is always surfaced as a safety
   annotation.
2. Expected user/system cancellation maps to stop, not failure. Cancellation
   during provider start returns a cancellation/start-aborted result after
   cleanup exactly once.
3. Configuration/version/size errors belong to `configuration`; trust and
   credential errors to `sshTrust`/`sshCredential`; resolution/connect/auth and
   channel health to `sshTransport`; TCP/DNS/packet failures to their component;
   apply/clear callbacks to `networkSettings`; illegal transitions/stale
   ownership to `runtimeInvariant`.
4. Raw engine errors, errno text, remote strings, hostnames, endpoints, DNS
   names, payloads, fingerprints, credential identifiers and shell input never
   cross the snapshot. Adapters map them to finite codes before reporting.
5. Current structural `PacketFlowBridge` semantics from accepted
   `TASK-260715-3o0co4_results.md` / `TASK-260715-3o0co4_review.md` and the
   accepted `TASK-260715-3dn813` test verdict classify normalized would-block
   and `ENOBUFS` as bounded drops and the reviewed EMSGSIZE/EOF/persistent-error
   paths as fatal. Production factories may rely on those semantics only after
   `TASK-260715-2jatnd` and `TASK-260720-1qhxqa` bind the exact production
   revision and all conditions; this contract does not promote current source
   or candidate values into a production decision.
6. A component may fail its own flow/channel without failing the generation
   only when the separately approved consumer contract classifies the event as
   flow-local. Loss of the baseline authenticated session, packet plane, TCP
   admission, DNS readiness, or route integrity is generation-fatal in M1.

## 9. Versioned configuration, commands, capabilities and diagnostics

### 9.1 Common envelope

Every new M1 cross-process payload other than the accepted legacy `version`
kind uses deterministic JSON with sorted keys and this top-level envelope:

`protocolVersion: UInt16`, `kind: String`, `schemaVersion: UInt16`, and
`requestID: String?` for app-message request/response correlation. Current
protocol and schema versions are `1`. Producers include all required fields;
optional new fields are additive.

| Kind family | M1 kinds | Maximum encoded bytes | Direction / side effects |
| --- | --- | --- | --- |
| Legacy version | `version` | 4 KiB | Exact accepted v1 exception: request and response contain only `protocolVersion` and `kind`; read-only and byte/semantic compatible with `ProviderMessageCodec` |
| Configuration | `configurationSnapshot` | 64 KiB | App-owned atomic non-secret snapshot -> provider load path; opaque profile/credential/trust refs only |
| Commands | `getProtocolCapabilities`, `getRuntimeSnapshot`, `getCapabilities`, `getDiagnostics` | 4 KiB | App -> provider; read-only. `getProtocolCapabilities` reports min/max protocol and kind/schema ranges without changing legacy `version`. Start/stop remain system VPN session operations, not app-message mutations |
| Runtime/capability | `runtimeSnapshot`, `capabilitySnapshot` | 16 KiB | Provider -> app; immutable generation/sequence state and independent `tcp`, `safeDNS`, `udp`, `routesInstalled`, `healthy` fields |
| Diagnostics | `diagnosticsSnapshot` | 64 KiB | Provider -> app; bounded aggregate counters/gauges/buckets and stable error codes only |
| Error | `protocolError` | 4 KiB | Provider -> app; stable domain/code, supported range, requestID; no raw error text |

The configuration snapshot also carries `configurationGeneration: UInt64` and
an opaque profile revision. Runtime/capability/diagnostic snapshots carry
`runtimeGeneration: UInt64` and `snapshotSequence: UInt64`; sequence starts at
zero for each runtime generation and increases for every published snapshot.
Consumers discard a lower generation or non-increasing sequence.

### 9.2 Compatibility rules

- JSON decoders ignore unknown object fields after size/depth/type validation.
  Unknown fields cannot enable behavior and are omitted when re-encoding known
  v1 models.
- Unknown required enum/string values in provider inputs, unknown command kinds,
  and unknown route/capability requests are rejected before side effects with
  `unsupportedKind` or `unsupportedValue`.
- A protocol/schema version above the advertised maximum is rejected; there is
  no best-effort downgrade. A version below the minimum is rejected. Supported
  older versions use an explicit version-specific decoder and deterministic
  upgrade, never the current decoder by accident.
- App-side snapshot readers preserve service by projecting an unknown output
  state/reason as `unknown` with all unknown capabilities false. They may still
  display system VPN state from `NETunnelProviderSession`.
- Unknown diagnostic counters/categories are ignored by older readers. Counter
  names already defined in a schema never change units or meaning; incompatible
  change requires a new schema version.
- Unknown capability fields default false. Absence of `tcp`, `safeDNS`, `udp`,
  `routesInstalled`, or `healthy` in a schema that requires them is corrupt, not
  a default.
- Oversize, excessive nesting, duplicate-key ambiguity, invalid UTF-8, corrupt
  numbers and trailing payload bytes are rejected before allocation/side effect.
- The existing M0 `version` request and response remain exact byte/semantic v1
  forms with only `protocolVersion` and `kind`; `schemaVersion`, `requestID`,
  ranges and features are forbidden on that kind. Discovery beyond the current
  version uses the separately versioned `getProtocolCapabilities` command.
- Secrets are structurally unrepresentable in shared models: configuration
  fields accept opaque references, never private-key/passphrase byte/string
  properties.

### 9.3 Snapshot authority

`NETunnelProviderSession.status` is authoritative for the system session.
The extension runtime snapshot is authoritative for live M1 capability, route,
generation, error and diagnostics state. The app may combine them for display
but may not persist a combined value as authority or infer capability from app
process memory. If the app terminates, forwarding and snapshot evolution
continue in the extension.

## 10. Explicit M2/M3 extension seams

| Future concern | Stable seam reserved now | M1 behavior |
| --- | --- | --- |
| M2 UDP/relay | Optional `DatagramCapabilitySession` contributing an independent `udp` bit and typed health | Not constructed; UDP false; absence does not weaken TCP/safe-DNS readiness |
| M2 full/degraded reasons | Versioned independent capability fields and reason namespace delegated to `TASK-260715-30lv40` | Only factual M1 fields; no relay retry/reprobe state |
| M3 lanes | `SSHSessionProvider`/channel-open policy input can later select a session | Exactly one authenticated baseline session; no scheduler, migration or lane ID semantics |
| M3 reconnect/reasserting | `RuntimeRecoveryPolicy` event disposition seam | Mandatory health event disposition is always `stopGeneration`; never retry/reassert |
| M3 fail-closed routes | `RoutePolicy` input to settings builder | Only separately approved compatible mode accepted; unsupported modes fail before routes |
| M3 memory recovery | Injected pressure source and typed component controls | Observe/diagnose only where M1 contracts allow; no old/new transport overlap |

No placeholder default may silently activate a future seam. Each requires a
new supported schema/capability version and its owning reviewed contract.

## 11. Development and verification handoff

### 11.1 Existing atomic implementation tasks

| Task | Contract responsibility |
| --- | --- |
| `TASK-260715-lovbdz` | Implement v1 envelope/configuration/command/capability/lifecycle/error models, bounds and compatibility rules in section 9. |
| `TASK-260715-3tlgwm` | Implement coordinator actor, state table, generation/cancellation and acquisition/rollback rules in sections 5–8 against injected fakes; it does not wait for production composition. |
| `TASK-260715-1i49fm` | Implement bounded privacy-safe snapshot aggregation and redaction from sections 8–9. |
| `TASK-260715-32virr` | Exhaustively fault/race test every transition and acquisition boundary in sections 6–8. |
| `TASK-260715-m8bi8i` | Black-box harness proof of one generation, app independence and resource baselines. |
| `TASK-260715-30ugfm` | Integrate real SSH/TCP/DNS/packet/settings components in the exact sequence after their owning story tasks land. |
| `TASK-260715-2rcvr0` | Reconcile developer/operator docs with the implemented names and evidence. |

### 11.2 New gap-closing task

`TASK-260720-1qhxqa — Bind accepted M0 revisions for M1 production
composition` is blocked by this contract and all three missing M0 decisions.
It blocks `TASK-260715-3ejhyy`. `TASK-260715-3ejhyy` remains the atomic owner of
concrete production factories and must consume only the resulting binding
manifest. The candidate-neutral coordinator proceeds after the contract/models
against fakes; real-component integration `TASK-260715-30ugfm` depends on both
the coordinator and production composition, where the two branches converge.

### 11.3 Required tests

- Table-drive every legal and illegal transition and every cancellation point.
- Inject failure immediately before and after each resource acquisition and
  assert exact rollback order, route flag and primary/secondary errors.
- Race start/stop, apply callback/stop, component health/stop and old/new
  generations; assert exactly one completion and no revival.
- Prove no settings apply under every condition in section 6.4.
- Repeat at least 100 generations with descriptor/task/thread/socket/channel/
  listener/lease counters returning to baseline.
- Verify version round-trip, golden output, unknown fields, unsupported
  versions/kinds/values, corrupt and oversize inputs, generation/sequence
  filtering and secret-field prohibition.
- Prove app-process loss has no effect on the extension-owned generation.
- Compile core, both adapters and harness without candidate/platform types
  leaking across the accepted dependency boundaries.

## 12. Residual decisions (owned, not placeholders)

1. M0 accepted pins and numeric values are intentionally unresolved here and
   owned by existing decision tasks plus `TASK-260720-1qhxqa`; production permit
   remains false.
2. Exact compatible virtual addresses/routes/DNS fields are owned by
   `TASK-260715-2pml0c`; the coordinator consumes its plan but cannot select it.
3. Profile/trust/credential field details are owned by `TASK-260715-29ws8l`.
4. Private SOCKS byte/stream semantics are owned by `TASK-260715-1juybj`.
5. M2 capability reasons and relay-only behavior are owned by
   `TASK-260715-30lv40`; M3 owns lanes, reconnect and fail-closed routing.

These ownership assignments are binding. They are not permission for local
implementation guesses.
