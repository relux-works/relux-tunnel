# M1 runtime ownership and operations

This document describes the implemented M1 shared runtime contract. It is for
developers and operators of the generated Relux Tunnel targets; it does not
define end-user copy or promise a future mode.

## Implementation status and authority

`ReluxTunnelCore` contains the implemented, provider-owned runtime,
`TunnelProviderAdapter`, strict v1 messages, aggregate diagnostics, and host
projection seams. `ReluxTunnelMacOSAdapter` contains the M0-bound production
dependency factory. The deterministic command-line harness composes the same
coordinator and packet-plane factory with controlled dependencies.

The checked-in generated macOS provider subclass is still a lifecycle shell:
`App/ReluxProxyMacTunnel/Sources/PacketTunnelProvider.swift` does not yet create
`MacOSProviderCompositionRoot`. Consequently, the shared runtime and production
factory are implemented and tested, but the generated provider executable is
not evidence that the live Network Extension invokes them. The iOS production
target is also deferred by ADR-024 and ADR-027. Do not describe either target
as a deployed M1 runtime until its concrete provider entry point is wired and
validated.

The authority boundary does not change when the host app exits:

- NetworkExtension owns the system tunnel lifecycle.
- The provider generation owns SSH, TCP, safe DNS, packet-plane, settings,
  cleanup, capability, and diagnostic state.
- `VPNSessionController` owns only host observation, bounded requests, and the
  projection of system status plus provider facts. `retire()` cancels this
  app-side work; it never calls `stopTunnel()`.
- The app may request or display state. It never owns forwarding resources and
  never infers provider capability from app process lifetime.

The focused lifecycle view is
[`TASK-260715-2rcvr0_m1-runtime-lifecycle.puml`](../diagrams/TASK-260715-2rcvr0_m1-runtime-lifecycle.puml),
with rendered pages under [`diagrams/artefacts/`](../diagrams/artefacts/).

## Component ownership

| Component | Public boundary | Internal owner and responsibility | Must not own |
| --- | --- | --- | --- |
| Host controller | `VPNSessionController`, `VPNHostSession` | App-process observation, bounded message requests, stale-snapshot filtering | SSH, packet reads, routes, DNS, or provider shutdown on app retirement |
| Platform roots | `IOSProviderCompositionRoot`, `MacOSProviderCompositionRoot` | Thin NetworkExtension-to-Core adaptation through one shared `TunnelProviderAdapter` contract | A second lifecycle or forwarding policy |
| Provider adapter | `TunnelProviderLifecycle` | One active generation, start/cleanup deadlines, once-only callbacks, request-ID ledger, failure cancellation | UI state or app-process lifetime |
| Runtime factory | `TunnelRuntimeFactory`; production `MacOSProductionDependencyFactory` | Validate the pinned M0 manifest before constructing a fresh graph; bind selected SSH/security and injected network seams | Reusing a consumed generation or bypassing the M0 gate |
| Coordinator | `TunnelRuntime`, `TunnelRuntimeHealthEventSink` | Ordered start, mandatory health, immutable snapshots, reverse cleanup | General UDP or reconnect policy in M1 |
| Packet plane | `M1PacketPlaneFactory`, `M1PacketPlaneSession` | Resource-free prepare followed by post-settings read activation; owns bridge/HEV/read teardown | Network settings authority |
| TCP and DNS | `TCPConsumer`, `DNSConsumer` | Admission and forwarding over the authenticated SSH session; M1 DNS is safe DNS only | Advertising UDP or full mode |
| Settings | `NetworkSettingsPlanBuilder`, `NetworkSettingsApplier` | Provider-owned plan/apply/clear with explicit commit disposition | Host-app route mutation |
| Snapshot stores | `ProviderRuntimeSnapshotSource`, `ProviderDiagnosticsSnapshotSource` | Generation-scoped immutable runtime/capability/diagnostic replies | Free-form labels or secrets |

## Dependency graph and M0 inputs

