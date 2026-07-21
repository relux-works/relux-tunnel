# macOS-first v1 threat model

Status: maintained security specification. Evidence reviewed through 2026-07-21
under `TASK-260717-3ujeip`.

This document models the target macOS-first system VPN and the repository state
that exists today. It is not a statement that every mitigation is shipped. The
plain-language publication contract is
[`security-claims.md`](security-claims.md).

## 1. Scope and evidence rules

The baseline product makes a user-configured SSH host the network exit for a
macOS device. The target packet tunnel terminates device TCP in HEV/lwIP, maps
TCP flows to SSH `direct-tcpip` channels, and maps UDP to a rootless relay over
an SSH exec channel. Relux Works does not operate an exit service in this
baseline.

The following evidence labels are binding throughout this document:

- **Implemented and tested**: production-path component code and repository
  tests exist for the stated boundary. This does not by itself prove a shipped
  application or an end-to-end release claim.
- **Contract implemented**: typed interfaces, ordering, or policy tests exist,
  but a production adapter or end-to-end composition is absent.
- **Accepted design**: an accepted ADR or normative specification requires the
  behavior, but current implementation evidence is incomplete.
- **Planned / evidence-gated**: the behavior is specified or proposed but may
  not be described as shipped until the named gate is accepted.

The repository does not yet contain a shippable system-VPN application or a
concrete `NEPacketTunnelProvider` subclass. The packet bridge, HEV integration,
provider/runtime coordination, VPN-manager repository, SSH-neutral contracts,
relay protocol and UDP components, and bounded diagnostics have implementation
evidence. Production SSH selection and integration, profile/Keychain storage,
DNS and route composition, relay deployment and frame-pump composition,
full/degraded recovery, physical leak validation, signed self-update, and the
release pipeline remain incomplete or evidence-gated.

## 2. Assets

| Asset | Security objective |
| --- | --- |
| SSH private keys and passphrases | Confidentiality, minimum lifetime, Keychain-only persistence |
| Approved SSH host identities | Integrity, provenance, explicit replacement, lane consistency |
| Profile and provider configuration | Integrity, versioning, non-secret storage, least-data publication |
| Live TCP, UDP, and DNS traffic | Confidentiality and integrity from device to exit; bounded availability |
| Route, DNS, and capability state | Accurate system state; no claim of protection after capability loss |
| Internal packet and SOCKS boundaries | Local isolation, authentication, bounded queues and parsers |
| Relay executable, protocol, and manifest | Integrity, authenticity, bounded behavior, version compatibility |
| Diagnostics and support exports | Confidentiality, bounded retention, user review before disclosure |
| Application, dependencies, and update payloads | Source-to-artifact integrity, authenticity, rollback control |
| CI, Developer ID, notarization, provisioning, and update-signing credentials | Confidentiality, least privilege, auditable use and revocation |
| Extension memory, descriptors, tasks, channels, and relay associations | Bounded consumption and deterministic cleanup |

## 3. Data flows and implementation state

