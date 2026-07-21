# Security claims source

Status: publication contract for macOS-first v1. Evidence reviewed through
2026-07-21 under `TASK-260717-3ujeip`.

This is the conservative source for in-app disclosure, privacy/support copy,
public policy, release notes, and security-facing product language. It does not
grant legal, App Store, or marketing approval. The threat analysis behind these
claims is [`threat-model.md`](threat-model.md).

## 1. Publication rules

1. Copy must preserve the claim ID and evidence state during drafting and
   review. Shortening a claim must not remove its limitation.
2. **Implemented component** means the cited component behavior has tests. It
   does not authorize a claim about a shipped VPN without release composition
   and physical evidence.
3. **Contract implemented; integration gated** may be described in engineering
   documentation as a requirement, but not to users as current protection.
4. **Accepted design; release-gated** and **planned / unverified** claims must
   use future/conditional wording internally and must not appear as shipped
   behavior.
5. **Approved disclosure / non-goal** may be published before a positive
   protection claim because it limits user expectations rather than asserting a
   protection that lacks evidence.
6. No current claim is authorized as a verified shipped system-VPN guarantee.
   A release audit must replace the evidence state only after the residual gate
   is accepted.

## 2. Approved plain-language claims

| ID | Evidence state | Approved wording | Publication boundary |
| --- | --- | --- | --- |
| SC-01 | Accepted design; release-gated | “When the VPN is connected, it sends covered traffic to the SSH host you configured. Relux Works does not operate the baseline exit.” | Requires a composed provider, selected SSH transport, route/DNS evidence, and confirmation that no vendor traffic service was added |
| SC-02 | Accepted design; release-gated | “Traffic carried by the tunnel is encrypted with SSH between this device and your SSH host. Your network can still see and fingerprint the SSH connection, including its server, timing, duration, and volume.” | Requires selected-engine conformance and physical routing/DNS leak evidence; never shorten to “invisible” or “untraceable” |
| SC-03 | Approved disclosure / non-goal | “Your SSH host is the exit. Its operator can see destination metadata, DNS traffic from the exit, and any traffic that is not separately encrypted by the application.” | Always retain the plaintext and compromised-exit limitation |
| SC-04 | Contract implemented; integration gated | “Relux must accept the SSH host identity before it can use your SSH credential. A changed or rejected host key stops that connection.” | Typed contract/tests exist; requires production adapter, trust repository/UI, lane consistency, and physical authentication evidence before shipped use |
| SC-05 | Planned / unverified | “Private keys and stored passphrases are kept in the Data Protection Keychain. Shared profile storage contains references, not raw secrets.” | Prohibited until the Keychain vault, extension resolver, access groups, archive inspection, and security tests are accepted |
| SC-06 | Implemented component; release composition gated | “Relux uses bounded packet and relay parsers: malformed input is rejected without an unbounded queue or allocation.” | Supported for cited bridge/relay components; a product-wide claim requires selected SSH parsing and composed hostile-input/soak evidence |
| SC-07 | Planned / unverified | “While the VPN reports usable DNS, ordinary DNS uses only tunnel-owned upstreams. Losing safe DNS withdraws that capability instead of selecting the physical resolver.” | ADR-022 is proposed and runtime limits are blocked; requires production DNS, route teardown, and physical leak tests |
| SC-08 | Accepted design; release-gated | “Fail-closed mode is limited by macOS. The system may exclude traffic needed for DHCP, captive portals, cellular or companion services, or maintaining the VPN.” | Current coordinator admits only compatible mode; publish only with a tested OS/version exception matrix; never call this an absolute kill switch |
| SC-09 | Implemented component; release composition gated | “The VPN’s internal SOCKS listener is loopback-only, uses per-run credentials, and is not a supported user-configurable proxy.” | Do not call it process-private or impossible for another local process to probe |
| SC-10 | Accepted design; partially implemented | “The UDP relay is designed to run without root as an SSH exec/stdin/stdout child. It does not require a daemon, public listener, or SFTP product path.” | Stdio/no-listener process and protocol components exist; remote deployment, SSH frame pump, UDP composition, and install verification remain gated |
| SC-11 | Accepted design; release-gated | “If the UDP relay is unavailable, Relux may report degraded mode with TCP and safe DNS only. It does not silently send UDP outside the tunnel.” | Requires capability negotiation, degraded transition/recovery, UDP rejection, and physical tests |
| SC-12 | Implemented component plus release scan gate | “The baseline has no Relux traffic account, exit, resolver, analytics, or traffic-telemetry service. Local runtime diagnostics use bounded aggregate fields rather than packet payloads, destinations, or DNS names.” | Recheck dependencies, endpoints, logs, exports, update/support flows, and release configuration; separate user-initiated support data must be disclosed |
| SC-13 | Accepted design; planned implementation | “A future macOS self-update channel must accept only an EdDSA-signed appcast and an already-notarized Developer ID payload.” | ADR-018 is accepted, but Sparkle, appcast generation, release jobs, rollback, key custody, and tests are absent; do not say self-update is available |
| SC-14 | Approved disclosure / release-gated functional effect | “A destination reached through the tunnel sees the SSH exit host’s IP, plus anything the application itself sends. It does not normally see the device’s access-network IP.” | Requires physical IPv4/IPv6 routing evidence and must not imply anonymity or protection from application tracking |