All concrete production dependencies are created per provider generation after
the immutable production-binding gate succeeds.

| Owner | Dependency | Binding or seam |
| --- | --- | --- |
| `MacOSProductionDependencyFactory` | M0 manifest | [`TASK-260720-1qhxqa_m0-production-bindings.md`](TASK-260720-1qhxqa_m0-production-bindings.md) and `Configuration/TASK-260720-1qhxqa_m0-production-bindings-v1.json` |
| Factory | SSH transport, host policy, credential resolver, error mapper | Root-owned selected libssh2 transport, immutable-profile policy, system-domain Keychain reference lookup, privacy-safe mapping; see [SSH transport](../.spec/ssh-transport.md) and ADR-014 |
| Coordinator | Configuration snapshot | `ConfigurationSnapshotSource`; immutable opaque profile, revision, credential, and trust references |
| Coordinator | TCP / safe DNS | Injected `TCPConsumerFactory` and `DNSConsumerFactory` using the authenticated SSH session |
| Coordinator | Packet plane | `BridgeBackedM1PacketPlaneFactory`, `PacketFlowBridge`, and the accepted [M0 HEV decision](TASK-260715-2jatnd_m0-bridge-hev-decision-adr.md) |
| Coordinator | Settings | Injected plan builder and applier; endpoint exception precedes broad tunnel routes per ADR-020 |
| Adapter | Runtime and diagnostics | `TunnelRuntimeFactory`, `ProviderRuntimeSnapshotSource`, `ProviderDiagnosticsSnapshotSource` |

The generated-target split and deferred target decisions are recorded in the
[generated project architecture ADR](TASK-260715-32umrc_generated-project-architecture-adr.md).
The canonical decision log is [`.spec/decisions.md`](../.spec/decisions.md),
especially ADR-014, ADR-015, ADR-020, ADR-023, ADR-024, and ADR-029.

## Startup and teardown

One `TunnelProviderAdapter` generation has a 60-second start budget and a
10-second cleanup budget. Its coordinator starts in this exact order:

1. Load and validate one configuration snapshot and its compatible route mode.
2. Authenticate SSH and register its cleanup control.
3. Prepare TCP, safe DNS, and the resource-free packet plane; verify all four
   mandatory components are healthy.
4. Build and apply NetworkExtension settings.
5. Activate packet reads and native packet-plane resources.
6. Recheck mandatory health and publish `connectedDegraded`.

The successful M1 snapshot has `tcp=true`, `safeDNS=true`, `udp=false`,
`routeMode=compatible`, `routeState=installed`, `routesInstalled=true`, and
`healthy=true`. TCP plus safe DNS is degraded M1 service, not full UDP
capability and not `connectedFull`.

Startup failure, provider failure, user stop, and system stop converge on one
idempotent reverse cleanup:

1. Close TCP admission, then DNS admission.
2. Stop packet reads, bridge/native work, and the private packet plane.
3. Clear settings only when apply committed or its disposition is uncertain.
4. Stop DNS, then TCP.
5. Close SSH and release the immutable configuration snapshot.

An apply failure explicitly described as `notCommitted` does not clear settings.
`committed` and `uncertain` both require clear. If clear fails, the final state
is `failed`, `routeState=clearFailed`, `routesInstalled=true`, and all
forwarding capability facts are false. The adapter completes its stop callback
exactly once; after the cleanup budget it force-closes registered handles and
records a finite cleanup diagnostic.

`providerDidFail` is also generation-scoped and first-call-wins. It calls the
platform cancellation callback before awaiting cleanup; a later system stop
joins the same cleanup rather than creating another owner.

## Messages and compatibility

The frozen legacy discovery request is exactly `{"kind":"version",
"protocolVersion":1}` and is answered independently of provider phase. All
other messages use protocol version 1 and schema version 1.