| ID | Flow | Boundary crossed | Repository state |
| --- | --- | --- | --- |
| DF-01 | The containing app publishes a versioned non-secret profile reference and controls the VPN session | App to packet-tunnel extension | VPN-manager repository and provider-message contracts are implemented and tested; profile publication and a concrete provider target are planned |
| DF-02 | The extension resolves opaque references to host trust and SSH credentials | App Group and Keychain access groups | Typed references exist; production profile, trust, and Keychain repositories are planned |
| DF-03 | The extension resolves and connects to the SSH endpoint on the physical path before default tunnel routes | Device to access network | Accepted design; endpoint bootstrap, exclusion, and physical-path validation are planned |
| DF-04 | The provider exchanges IP packets with HEV/lwIP through a nonblocking `AF_UNIX/SOCK_DGRAM` bridge | Apple packet flow to private packet plane | Implemented and tested as a component; physical provider integration remains gated |
| DF-05 | HEV TCP requests open SSH `direct-tcpip` channels to destinations | Internal SOCKS boundary to authenticated SSH | SOCKS boundary and SSH contracts are implemented; selected SSH adapter and end-to-end TCP path are not |
| DF-06 | HEV UDP records cross the SSH exec stream and the relay opens UDP sockets on the exit | Internal SOCKS to relay to destination network | Codecs, association ownership, relay protocol, and UDP I/O are implemented and tested separately; SSH frame pump, deployment, and stdio-to-UDP composition are planned |
| DF-07 | DNS uses configured numeric exit-resolver endpoints through relay UDP with bounded TCP fallback | Packet plane to SSH exit resolver | Policy is proposed and implementation is blocked on production-authorized limits and selected-SSH evidence; no physical fallback is permitted by design |
| DF-08 | The app uploads and launches the relay through exec stdin, then verifies identity and protocol | Authenticated SSH session to user account | Rootless stdio entrypoint and artifact verification tooling exist; remote install/upload/launch composition is planned; SFTP is outside the transport contract |
| DF-09 | Typed aggregate runtime diagnostics return to the containing app and may enter a user-created support export | Extension to app to user-selected recipient | Bounded typed runtime diagnostics are implemented; support-export redaction, preview, retention, and sharing are planned |
| DF-10 | CI builds application/relay artifacts and a macOS app fetches a signed update | Build system and update channel to device | Sparkle 2.9.4, signed-feed/payload, already-notarized final-DMG, channel, rollback, key, privacy, and system-extension lifecycle contracts are accepted under TASK-260717-2uyfn5; integration, release CI, credentials, publication, and physical evidence remain planned |

## 4. Trust boundaries

1. **Containing app to packet-tunnel extension.** Only versioned non-secret
   configuration references and bounded control/diagnostic messages may cross.
2. **Provider to Apple networking APIs.** `NEPacketTunnelFlow`, network settings,
   route exceptions, and system-excluded traffic are controlled partly by the
   OS, not solely by Relux.
3. **Packet flow to HEV/lwIP and internal SOCKS.** The packet bridge is private;
   the current SOCKS boundary is loopback-only and protected by per-run
   credentials, but it is still a local socket rather than an OS-enforced
   process-private channel.
4. **Apple device to access network.** The access network carries SSH bootstrap
   DNS/connect traffic, SSH metadata, and any traffic the OS excludes from the
   tunnel.
5. **SSH client to user-configured `sshd`.** Host identity must be accepted
   before credentials are requested; SSH protects payload only to this host.
6. **`sshd` exec session to `relux-relay`.** The relay inherits the security of
   the authenticated user account and the exec/stdin/stdout channel.
7. **Exit host to DNS resolver and destination networks.** SSH protection has
   ended. Application-layer encryption, if any, is the application's concern.
8. **Build/release system to distributed artifacts and update feed.** Source,
   dependency, CI, signing, notarization, appcast, and rollback authorities meet.
9. **Diagnostics/support boundary.** Local aggregate state becomes disclosed
   data only when an export is constructed and the user shares it.

Relux Works is deliberately absent from the baseline traffic path. Adding a
vendor account, tunnel broker, resolver, relay, exit, analytics endpoint, or
traffic-processing service creates a new trust boundary and invalidates that
assumption.

## 5. Adversaries, threats, and controls

### A. Access-network, ISP, or transit observer

The observer can see the SSH server IP and port, connection timing, duration,
volume, loss patterns, and enough protocol behavior to identify or suspect SSH.
It may see the initial DNS lookup for an SSH hostname before tunnel routes are
installed. It can block, throttle, reset, or fingerprint the SSH connection.

If the release candidate proves that all advertised traffic is carried inside
authenticated SSH, the observer does not see those tunneled destination
addresses, tunneled DNS messages, or payloads. This is a release-gated claim,
not current end-to-end evidence. SSH is not an anonymity, traffic-shaping, DPI
evasion, or censorship-circumvention layer.

### B. SSH server impersonator or on-path attacker

An attacker may answer at the expected endpoint and attempt to obtain
credentials or become the exit. The SSH contract computes SHA-256 host-key
evidence and makes credential acquisition depend on an accepting host decision.
Contract tests cover accepted and rejected decisions. The production host-trust
repository, user approval flow, lane-consistency enforcement, and selected SSH
adapter remain unverified, so “host verification is shipped” is prohibited.

First use remains trust on first use unless the user verifies the fingerprint
through an independent channel. A compromised approved key or unsafe user
approval defeats this boundary.

### C. Exit-host operator or compromised exit account

