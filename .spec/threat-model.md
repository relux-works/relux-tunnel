# Threat model and security-claims specification

Status: seed. Completed and maintained under board task
`TASK-260717-3ujeip` (author-threat-model-and-user-facing-security-claims-doc).
This document is the single source from which the in-app disclosure, the App
Store privacy copy, and the public privacy policy derive. Every claim here MUST
be provable from the design in `architecture.md`, `security-privacy.md`,
`routing-dns-lifecycle.md`, and `decisions.md`. If code or design diverges, this
document changes first.

## 1. Product in one sentence

Relux Proxy makes a user-owned SSH host the network exit for a whole Apple
device; to the OS it is a system VPN, and on the external network its transport
is one or more authenticated SSH connections to that host.

## 2. Assets

- SSH private keys and passphrases.
- Verified host identities (known-hosts equivalent).
- Profile metadata (hostnames, accounts, ports, options).
- Live user traffic (TCP, UDP, DNS) while tunneled.
- Relay binaries and their integrity manifest.
- Update payloads and the update-signing keys (macOS self-update).
- Diagnostics and support exports.
- The Developer ID / notarization and App Store signing credentials.

## 3. Trust boundaries

Numbered to match `security-privacy.md`:

1. Containing app ↔ packet tunnel extension (App Group + Keychain access group).
2. Apple device ↔ access network (Wi-Fi/cellular/on-path observers).
3. SSH client (inside the extension) ↔ user-owned `sshd`.
4. `sshd` exec session ↔ `relux-relay`.
5. Exit host ↔ destination networks.
6. Build/release system ↔ distributed app, relay assets, and update feed.

The UI process is outside the data path: the SSH transport, packet bridge, and
relay protocol all live in the extension (ADR-001).

## 4. Adversaries and what the design does about them

### A. On-path / local-network observer (café Wi‑Fi, ISP, transit)
- **Sees:** that the device holds one or a few long-lived TCP/SSH connections to
  a specific host:port; timing, duration, byte volume; the initial DNS lookup of
  the SSH hostname if resolved in the clear; SNI/metadata of any traffic that the
  design intentionally leaves outside the tunnel (system-reserved services).
- **Does NOT see:** tunneled destination addresses, DNS queries, or payloads —
  they are inside the SSH stream.
- **Mitigations:** all user TCP/UDP/DNS ride inside SSH; DNS is tunnel-owned and
  fails closed (`routing-dns-lifecycle.md`); the SSH endpoint route is narrow and
  derived from the connected endpoint; the server IP can be pinned so steady-state
  traffic needs no in-clear resolution.
- **Explicit non-goal:** this is **not** a DPI-evasion or censorship-circumvention
  tool. A long-lived, high-volume SSH session is trivially fingerprintable as SSH
  by traffic analysis. We claim confidentiality of tunneled content and exit
  relocation, not unobservability of the SSH connection itself.

### B. Exit-host operator (the user's own machine, or whoever controls it)
- **Sees:** everything after SSH termination — destination IPs/hostnames, DNS,
  and any traffic without end-to-end application encryption (i.e. plaintext).
- **Design stance:** this is the intended trust model. The user chooses to exit
  through a machine they administer. The product does not add end-to-end
  protection beyond what each application already provides.
- **Claim:** we tell the user plainly that the exit host can observe destination
  metadata and plaintext, and that they are trusting that machine.

### C. Malicious or compromised remote host (impersonation / MITM of the SSH server)
- **Threat:** an attacker answers on the expected host:port and tries to become
  the exit.
- **Mitigations:** mandatory host-key verification before user auth; full SHA-256
  fingerprint shown on first use with an explicit trust action; a changed key
  hard-stops with a high-severity error and never auto-accepts; every SSH lane in
  a session must present the same approved identity (`security-privacy.md`).
- **Residual:** first-use trust is TOFU unless the user verifies the fingerprint
  out of band. We surface the fingerprint; we cannot force out-of-band checking.