| Request kind | Maximum request | Response | Availability and semantics |
| --- | ---: | --- | --- |
| `getProtocolCapabilities` | 4 KiB | `protocolCapabilities`, max 4 KiB | Running generation only; lists the four v1 commands and schema range 1...1 |
| `getRuntimeSnapshot` | 4 KiB | `runtimeSnapshot`, max 16 KiB | Latest lifecycle, route, capability, health, and redacted error facts |
| `getCapabilities` | 4 KiB | `capabilitySnapshot`, max 16 KiB | Independent `tcp`, `safeDNS`, and `udp` facts; there is no synthetic “full” bit |
| `getDiagnostics` | 4 KiB | `diagnosticsSnapshot`, max 64 KiB | Fixed-schema aggregate counters, gauges, histograms, and bounded errors |

Every v1 command must carry a request UUID. The provider accepts it only while
the same generation is running and only once in the bounded active/recent
ledger. Missing, duplicate, stale-generation, non-running, or retired requests
receive `protocolError/unsupportedValue`. Responses are sorted-key JSON.

Configuration snapshots are capped at 64 KiB; legacy version, provider
configuration, start request, protocol capability, and protocol error payloads
are capped at 4 KiB. JSON nesting is capped at 16. Duplicate keys, malformed
UTF-8, invalid kinds/values, and unsupported versions fail closed. Known v1
output enums deliberately project unknown lifecycle/route values to `unknown`
and all capability facts to false, allowing additive output evolution without
creating a false-positive capability. Input version, kind, and enumerated-value
discriminators remain strict.

The detailed codec contract is also available in
[`RuntimeMessages.md`](../Sources/ReluxTunnelCore/ReluxTunnelCore.docc/RuntimeMessages.md).

## State and capability semantics

| Coordinator state | Published lifecycle | TCP | Safe DNS | UDP | Route / health meaning |
| --- | --- | ---: | ---: | ---: | --- |
| `disconnected` | `disconnected` | false | false | false | No usable provider generation |
| `starting(...)` | `connecting` | false | false | false | Partial resources are never advertised |
| `usableTCPDNS` | `connectedDegraded` | true | true | false | Compatible M1 routes installed and mandatory components healthy |
| `stopping` | `disconnecting` | false | false | false | Admission is closing; do not infer availability from remaining handles |
| `failed` | `failed` | false | false | false | Redacted primary error; route state may be `clearFailed` |

The host combines two authorities: NetworkExtension session status determines
whether the system tunnel is connected, while a newer provider snapshot
determines provider facts. Malformed, timed-out, absent, or stale provider data
means capability is unknown. It is not evidence of `false`, and it is never
reconstructed from app-side cached state.

## Failure mapping

### Wire protocol errors

Every rejected message returns `domain=protocol` and one stable code, with the
supported protocol and schema ranges: `payloadTooLarge`, `invalidUTF8`,
`corruptPayload`, `excessiveNesting`, `duplicateKey`,
`unsupportedProtocolVersion`, `unsupportedSchemaVersion`, `unsupportedKind`,
or `unsupportedValue`. No parser text is returned.

### Provider callback errors

The NSError domain is `works.relux.tunnel.provider`.

| Code | Token | Current M1 production call site |
| ---: | --- | --- |
| 1004 | `lifecycleBusy` | Overlapping start or invalid phase |
| 1005 | `startCancelled` | Stop, retirement, or lost generation during start |
| 1006 | `startupTimedOut` | 60-second start race deadline |
| 1007 | `runtimeStartupFailed` | Runtime factory/start failure |
| 1009 | `internalInvariant` | Exhausted generation or missing adapter at callback boundary |
| 1001–1003, 1008 | configuration/reference/settings vocabulary | Defined for stable platform mapping, but no current production call site emits these enum cases |

Do not claim an emitted error from enum presence alone. Concrete SSH bootstrap
mapping has its own finite provider-safe codes and stages in
`SSHBootstrapDiagnostics.swift`.

### Runtime snapshot errors

The coordinator maps failures to finite domain/token pairs:

| Boundary | Domain / fallback token |
| --- | --- |
| Configuration load or reference mismatch | `configuration/configuration_invalid` |
| SSH authentication or health | `sshTransport/ssh_session_lost` |
| TCP prepare or health | `tcp/tcp_flow_failed` |
| Safe DNS prepare or health | `dns/dns_upstream_timeout` |
| Packet prepare, activation, or health | `packetPlane/packet_plane_failed` |
| Settings plan / apply / clear | `networkSettings/settings_invalid`, `network_settings_apply_failed`, or `network_settings_clear_failed` |
| Missing internal resource / uncategorized startup | `runtimeInvariant/resource_missing` or `startup_failed` |
| Explicit provider failure stop | `runtimeInvariant/provider_failure` |

An injected dependency may supply a previously validated redacted error; the
fallback above is used when it does not. The diagnostics store accepts only its
reviewed `RuntimeDiagnosticErrorCode` catalog, at most one error per domain.
Unknown domain/code combinations are discarded and counted, not retained.

## Diagnostic privacy

Diagnostics are generation-scoped aggregates. The schema admits only finite
component, counter, gauge, histogram, DNS-result, queue-drop, error, SSH-stage,
and user-action tokens. It has no component-instance, SSH-lane, flow,
association, endpoint, query, packet, or request labels. A response may echo its
top-level request UUID for wire correlation, but that UUID never enters an
aggregate label. The bounded ingestion lane holds at most 256 pending updates;
unknown metric names are rejected and increment the rejected-update counter
without retaining the name.

Never add raw parser/platform error text, hostnames, IP addresses, ports, DNS
names, packet bytes, profile JSON, credentials, private-key material,
passphrases, host keys, or opaque profile/credential/trust reference values to
diagnostics. SSH context is limited to endpoint family and a reviewed algorithm
token. Redaction tests must exercise the production snapshot call site and
prove prohibited values are absent, including failure output.

## Troubleshooting

| Observation | Check | Interpretation / action |
| --- | --- | --- |
| Version reply works but v1 commands return `unsupportedValue` | Provider phase and request UUID reuse | Version discovery is phase-independent; commands require one live running generation and a fresh UUID |
| `connectedDegraded`, TCP and safe DNS true, UDP false | No action for M1 | Expected M1 capability; do not relabel as full mode |
| Startup fails before any consumer call | M0 manifest result and configuration reference | The production factory and configuration load fail closed before graph construction or forwarding |
| Route apply fails | Commit disposition and final route state | Clear only for committed/uncertain; a failed clear remains `clearFailed` and requires operator investigation |
| Mid-session SSH, TCP, DNS, or packet health becomes unhealthy | Runtime error token and cleanup counters | Mandatory health loss transitions through disconnecting to failed and performs the same reverse cleanup |
| App disappears but provider traffic continues | System session status | Expected ownership: host retirement does not stop the system tunnel |
| Capability is absent after reconnecting the app | Fresh provider message result | Treat as unknown until a newer generation/sequence arrives; do not infer from a read failure |
| Cleanup deadline counter increases | Provider lifecycle diagnostics | A handle exceeded the 10-second budget and was force-closed; retain aggregate evidence and inspect the owning component |

## Reproduction and verification

Run from the repository root. These commands do not install an app, start a
VPN, or change host routes/DNS.

```sh
# Core message, lifecycle, ownership, and privacy unit tests
swift test --filter RuntimeMessageCodecTests
swift test --filter TunnelRuntimeCoordinatorTests
swift test --filter ProviderAdapterContractTests
swift test --filter VPNSessionControllerTests
swift test --filter M1RuntimeCompositionTests
swift test --filter MacOSProductionRuntimeOwnershipTests
swift test --filter RuntimeDiagnosticsTests
swift test --filter SSHBootstrapErrorMappingTests

# All seven deterministic success/failure harness scenarios
make m1-runtime-harness-test

# Both shared platform provider composition roots
swift build --target ReluxTunnelIOSAdapter
swift build --target ReluxTunnelMacOSAdapter

# Generated macOS host + provider, unsigned Debug and Release builds
make macos-targets-validate

# Source diagram validation/rendering
plantuml -checkonly diagrams/TASK-260715-2rcvr0_m1-runtime-lifecycle.puml
plantuml -tsvg -o artefacts diagrams/TASK-260715-2rcvr0_m1-runtime-lifecycle.puml
```