The exit sees destination IP addresses and ports, resolver requests sent from
the exit, traffic timing and volume, and application plaintext that lacks its
own end-to-end encryption. It can log, alter, block, reroute, or inject that
traffic. It can tamper with files in the user's account or the relay process.

The design verifies the uploaded relay asset and protocol identity, but it does
not attest the operating system or protect traffic after SSH termination. The
user is trusting the selected host and its administrator.

### D. Hostile relay, SSH peer, destination, or packet input

Malformed packet, SOCKS, SSH, relay-envelope, datagram, resolver, and lifecycle
inputs can target parser safety, allocations, queues, descriptors, and stale
generation reuse. Packet-bridge bounds, SSH-neutral bounds, relay codecs,
association ownership, UDP I/O, and cleanup have component tests. The complete
composed path and production SSH parser still require integration, fuzz, soak,
and physical-memory evidence.

### E. Malicious local process or another local user

A local process may probe the loopback SOCKS listener, read weakly protected
configuration, scrape logs, or race the containing app/provider. The implemented
SOCKS boundary binds to loopback, generates per-run credentials, bounds pending
authentication, and does not expose a supported public-proxy configuration.
It is not equivalent to a process-private socket; compromise of the process,
credential memory, or a sufficiently privileged local account remains in scope
as residual risk.

### F. Lost, stolen, or compromised device

The accepted design keeps private keys and passphrases in the Data Protection
Keychain and non-secret configuration in the App Group. That storage path is
not implemented yet. When implemented, it still inherits device-unlock,
Keychain-access-group, backup, malware, and OS-compromise risks. No claim covers
a compromised Apple device.

### G. Supply-chain, CI, maintainer, and update attacker

An attacker may alter dependencies, build tools, relay assets, application
archives, signing jobs, the appcast, or release metadata. The repository pins
and verifies native dependencies and a credential-isolated relay toolchain, and
CI exercises relay builds. Relay embedding, application SBOM/secret gates,
Developer ID/notarization jobs, signed appcast generation, rollback controls,
and key-rotation drills remain planned. ADR-018 is accepted design intent, not
evidence that self-update is available.

### H. Relux Works insider or future service operator

The baseline architecture has no Relux-operated exit, resolver, account, or
traffic telemetry service. Typed runtime diagnostics contain finite aggregate
fields rather than payload, destination, or DNS-name fields. This does not mean
Relux Works can never receive data: distribution infrastructure, a future
opt-in support export, a vulnerability report, or ordinary visits to a Relux
service are separate flows. Any vendor traffic service or telemetry requires a
new threat-model revision and disclosure before implementation.

### I. Abusive user or compromised client

The user can direct their own exit host toward third-party destinations. The
product does not make that activity anonymous, provide shared credentials,
operate a public exit, accept unsolicited inbound relays, or prevent destination
services and the exit operator from applying abuse controls. Resource caps
protect availability; they are not an authorization system for destination use.

## 6. Mitigation and evidence ledger

