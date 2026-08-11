# Security and privacy specification

## Assets and trust boundaries

Protected assets are SSH private keys/passphrases, verified host identities,
profile metadata, user traffic, DNS queries, relay binaries, and diagnostics.

Trust boundaries:

1. containing app to packet tunnel extension;
2. Apple device to access network;
3. SSH client to the user-owned SSH server;
4. `sshd` exec session to `relux-relay`;
5. exit host to destination networks;
6. build/release system to distributed applications and relay assets.

The access network can observe SSH endpoints, timing, duration, and volume. The
exit host administrator can observe post-SSH destinations and plaintext traffic
that lacks end-to-end application encryption. Relux Works is not in the data
path for the baseline product.

## Host authentication

- Host-key verification is mandatory before user authentication succeeds.
- Profiles store a canonical hostname plus one or more approved key algorithms
  and fingerprints, with provenance and first/last-seen timestamps.
- First use presents the full SHA-256 fingerprint and an explicit trust action;
  there is no silent `StrictHostKeyChecking=no` equivalent.
- A changed host key stops the connection with a high-severity error. The user
  must inspect and explicitly replace trust; reconnect cannot auto-accept it.
- All SSH lanes in one session must present the same approved identity.

## Client credentials

- On iOS, private keys and passphrases live in the Data Protection Keychain and
  are shared only through the minimum keychain access group required by the app
  and its packet tunnel extension.
- On macOS, the root packet-tunnel provider uses a provider-owned generic-password
  item in the file-based system-domain Keychain. It resolves that Keychain with
  `SecKeychainCopyDomainDefault(kSecPreferencesDomainSystem, ...)`, scopes reads
  through an explicit one-Keychain `kSecMatchSearchList`, and matches only a
  fixed non-identifying service plus the exact opaque credential reference.
  Keychain Sharing, access-group, accessibility, ambient-search-list, and
  hard-coded Keychain-path mechanisms are not used on this path.
- macOS profile configuration travels through `providerConfiguration`; it contains
  only non-secret profile data and opaque Keychain references. The macOS host and
  root provider do not treat App Group storage as a shared credential channel.
- The macOS system-domain item is not protected by the user's login password.
  Runtime secret lifetime is bounded and mutable buffers are cleared on a
  best-effort basis; immutable Swift/framework/allocator copies cannot be proven
  zeroized.
- Key import validates format and permissions. Key generation uses platform
  cryptography and never exports silently.
- Secrets are not placed in `NETunnelProviderProtocol.providerConfiguration`,
  logs, crash annotations, shell commands, or task-board resources.
- Agent forwarding is disabled.

## Relay supply chain

- Relay assets are built from pinned source revisions in CI for the declared
  OS/architecture matrix.
- The application bundle contains a manifest with protocol version, platform,
  file size, and SHA-256 for every asset.
- Upload occurs only after SSH host verification and authentication.
- Remote installation uses private permissions, checksum verification, and
  atomic rename; a mismatch never executes.
- The relay performs a versioned handshake and reports its build identity.
- Third-party notices for HEV, hev-task-system, hev-socks5-core, lwIP, the SSH
  engine, and any relay dependency ship with the product.

## Traffic and routing safety

- Ordinary traffic and DNS fail closed on mandatory tunnel failure.
- SSH endpoint routes are narrow and derived from the actual connected endpoint.
- Malformed packet, SOCKS, SSH channel, or relay frames are rejected within
  bounded memory and do not become arbitrary allocations.
- The relay validates address families, lengths, association IDs, and datagram
  limits before opening or using sockets.
- Local internal SOCKS/bridge endpoints are not reachable as a user-configurable
  general proxy.
- QUIC blocking and degraded-mode decisions are explicit capability policies,
  not silent traffic interception.

## Diagnostics and data collection

Default logs MAY include timestamps, state transitions, lane IDs, aggregate
counts, error domains/codes, memory measurements, negotiated algorithms, relay
build identity, and redacted IP-family information.

Default logs MUST NOT include private keys, passphrases, packet payloads, DNS
names, destination hostnames/IPs, full local network addresses, shell command
stdin, or user traffic samples. A user-initiated support export applies a
documented redaction pass and previews included categories.

The baseline has no analytics or traffic telemetry. Any future telemetry is
opt-in, aggregate-only, documented in the privacy policy and in-app disclosure,
and requires a threat-model update.

## App Store privacy commitments

Before enabling the VPN, the app MUST present what data is processed, where
traffic exits, that the user controls the SSH host, and that the exit host can
observe destination metadata. This applies to **every** Relux Tunnel client: the
macOS client must satisfy it on the macOS-first goal, and the iOS client must
satisfy it unchanged when iOS resumes (ADR-024). Only the App Store submission
artifacts built on top of this disclosure are deferred (ADR-013). The privacy policy MUST state that Relux Works
does not sell, use, or disclose VPN traffic data to third parties and describe
retention/deletion for profile and support data.

Regional VPN licensing and distribution availability are product/legal gates,
not assumptions delegated to code.

## Abuse boundaries

The product connects only to infrastructure configured by the user. It does not
scan for SSH servers, provide shared exit credentials, relay inbound unsolicited
connections, or expose a server marketplace. Rate/resource limits protect both
the device and exit host from accidental exhaustion.