The two SwiftPM target builds prove both shared provider roots compile. They do
not create an iOS production app/provider target. `make macos-targets-validate`
covers both build configurations of the active generated macOS provider target.
None of these builds proves runtime composition wiring, signing, installation,
launch, or iOS production availability.

## Migration boundary

M1 introduces no import, coexistence, replacement, retirement, defaults-domain,
Keychain, bundle-identity, or release migration for the legacy v0.1.0 product.
The enforced isolation and exact owner split are documented in
[`migration-isolation.md`](migration-isolation.md). M4 owns the human
coexistence decision in
[`TASK-260715-35nc5m`](../.task-board/EPIC-260716-3fyjn0_manual-validation-and-approvals/STORY-260716-2mtjdn_m4-product-decisions-and-validation/TASK-260715-35nc5m_decide-legacy-socks-coexistence-replacement-or-retirement/README.md);
M5 owns release identity, entitlements, and migration in
[`TASK-260715-1tzaed`](../.task-board/EPIC-260715-w5gzf4_release-and-distribution/STORY-260715-c1qsc6_macos-signed-distribution/TASK-260715-1tzaed_record-macos-release-identity-entitlement-and-migration-contract/README.md).

## Stable extension seams

Future work extends provider-owned seams; it must not move runtime authority to
the app.