| ID | Mitigation | State and evidence | Residual gate |
| --- | --- | --- | --- |
| M-01 | Host-key acceptance precedes credential use | Contract implemented in `SSHContracts.swift` and tested in `SSHTransportContractTests.swift` | Select and integrate a production SSH adapter; implement trust storage/UI and physical authentication evidence |
| M-02 | Secrets persist only in Keychain; App Group data is non-secret | Accepted design in `security-privacy.md` | Implement and test the credential vault, profile publisher, extension resolver, access groups, and archive inspection |
| M-03 | Packet and relay inputs are bounded and generation-owned | Implemented and tested for packet bridge, relay codecs/session, association registry, and UDP I/O | Add the selected SSH parser and composed hostile-input/soak evidence |
| M-04 | Ordinary DNS has only tunnel-owned upstreams and fails safe on loss | Planned / evidence-gated; coordinator requires a healthy safe-DNS dependency before routes | ADR-022 is proposed; production limits, resolver/profile/runtime code, route teardown, and physical leak tests remain blocked or backlog |
| M-05 | SSH endpoint routing is narrow and tunnel settings apply only after SSH/TCP/DNS readiness | Contract implemented in the coordinator; real settings builder/applier absent | Implement endpoint bootstrap/exclusions and pass macOS routing/leak matrices |
| M-06 | Internal SOCKS is loopback-only, per-run authenticated, and not a user proxy | Implemented and tested in `HEVSOCKSBoundary.swift` | Preserve credential secrecy and validate the composed provider boundary |
| M-07 | Relay uses rootless exec/stdin/stdout, no daemon or public listener, and no product SFTP path | Stdio entrypoint and no-listener relay process implemented; exec/upload contract excludes SFTP | Implement shell-safe deployment, upload, checksum, launch, frame pump, and stdio-to-UDP composition |
| M-08 | Relay artifacts are pinned, reproducible, identified, and verified before use | Portable toolchain, identity/self-hash, protocol vectors, and partial CI implemented | Build accepted four-asset release bundle, embed manifest, implement remote verification/install, SBOM and independent reproducibility gates |
| M-09 | Full mode may degrade to TCP plus safe DNS without leaking UDP | Accepted design in ADR-007; model types exist | Implement capability negotiation, degraded transition/recovery, UDP rejection, and physical full/degraded tests |
| M-10 | Compatible and platform-scoped fail-closed route modes are explicit | Accepted design in ADR-012; VPN-manager fields exist | Current coordinator accepts only compatible mode; implement route policy and validate documented OS exceptions |
| M-11 | Diagnostics use finite aggregate schemas without payload/destination fields | Implemented and tested for runtime snapshots | Implement export redaction, preview, retention, security tests, and downstream privacy approval |
| M-12 | macOS updates require a signed feed and EdDSA payload over an already-notarized Developer ID DMG | Exact Sparkle 2.9.4, fail-closed feed, forward-rollback, two-root key, privacy, and host/system-extension lifecycle design accepted in ADR-018 and `TASK-260717-2uyfn5` | Implement host/XPC integration and appcast/release jobs; perform human key ceremony, privacy audit, withdrawal/rotation drill, and physical clean-install/update/system-extension gates before any shipped claim |

## 7. Does-hide / does-not-hide matrix

This matrix is valid for the target VPN only after the corresponding release
candidate passes SSH, routing, DNS, and physical leak gates. It must not be used
to describe the current component-only repository as a shipped VPN.

| Observer | What the target can hide after release gates pass | What remains visible or controllable |
| --- | --- | --- |
| Access network / ISP | Destinations, DNS messages, and payloads actually carried inside SSH | SSH server IP/port, SSH-identifiable metadata, timing, duration, volume, blocking; bootstrap hostname DNS; traffic excluded by the OS |
| Exit-host operator | Application content protected by separate end-to-end encryption | Destination metadata, resolver traffic, timing/volume, and all application plaintext after SSH termination |
| Relux Works baseline | Tunnel traffic, DNS, destinations, and payloads, because no Relux traffic service is in the baseline path | Data deliberately sent through separate distribution, support, vulnerability-report, or ordinary Relux-service interactions |
| Destination service | The device's access-network IP when traffic exits through the SSH host | Exit-host IP, timing, application identifiers/content, and any account or tracking data the application sends |
| Apple OS / compromised device | No protection is claimed against the trusted OS or device owner | Network settings, packet flow, local process memory, credentials available under OS policy, and application traffic before tunnel encryption |

## 8. Fail-closed and availability semantics

- **Compatible mode** is the only route mode currently admitted by the shared
  runtime coordinator. Its production settings implementation is still absent.
- **Fail-closed mode** is an accepted platform-scoped design using
  `includeAllNetworks` where supported, but it is not implemented end to end.
- Apple may exclude DHCP, captive-portal negotiation, certain cellular or
  companion-device services, and traffic needed to maintain the VPN. OS behavior
  can change by release.
- Mandatory SSH, TCP, safe-DNS, packet-plane, or settings failure must withdraw
  advertised capability and tear down settings rather than create a physical
  fallback. The coordinator implements this ownership rule against injected
  dependencies; real route/DNS evidence is pending.
- “Kill switch,” “zero leaks,” and “all packets under every condition” are
  prohibited claims. The approved term is **platform-scoped fail-closed** with
  the tested OS exceptions named.

## 9. Abuse boundaries

- The user supplies the SSH host and credentials. There is no shared exit pool,
  server marketplace, credential broker, or Relux-operated exit in baseline v1.