## 3. Does-hide / does-not-hide wording

Use this matrix only with the SC-01/SC-02 release gates intact.

| Observer | Approved “does hide” wording | Required “does not hide” wording |
| --- | --- | --- |
| Access network / ISP | “Covered traffic inside SSH hides its destinations, DNS messages, and payloads from the access network.” | “The access network still sees the SSH server and SSH-identifiable metadata, timing, duration, and volume; it may see bootstrap DNS and system-excluded traffic.” |
| Exit-host operator | “Application content with its own end-to-end encryption remains protected by that application protocol.” | “The exit sees destination metadata, resolver traffic, timing/volume, and all plaintext after SSH ends.” |
| Relux Works baseline | “No Relux-operated traffic service receives baseline tunnel traffic.” | “This does not cover data deliberately sent through updates, support, vulnerability reports, or ordinary Relux services.” |
| Destination service | “The destination normally sees the exit IP instead of the access-network IP.” | “The destination still sees application content, accounts, identifiers, timing, and tracking data the application sends.” |
| Apple OS / compromised device | No positive hiding claim is approved. | “Relux does not protect traffic or credentials from the trusted OS, a compromised device, or a privileged local account.” |

## 4. Prohibited claims

The following wording, or any wording with the same implication, is prohibited:

| ID | Prohibited claim | Why it is prohibited |
| --- | --- | --- |
| PC-01 | “Anonymous,” “untraceable,” “unlinkable,” or “hides who you are” | Single-hop SSH exposes a stable exit and fingerprintable metadata; there is no mixing or anonymity system |
| PC-02 | “Looks like normal web traffic,” “DPI-proof,” “stealth,” or “cannot be blocked” | SSH remains visible and fingerprintable and can be throttled or blocked |
| PC-03 | “End-to-end encrypts all traffic” or “the exit cannot read your traffic” | SSH protection ends at the exit; plaintext remains visible there |
| PC-04 | “Relux Works can never see any data” | Baseline tunnel traffic avoids Relux services, but separate update, support, report, or ordinary service interactions may disclose data |
| PC-05 | “Zero logs” or “collects nothing” | Bounded local operational diagnostics exist; future user-initiated support exports are separate disclosed flows |
| PC-06 | “Absolute kill switch,” “zero leaks,” or “no packet can ever escape” | Apple controls platform exceptions and current fail-closed implementation/physical evidence is absent |
| PC-07 | “DNS can never leak” | This requires production DNS/route composition and physical evidence; bootstrap DNS and OS-excluded traffic must be disclosed |
| PC-08 | “Host-key verification protects every connection” | Only the neutral contract/tests exist; production SSH/trust integration is not accepted |
| PC-09 | “Keys are stored only in Keychain” as a current feature | The production vault, access groups, and extension resolver are not implemented |
| PC-10 | “UDP always works” or “full mode is guaranteed” | Relay availability is conditional and degraded TCP plus safe DNS is an explicit product state |
| PC-11 | “The relay cannot be tampered with” | Component/tooling controls exist, but remote install, embedding, release provenance, and compromised-exit risks remain |
| PC-12 | “The internal proxy is inaccessible to all local processes” | It is an authenticated loopback socket, not an OS-enforced process-private channel |
| PC-13 | “No SFTP code exists anywhere” | The product contract does not use SFTP, but a candidate library artifact may contain unused SFTP APIs; claim only that the product path does not require/use it |
| PC-14 | “Signed automatic updates are available” | ADR-018 is design intent; Sparkle/appcast/release implementation and tests are not present |
| PC-15 | “Independently audited,” “penetration tested,” “Apple approved,” or “App Store compliant” | This task performs documentation/code evidence review only; external audit, entitlement, legal, and review gates remain open |
| PC-16 | “Relux protects you from a compromised exit or device” | Those actors are explicit non-goals |