| Milestone | Concrete handoff | Allowed extension | Preserved M1 invariant |
| --- | --- | --- | --- |
| M2 UDP | [`TASK-260715-1loqwb`](../.task-board/EPIC-260715-2lz67t_udp-relay-and-degraded-mode/STORY-260715-1nsw9p_udp-forwarding-and-associations/TASK-260715-1loqwb_implement-hev-to-relay-datagram-adapter/README.md), [`TASK-260715-3e30tx`](../.task-board/EPIC-260715-2lz67t_udp-relay-and-degraded-mode/STORY-260715-1nsw9p_udp-forwarding-and-associations/TASK-260715-3e30tx_implement-ssh-relay-frame-pump-and-backpressure/README.md), [`TASK-260715-28jdml`](../.task-board/EPIC-260715-2lz67t_udp-relay-and-degraded-mode/STORY-260715-1nsw9p_udp-forwarding-and-associations/TASK-260715-28jdml_integrate-full-mode-dns-over-relay/README.md) | Replace general-UDP deferral with provider-owned relay association/frame-pump behavior; move full-mode DNS only after relay readiness | Virtual-DNS routing remains explicit; no direct UDP fallback; reverse cleanup remains generation-owned |
| M2 capability | [`TASK-260715-3edgwz`](../.task-board/EPIC-260715-2lz67t_udp-relay-and-degraded-mode/STORY-260715-2ungml_capability-and-degraded-mode/TASK-260715-3edgwz_implement-relay-capability-negotiation-and-snapshot/README.md), [`TASK-260715-ak0s72`](../.task-board/EPIC-260715-2lz67t_udp-relay-and-degraded-mode/STORY-260715-2ungml_capability-and-degraded-mode/TASK-260715-ak0s72_implement-relay-failure-to-degraded-transition-controller/README.md), [`TASK-260715-uh8kk6`](../.task-board/EPIC-260715-2lz67t_udp-relay-and-degraded-mode/STORY-260715-2ungml_capability-and-degraded-mode/TASK-260715-uh8kk6_enforce-degraded-udp-rejection-and-no-fallback-policy/README.md), [`TASK-260715-30lv40`](../.task-board/EPIC-260715-2lz67t_udp-relay-and-degraded-mode/STORY-260715-2ungml_capability-and-degraded-mode/TASK-260715-30lv40_record-capability-state-and-reason-contract/README.md) | Negotiate relay support and publish `udp=true` / `connectedFull` only from a usable relay generation; degrade without losing TCP/safe DNS | Capability facts remain independent, versioned provider output; app only projects them |
| M2 operations | [`TASK-260715-24e2o1`](../.task-board/EPIC-260715-2lz67t_udp-relay-and-degraded-mode/STORY-260715-1nsw9p_udp-forwarding-and-associations/TASK-260715-24e2o1_document-udp-limits-metrics-and-operations/README.md) | Add finite UDP limits and aggregate metrics after behavior exists | No endpoint, association, query, or packet labels |
| M3 resilience | [`TASK-260715-1j30es`](../.task-board/EPIC-260715-2qzczm_resilience-and-performance/STORY-260715-2txwb7_path-reconnect-state-machine/TASK-260715-1j30es_implement-generation-safe-reconnect-coordinator/README.md), [`TASK-260715-3ddzdd`](../.task-board/EPIC-260715-2qzczm_resilience-and-performance/STORY-260715-2txwb7_path-reconnect-state-machine/TASK-260715-3ddzdd_integrate-reasserting-capability-restoration/README.md), [`TASK-260715-2lodgq`](../.task-board/EPIC-260715-2qzczm_resilience-and-performance/STORY-260715-2txwb7_path-reconnect-state-machine/TASK-260715-2lodgq_implement-atomic-endpoint-route-replacement/README.md) | Add generation-safe reconnect, `reasserting`, and atomic endpoint-route replacement around provider-owned generations | Stale events/snapshots cannot revive retired generations; routes and forwarding stay provider-owned |
| M3 SSH | [`TASK-260728-3cveay`](../.task-board/EPIC-260715-2qzczm_resilience-and-performance/STORY-260715-1zzt0c_windows-rekey-and-memory-controls/TASK-260728-3cveay_implement-deferred-m3-ssh-semantics-and-observability/README.md) | Add the deferred SSH semantics and finite observability behind the existing bootstrap/session seams | Selected transport/security authority remains in the production root |
| M4 product | [`TASK-260715-2a1cp7`](../.task-board/EPIC-260715-21g2pi_product-experience-and-security/STORY-260715-309t4z_connection-control-and-status-ui/TASK-260715-2a1cp7_record-connection-presentation-state-and-command-contract/README.md), [`TASK-260715-3btpxm`](../.task-board/EPIC-260715-21g2pi_product-experience-and-security/STORY-260715-309t4z_connection-control-and-status-ui/TASK-260715-3btpxm_implement-shared-connection-presentation-model/README.md), [`TASK-260715-kq7vqf`](../.task-board/EPIC-260715-21g2pi_product-experience-and-security/STORY-260715-309t4z_connection-control-and-status-ui/TASK-260715-kq7vqf_build-capability-failure-and-recovery-detail-presentation/README.md), [`TASK-260715-2o2oq0`](../.task-board/EPIC-260715-21g2pi_product-experience-and-security/STORY-260715-3tds7d_diagnostics-privacy-and-support/TASK-260715-2o2oq0_implement-versioned-diagnostic-snapshot-and-event-client/README.md) | Consume versioned state/capability/diagnostic replies and present unknown/degraded/recovery accurately | NetworkExtension status and provider facts remain separate authorities; read failure stays unknown |
| M5 delivery | [`TASK-260715-1uxx3i`](../.task-board/EPIC-260715-w5gzf4_release-and-distribution/STORY-260715-anxje6_continuous-integration-quality-gates/TASK-260715-1uxx3i_add-credential-free-apple-target-build-matrix/README.md), [`TASK-260715-1tzaed`](../.task-board/EPIC-260715-w5gzf4_release-and-distribution/STORY-260715-c1qsc6_macos-signed-distribution/TASK-260715-1tzaed_record-macos-release-identity-entitlement-and-migration-contract/README.md) | Build/sign/release the concrete targets and own migration policy | Build evidence does not silently become runtime-wiring or product-migration evidence |