- The product opens outbound `direct-tcpip` channels and relay UDP sockets for
  client traffic. It does not expose inbound forwarding or unsolicited relays.
- The internal SOCKS listener is an authenticated implementation boundary, not
  a supported proxy endpoint for browsers, LAN clients, or third parties.
- Relay deployment is limited to reviewed exec commands and stdin/stdout. No
  SFTP, interactive shell, agent forwarding, arbitrary command UI, root daemon,
  public listener, or firewall automation belongs to the baseline.
- Association, frame, queue, timer, resolver, channel, memory, and diagnostic
  limits protect resource availability. They do not certify remote destinations
  or prevent abuse originating from a compromised client or exit.

## 10. Explicit non-goals

- Anonymity, unlinkability, mixing, multi-hop privacy, or hiding the SSH endpoint.
- DPI evasion, protocol obfuscation, censorship circumvention, or guaranteed
  availability against an observer that blocks SSH.
- End-to-end encryption beyond the selected exit host; applications still need
  TLS or another application-layer protection.
- Protection from a malicious/compromised exit host, Apple device, privileged
  local account, destination service, or application endpoint.
- A hosted VPN, shared exit, vendor resolver, or Relux-operated traffic service.
- Absolute kill-switch or zero-packet-leak semantics across all Apple OS states.
- DNSSEC validation, fake DNS, tunneled DoH, inbound forwarding, SFTP, or an
  interactive remote shell in baseline v1.
- Independent security audit, external penetration test, or legal/App Store
  approval; none has been performed or granted by this task.

## 11. Residual risk and open evidence gates

- SSH metadata remains visible and fingerprintable; the connection can be
  blocked or correlated by timing and volume.
- An SSH hostname may require a physical-path bootstrap DNS lookup. Pinning or
  caching an endpoint changes availability and rotation tradeoffs and is not a
  blanket privacy guarantee.
- The exit host sees destination metadata, DNS/resolver traffic, and plaintext.
- First-use host trust is vulnerable when the fingerprint is not verified out
  of band.
- The production SSH engine is unselected (`TASK-260715-1gjxer`); both candidate
  adapters remain blocked, so host verification, channel, rekey, and memory
  guarantees are not release claims.
- DNS runtime limits remain non-authoritative and blocked
  (`TASK-260721-3miqh4`); ADR-022 remains proposed.
- Exact route exclusions and platform-scoped fail-closed behavior lack physical
  macOS evidence.
- The loopback SOCKS boundary is hardened but not process-private.
- Relay protocol and UDP components are not yet composed through the SSH exec
  stream or installed on a remote host.
- Keychain, App Group, profile, signing identity, and entitlement bindings are
  not yet implemented and accepted as a release configuration.
- CI/signing/update credentials remain high-impact organizational trust roots;
  application update generation and rollback evidence is absent.
- No external penetration test, independent protocol audit, or shipped-product
  privacy verification exists.
- Apple platform-intent gate A0 and provisioning gate P0 remain release
  boundaries; implementation evidence does not imply entitlement or review
  acceptance.

## 12. Change control

Update this threat model and [`security-claims.md`](security-claims.md) in the
same change when any of the following occurs:

- a data flow, observer, asset, trust boundary, privilege, listener, inbound
  path, vendor service, account, resolver, analytics, or telemetry path is added;
- the SSH engine, host-trust order, authentication method, lane policy, rekey
  behavior, relay transport, protocol version, SFTP boundary, or shell surface
  changes;
- DNS bootstrap, resolver kinds, route modes, OS exceptions, endpoint exclusion,
  degraded behavior, or capability/failure semantics change;
- profile, App Group, Keychain, diagnostic, support-export, logging, retention,
  redaction, or privacy behavior changes;
- relay/application dependency, build, CI, signing, notarization, appcast,
  update, rollback, or credential-custody controls change;
- a planned mitigation obtains implementation evidence, an evidence gate fails,
  or a release claim is added, removed, or reworded.

The downstream consumers are `TASK-260715-6qqmsz` (VPN privacy disclosure and
zero-telemetry UI), `TASK-260715-2gwfaw` (privacy, retention, and support copy),
and `TASK-260715-2k812u` (public VPN privacy policy). They must consume claim IDs
from `security-claims.md`, retain the evidence state, and may not promote a
planned claim to shipped behavior.