## 5. Claim-to-source and implementation crosswalk

“No production evidence” is an explicit evidence result, not permission to
infer behavior from an interface or test fake.

| Claim | Accepted design/spec source | Current implementation evidence | Residual evidence gate |
| --- | --- | --- | --- |
| SC-01 | [`architecture.md`](architecture.md), [`product.md`](product.md), ADR-001/005 in [`decisions.md`](decisions.md) | Provider/runtime libraries exist, but [`MacOSProviderCompositionRoot.swift`](../Sources/ReluxTunnelMacOSAdapter/MacOSProviderCompositionRoot.swift) states that a concrete provider subclass is later work | Production provider, selected SSH adapter, TCP/DNS/routes, physical exit evidence |
| SC-02 | [`architecture.md`](architecture.md), [`ssh-transport.md`](ssh-transport.md), [`security-privacy.md`](security-privacy.md) | Candidate-neutral SSH contract only: [`SSHContracts.swift`](../Sources/ReluxTunnelCore/SSHContracts.swift); both candidate adapters are blocked and selection task `TASK-260715-1gjxer` is backlog | Selected-engine conformance, real-host authentication, routing/DNS captures |
| SC-03 | [`architecture.md`](architecture.md), [`security-privacy.md`](security-privacy.md) | Inherent boundary of SSH termination; no implementation can remove exit visibility without a new end-to-end design | Preserve disclosure in UI/policy; test no contradictory copy |
| SC-04 | [`security-privacy.md`](security-privacy.md), [`ssh-transport.md`](ssh-transport.md) | Host acceptance is a typed prerequisite for credentials in [`SSHContracts.swift`](../Sources/ReluxTunnelCore/SSHContracts.swift), covered by [`SSHTransportContractTests.swift`](../Tests/ReluxTunnelCoreTests/SSHTransportContractTests.swift) | Production adapter, trust repository/UI, lane consistency, physical auth matrix |
| SC-05 | [`security-privacy.md`](security-privacy.md), [`architecture.md`](architecture.md) | Opaque reference types exist, but there is no production Keychain vault or extension credential resolver | `TASK-260715-379cpk`, `TASK-260715-1o9wjz`, access-group/archive/security tests |
| SC-06 | ADR-003/009/021, [`packet-plane.md`](packet-plane.md), [`relay-protocol.md`](relay-protocol.md) | [`PacketFlowBridge.swift`](../Sources/ReluxTunnelCore/PacketFlowBridge.swift), relay codecs/session under [`RelayProtocol`](../Sources/ReluxTunnelCore/RelayProtocol), and Go protocol/UDP code under [`relay/internal`](../relay/internal) have bounded tests | Selected SSH parser, composed fuzz/soak, release memory evidence |
| SC-07 | [`routing-dns-lifecycle.md`](routing-dns-lifecycle.md), [`security-privacy.md`](security-privacy.md); ADR-022 is Proposed | [`TunnelRuntimeCoordinator.swift`](../Sources/ReluxTunnelCore/TunnelRuntimeCoordinator.swift) requires an injected healthy safe-DNS consumer before settings, but no production DNS factory/settings composition exists | `TASK-260721-3miqh4` authorization, resolver/profile/runtime tasks, route teardown and macOS leak matrix |
| SC-08 | ADR-012, [`routing-dns-lifecycle.md`](routing-dns-lifecycle.md) | VPN-manager adapters preserve `includeAllNetworks`, but [`TunnelRuntimeCoordinator.swift`](../Sources/ReluxTunnelCore/TunnelRuntimeCoordinator.swift) currently accepts only compatible route mode | Fail-closed settings/lifecycle implementation and versioned physical exception evidence |
| SC-09 | ADR-003/004, [`packet-plane.md`](packet-plane.md) | [`HEVSOCKSBoundary.swift`](../Sources/ReluxTunnelNativeAdapter/HEVSOCKSBoundary.swift) implements loopback-only per-run authentication with bounded pending work; tests live in [`HEVIntegrationTests.swift`](../Tests/ReluxTunnelNativeAdapterTests/HEVIntegrationTests.swift) | Preserve credentials and verify composed provider behavior; retain local-process residual risk |
| SC-10 | ADR-005/006, [`relay-protocol.md`](relay-protocol.md), [`ssh-transport.md`](ssh-transport.md) | [`relux-relay`](../relay/cmd/relux-relay/main.go) accepts bounded stdio/identity modes; [`stdio/session.go`](../relay/internal/stdio/session.go) starts no listener; SSH contract offers exec/upload and no SFTP API | Remote deploy/install, exec frame pump, stdio-to-UDP composition, release asset verification |
| SC-11 | ADR-007, [`routing-dns-lifecycle.md`](routing-dns-lifecycle.md) | Lifecycle/capability model types exist, but the current coordinator exposes usable TCP/DNS only and relay capability controllers are backlog | Full/degraded controller, UDP rejection, restoration, and physical tests |
| SC-12 | [`security-privacy.md`](security-privacy.md), [`architecture.md`](architecture.md) | [`RuntimeDiagnostics.swift`](../Sources/ReluxTunnelCore/RuntimeDiagnostics.swift) uses finite aggregate schemas; repository package/workflow inspection finds no baseline analytics or vendor traffic client | Release endpoint/dependency/log scan; support export redaction/preview/retention and privacy approval |
| SC-13 | ADR-018, [`platform-distribution.md`](platform-distribution.md) | No Sparkle dependency, appcast generation, update target, or release-update workflow is present in [`Package.swift`](../Package.swift) or current CI | `TASK-260717-1mt4e7`, `TASK-260717-a8uhro`, `TASK-260717-s4ox20`, key custody and notarized release evidence |
| SC-14 | [`product.md`](product.md), [`architecture.md`](architecture.md), [`validation.md`](validation.md) | Intended exit topology only; no physical IPv4/IPv6 exit validation exists | macOS routing/DNS/exit tests and privacy-copy audit |