### D. Hostile data from an otherwise-authenticated peer (relay, sshd, destinations)
- **Threat:** malformed packets, SOCKS frames, SSH channel data, or relay frames
  attempting memory bl-up or logic abuse.
- **Mitigations:** all parsers reject malformed input within bounded memory; the
  relay validates address families, lengths, association IDs, and datagram limits
  before touching sockets; the internal SOCKS/bridge endpoint is not reachable as
  a general user proxy (ADR-003, `security-privacy.md`).

### E. Supply chain (relay assets, dependencies, CI, update feed)
- **Threats:** a tampered relay binary executed on the exit host; a poisoned
  dependency; a malicious update pushed to users.
- **Mitigations:** relay assets built from pinned revisions in CI, shipped with a
  per-asset SHA-256 manifest; remote install uses private perms, checksum
  verification, and atomic rename, and a mismatch never executes; SBOM, license,
  secret, and vulnerability gates in CI; macOS update payloads are already-
  notarized Developer ID builds and the appcast is EdDSA-signed with a key held
  in the same custody as signing credentials; a bad signature fails closed.
- **Residual:** the exit-host account's own integrity is the user's
  responsibility; we verify what we upload, not the whole host.

### F. Lost or stolen device
- **Mitigations:** private keys and passphrases live in the Data Protection
  Keychain, shared only through the minimum access group; App Group storage holds
  only non-secret config and opaque Keychain references; secrets never appear in
  `providerConfiguration`, logs, crash annotations, shell commands, or board
  resources.
- **Residual:** device-unlock security is the platform's; we inherit it.

### G. The vendor (Relux Works) as adversary — what stops us
- Relux Works is **not** in the baseline data path, operates no exit network,
  and requires no account for the baseline product. There is no analytics or
  traffic telemetry by default; any future telemetry is opt-in, aggregate-only,
  documented, and requires a threat-model update.

## 5. Does-hide / does-NOT-hide matrix (user-facing claims)

| Observer | Hidden from them | Visible to them |
| --- | --- | --- |
| On-path network | tunneled destinations, DNS, payloads | that you run an SSH session to a specific host; timing/volume; SSH hostname's first lookup unless pinned |
| Exit host operator | nothing after termination | destinations, DNS, plaintext |
| Relux Works | everything (not in path) | nothing about your traffic |
| Destination server | your real ISP-assigned IP | the exit host's IP; whatever the app itself sends |

## 6. Fail-closed and kill-switch semantics (claim precision)

- Ordinary traffic and DNS fail closed on mandatory tunnel failure.
- Two explicit route modes (ADR-012): **Compatible** (allows captive-portal
  recovery) and platform-scoped **Fail-closed** (`includeAllNetworks` where the
  platform supports it).
- **Claim boundary:** fail-closed is platform-scoped, **not** an absolute
  kill-switch. We do not claim that zero packets can ever escape under all OS
  conditions. Marketing/UI copy MUST NOT imply an absolute guarantee.

## 7. Non-goals (state these, do not let copy overreach)

- Not anonymity (no mixing, single hop, fingerprintable SSH).
- Not DPI/censorship evasion.
- Not an audited end-to-end encryption layer over application traffic.
- Not a hosted/shared-exit VPN; connects only to user-configured infrastructure.
- Not protection against a compromised exit host or a compromised Apple device.

## 8. Residual risks register

- TOFU on first host-key trust unless verified out of band.
- SSH traffic-analysis fingerprintability.
- Exit-host operator has full post-exit visibility by design.
- Platform-scoped (not absolute) fail-closed.
- First in-clear DNS lookup of the SSH hostname unless the server IP is pinned.
- Update-signing and Developer ID key custody is a single-org trust root.

## 9. Change control

Any change that adds a data flow, weakens a boundary, introduces telemetry, or
alters a claim in §5–§7 MUST update this document and the derived disclosure,
privacy copy, and privacy policy in the same change. The disclosure UI
(`TASK-260715-6qqmsz`), privacy copy (`TASK-260715-2gwfaw`), and public privacy
policy (`TASK-260715-2k812u`) are downstream consumers linked on the board.