## 6. Release evidence gates

Before changing any positive claim to **verified release claim**, a fresh release
audit must record:

- the exact source revision, dependency locks, selected SSH engine, application
  and relay artifact identities, and accepted ADR statuses;
- host-key-before-auth results against the production adapter and host-trust
  repository, including changed/revoked/lane-mismatch cases;
- Keychain/App Group/entitlement/archive inspection proving raw credentials do
  not enter provider configuration, logs, diagnostics, or artifacts;
- macOS IPv4, IPv6, DNS, bootstrap, reconnect, degraded, route-exception, and
  platform-scoped fail-closed captures on named supported OS versions;
- relay deployment, checksum/identity mismatch, stdio-to-UDP composition,
  no-listener/rootless behavior, resource, fuzz, and cleanup results;
- diagnostic and support-export redaction/retention results and a release scan
  for telemetry, vendor endpoints, payloads, destination fields, and secrets;
- Developer ID, notarization, appcast signature, downgrade/rollback, withdrawal,
  and key-rotation results if self-update is enabled; and
- independent claims review against the actual candidate. Legal, App Store, and
  external security approval remain separate gates.

## 7. Downstream consumers and change control

The following tasks must reference this document and preserve claim IDs:

- `TASK-260715-6qqmsz` — VPN privacy disclosure and zero-telemetry UI;
- `TASK-260715-2gwfaw` — VPN privacy, retention, and support copy; and
- `TASK-260715-2k812u` — versioned public VPN privacy policy.

Any wording change, new positive claim, evidence-state promotion, new service or
telemetry flow, or failed release gate requires a same-change update to this
document and [`threat-model.md`](threat-model.md). Evidence-state promotion must
name the accepted task/review outcome and exact implementation/validation
artifact; design intent alone is not sufficient.
