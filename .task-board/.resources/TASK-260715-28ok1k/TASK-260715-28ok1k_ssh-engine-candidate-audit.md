# TASK-260715-28ok1k — SSH engine candidate source audit

Date: 2026-07-20  
Status: research handoff; engine selection remains open under ADR-014  
Consumers: TASK-260715-2ny6z4, TASK-260715-nzdzv3, TASK-260715-1af33i,
TASK-260715-1ozsb6

## Key takeaways

- The pinned SwiftNIO SSH baseline is tag `0.14.1`, commit
  `31cdc3c3391a10460dedf1170530cf651d2ca496`. Its exact resolved graph builds in
  release mode on macOS. It fixes the critical NIOSSH ECDSA advisory and resolves
  to patched Swift Crypto and SwiftNIO versions.
- At that source, every newly opened child channel receives a hard-coded
  `1 << 24` byte (16 MiB) target receive window. There is no public setter or
  observation hook. The client-initiated `_rekey()` method is also `internal`.
  Both require source-fork work and validation; neither gate may be waived.
- The most recent libssh2 release, `1.11.1`, is affected by six advisories fixed
  after that release. The auditable candidate baseline is therefore the exact,
  untagged upstream commit
  `a34302491c164d53c900fec9b3cbb050ecebe719` (`1.11.2_DEV`) with all six fixes,
  paired with OpenSSL `3.5.7`. This removes known release vulnerabilities but
  creates an explicit release-hygiene and supply-chain risk.
- libssh2 publicly exposes initial per-channel windows, remaining-window
  observation, and manual window adjustment. Its direct-tcpip convenience API
  still hardcodes the 2 MiB default, so a custom-window adapter must use the
  generic channel-open API and reproduce the RFC 4254 payload.
- libssh2 handles server-initiated KEX internally but exposes no public API for
  client-initiated rekey and no local byte/time threshold. Consequently both
  candidates fail the public client-rekey source gate before adaptation and both
  require the same sustained-transfer experiment.
- Neither source inspection nor upstream claims establish 500–1,000 channel
  headroom, extension-safe Apple packaging, bounded physical memory, or robust
  cancellation. These remain named, symmetric experiments. This audit does not
  select an engine.

## Evidence and audit method

The audit used immutable source checkouts and downloaded source archives. Claims
below are classified as `Public`, `Internal`, `Absent`, or `Experiment`. Source
paths are relative to the pinned repositories and links point to immutable
commits. Current advisories, releases, and open issues were checked on
2026-07-20; those findings are point-in-time evidence, not a claim that an
undisclosed vulnerability does not exist.

The machine-readable pin set is in
[`260720_task-260715-28ok1k-ssh-engine-candidate-manifest.json`](./260720_task-260715-28ok1k-ssh-engine-candidate-manifest.json).

## Candidate manifest

| Component | Exact source baseline | SHA-256 of source archive | License and notices | Product packaging |
|---|---|---|---|---|
| SwiftNIO SSH | tag `0.14.1`; commit `31cdc3c3391a10460dedf1170530cf651d2ca496`; [upstream](https://github.com/apple/swift-nio-ssh/tree/31cdc3c3391a10460dedf1170530cf651d2ca496) | `0b135087e76cb03e33f544484f21e1c3ba3b967f8a0ba2aead960ce4d0d06e6a` | Apache-2.0; `LICENSE.txt` SHA-256 `cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30`; no separate NOTICE file at the pin, so preserve the license and repository attribution | ReluxNIOSSH SwiftPM source dependency per ADR-019 |
| libssh2 | untagged `1.11.2_DEV`; commit `a34302491c164d53c900fec9b3cbb050ecebe719`; [upstream](https://github.com/libssh2/libssh2/tree/a34302491c164d53c900fec9b3cbb050ecebe719) | `744ba3e9a8e7a877038e94a74459340052a105ad599605a5b6d0d6bc5ec2c87c` | BSD-3-Clause; `COPYING` SHA-256 `a83a4da224ebeaaaea5efb4cd1ef1ab0998c1bd719d6f70b05e1d5c491372137`; binary redistribution must reproduce the notice, conditions, and disclaimer | Locally rebuilt static XCFramework `binaryTarget` behind the native adapter per ADR-019 |
| OpenSSL backend | tag `openssl-3.5.7`; tag object `6ca677c395a4ae4472a12c5857c122ec33b36f66`; commit `8cf17aaeb4599f8af87fefd810b5b5fee90fe69e`; [upstream](https://github.com/openssl/openssl/tree/openssl-3.5.7) | `a8c0d28a529ca480f9f36cf5792e2cd21984552a3c8e4aa11a24aa31aeac98e8` | Apache-2.0; `LICENSE.txt` SHA-256 `7d5450cb2d142651b8afa315b5f238efc805dad827d91ba367d8516bc9d49e7a`; `ACKNOWLEDGEMENTS.md` SHA-256 `58dee45791f007ced048114717f86672778fe75c551827c57e760861446ce3c3` | Statically linked into each libssh2 XCFramework slice; ship license/acknowledgements |

The libssh2 release `1.11.1` was inspected for comparison: signed annotated tag
object `3a735286108ad19e3b49c64ebcb66342f1f21df7`, peeled commit
`a312b43325e3383c865a87bb1d26cb52e3292641`, archive SHA-256
`9954cb54c4f548198a7cbebad248bdc87dd64bd26185708a294b2b50771e3769`.
It is not the candidate pin because it lacks the six security fixes listed below.

One source anomaly must be treated deliberately: at the selected libssh2 commit,
`LIBSSH2_VERSION` is `1.11.2_DEV` and the major/minor/patch fields are 1/11/2,
but `LIBSSH2_VERSION_NUM` remains `0x010b01`. Consumers must not use that numeric
macro to prove the pin; use the commit and source hash.

## SwiftNIO SSH transitive manifest

`swift package resolve` at the pinned checkout produced `Package.resolved`
`originHash` `87b1cfeb4c77158fd4e5a086c52807c86b6fe400f6bf502cba251a7eb9fb0606`.
The following is the complete resolved graph, not only direct dependencies.

| Package | Version and commit | Archive SHA-256 | License / notice SHA-256 |
|---|---|---|---|
| swift-asn1 | `1.7.1`, `a9a5efd40eaf558a2bcd48d64b1d1646be686008` | `422c98d0aecf8cd7f1022167a0acaba1b3c4e9341e81ed16a7677427c3893650` | Apache-2.0 `8c6db340475136df3c1201d458fa5755698eace76e510471ecc9d857d6083dac`; NOTICE `11dd3b3b783e6ec26098dd38ebc962986ea109b85447e28e62867b83bd0f8c5b` |
| swift-atomics | `1.3.1`, `0442cb5a3f98ab802acb777929fdb446bda11a34` | `e2652977537003d50b8da1f330ef73d94e50e294b7f5a2fd0f2ddbb03fbf632f` | Apache-2.0 `770af8291f708538d8ff885a0bbc4e045cd700531741c4f99528d435c14d7f55` |
| swift-collections | `1.6.0`, `a0cb0954ecb21e4e31b0070e6ed5674e8556685a` | `8e8714b566f9fafc28bf3de967e789f84d9e53466faa3a2240060ca7c1a7f2c7` | Apache-2.0 `770af8291f708538d8ff885a0bbc4e045cd700531741c4f99528d435c14d7f55` |
| swift-crypto | `4.5.1`, `47d3869a7291f085c1fb9fb1e6d3b97a793f45c6` | `c0d9f0d81e32160f36d9255e0174aaf63a7e0ca539345dd8caa7413e72a89aea` | Apache-2.0 `cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30`; NOTICE `b3ddc2ae068e76b3beb71be03c0400f90090f9469aa491bf7b1ac42320af37b8` |
| swift-nio | `2.101.3`, `0b18836bd8b0162e7e17a995a3fbee20ed8f3b2b` | `b7ffa2501fbbdac568999e96fa99e8eb392be42409540de797e7a087afa402ac` | Apache-2.0 `cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30`; NOTICE `d25ed2452b3476c342082d11e4e8bf5459174d2836124f842b499850bcebc50e` |
| swift-system | `1.7.4`, `b5544ba79a70a0cb3563e75bf26dc198d6b40ed3` | `26b843b016b300232a24e788e2ce2a6c281e2e3fa045e4ca1ff1ee40f7796ba1` | Apache-2.0 `2245a990b635558be210fb3eb4f8a6f7a49aebc0fefbf5859146a65ddc7ddcf3` |

## Pinned build baselines

### SwiftNIO SSH

The pinned [`Package.swift`](https://github.com/apple/swift-nio-ssh/blob/31cdc3c3391a10460dedf1170530cf651d2ca496/Package.swift)
uses Swift tools 6.1 and declares macOS 10.15 and iOS 13. The project targets
macOS 14 and iOS 17, so the package declaration does not raise the deployment
floor. `swift build -c release` succeeded on the audit host using the exact graph
above. That proves macOS source compilation, not iOS extension runtime safety.

The later adapter experiment must build the source product for arm64 iPhoneOS,
arm64/x86_64 simulator, and arm64/x86_64 macOS with
`APPLICATION_EXTENSION_API_ONLY=YES`, then run forbidden-symbol and linked-image
checks. Pure Swift does not by itself prove Network Extension safety.

### libssh2 + OpenSSL

The audit baseline fixes the following libssh2 CMake inputs:

```text
-DBUILD_STATIC_LIBS=ON
-DBUILD_SHARED_LIBS=OFF
-DBUILD_EXAMPLES=OFF
-DBUILD_TESTING=OFF
-DLIBSSH2_BUILD_DOCS=OFF
-DENABLE_DEBUG_LOGGING=OFF
-DLIBSSH2_NO_DEPRECATED=ON
-DCRYPTO_BACKEND=OpenSSL
-DCMAKE_DISABLE_FIND_PACKAGE_ZLIB=TRUE
```

It also fixes C compile definitions `LIBSSH2_NO_RSA_SHA1` and
`LIBSSH2_NO_AES_CBC`, and Apple flags `-fapplication-extension`,
`-fvisibility=hidden`, `-ffunction-sections`, and `-fdata-sections`.
Compression is intentionally absent. Public
[`libssh2_session_method_pref`](https://github.com/libssh2/libssh2/blob/a34302491c164d53c900fec9b3cbb050ecebe719/include/libssh2.h)
must additionally allowlist approved KEX, cipher, host-key, and MAC names because
the compiled default KEX list still contains group1/group14 SHA-1 and the MAC
list still contains HMAC-SHA1.

OpenSSL common configure options are pinned to `no-shared no-module no-dso
no-tests no-apps no-docs no-legacy no-comp` plus the extension, visibility, and
section flags above. The source-pinned Apple configure targets and minimums are
`ios64-xcrun -miphoneos-version-min=17.0`,
`iossimulator-arm64-xcrun -mios-simulator-version-min=17.0`,
`iossimulator-x86_64-xcrun -mios-simulator-version-min=17.0`,
`darwin64-arm64-cc -mmacosx-version-min=14.0`, and
`darwin64-x86_64-cc -mmacosx-version-min=14.0`. These exact inputs are the
candidate recipe, not a claimed successful Apple build; E-LIB-APPLE below owns
reproduction, archive symbol audit, no-dylib check, minimum-OS check, and SwiftPM
consumer link test. This is a materially larger binary and supply-chain surface
than the Swift source candidate, but measured stripped/link-map sizes are still
unknown.

## M0 capability and gate matrix

`Public` means an upstream public API directly covers the surface. `Internal`
means source support exists but is not a supported API. `Absent` means the
required control was not found at the pin. `Experiment` means source inspection
cannot establish the operational result.

| M0 gate | SwiftNIO SSH `31cdc3c` | libssh2 `a343024` + OpenSSL 3.5.7 | Required evidence |
|---|---|---|---|
| iOS/macOS build and extension safety | Public SwiftPM package declares iOS 13/macOS 10.15; macOS release build passed. Extension safety remains Experiment. | Upstream is portable C, but has no first-party Apple XCFramework contract. Exact static four-slice build is Experiment. | E-NIO-APPLE / E-LIB-APPLE |
| Raw host key before user auth | Public `NIOSSHClientServerAuthenticationDelegate.validateHostKey(NIOSSHPublicKey, …)` runs during KEX; public OpenSSH serialization exposes algorithm plus Base64 SSH wire blob. | Public `libssh2_session_hostkey` returns raw key bytes, length, and type after handshake and before user authentication. | E-HOSTAUTH proves ordering, SHA-256 fingerprint, persistence, mismatch rejection |
| Ed25519 plus fallback host key | Public Ed25519 and ECDSA P-256/384/521. RSA is Absent. | Public/backend supports Ed25519, ECDSA, and RSA-SHA2. SHA-1 RSA is compiled out. | E-ALGO against current and compatibility fixtures |
| Public-key user authentication | Public delegate offers Ed25519/ECDSA private keys; RSA is Absent. Password/host-based APIs exist but are not the product baseline. | Public key APIs cover Ed25519/ECDSA/RSA subject to backend/build; nonblocking behavior uses EAGAIN. | E-HOSTAUTH using all product key fixtures |
| Hundreds of direct-tcpip channels | Public `.directTCPIP` and `createChannel`; no small source cap. Capacity is Experiment. | Public `libssh2_channel_direct_tcpip_ex`; internal channel lookup/ID allocation linearly scan a linked list, so scale is Experiment. | E-CHANNELS and E-SCALE at 100/250/500/1,000 |
| Bidirectional exec/stdio channel | Public `.session`, `ExecRequest`, writes, reads, and output half-close. | Public generic session open, `libssh2_channel_process_startup("exec")`, read/write, EOF. | E-EXEC with simultaneous stdout/stderr, stdin backpressure, EOF/exit ordering |
| Upload through exec stdin; no SFTP | Same public exec/write/half-close surface; SFTP is not introduced. | Same public exec/write/send-EOF surface; libssh2 SFTP is deliberately unused and may be excluded from adapter API. | E-EXEC upload checksum and bounded buffering |
| Configurable per-channel initial receive window | Absent publicly; Internal hard-coded `1 << 24` target on every new child channel. | Public generic `libssh2_channel_open_ex(window_size, packet_size, …)`. Direct helper hardcodes 2 MiB, so adapter must use generic open with RFC payload. | E-WINDOW; NIOSSH fork API and libssh2 custom direct-open proof |
| Observe and cap receive-window adjustment | Absent publicly; internal manager auto-adjusts back toward the 16 MiB target. | Public `libssh2_channel_window_read_ex` and `libssh2_channel_receive_window_adjust2`; user maintains receive credit. | E-WINDOW at 32 KiB, 64 KiB, bulk cap, and withheld reads |
| Client byte/time-triggered rekey | Absent publicly; Internal `_rekey()` is documented as mostly for tests. No byte/time policy. | Absent publicly; internal `ssh2_kex_exchange(..., reexchange=1, …)` is not exported. No byte/time policy. | E-REKEY requires an adapter/fork hook for either candidate |
| Server-initiated rekey | Internal KEX state machine support and tests exist; operational behavior is Experiment. | Internal handling of inbound `SSH_MSG_KEXINIT` invokes reexchange; operational behavior is Experiment. | E-REKEY server-forced rekey during active multi-channel transfer |
| Sustained multi-GB transfer | Not established by source. | Not established by source; current open AEAD correctness report adds risk. | E-REKEY transfers at least 5 GiB while control and relay channels remain active |
| Current OpenSSH algorithm intersection | Modern-only intersection: Curve25519/ECDH, AES-GCM, Ed25519/ECDSA. No RSA, DH, CTR, or separate MAC modes. | Broad intersection: ML-KEM hybrids where available, Curve25519/ECDH/DH, ChaCha20-Poly1305, AES-GCM/CTR, Ed25519/ECDSA/RSA-SHA2, HMAC-SHA2. Must allowlist. | E-ALGO records negotiated methods against real server defaults |
| Older/RSA-only server reachability | Confirmed absent for RSA-only and DH/CTR-only peers. | RSA-SHA2 and selected DH/CTR can work; `ssh-rsa` SHA-1/CBC are deliberately excluded, so truly legacy peers remain unsupported. | E-ALGO compatibility matrix; unsupported must be explicit, not silently downgraded |
| Threading model | Handler/channel state is event-loop serialized; `createChannel` must run on the channel event loop. Configuration is intentionally not `Sendable`. | Mutable session state has no locking; crypto global init is process-scoped. Serialize every call for a session/lane on one executor. | E-SCALE + Thread Sanitizer adapter test |
| Allocator and memory accounting | Uses NIO `ByteBufferAllocator`; no candidate-wide custom allocator hook. A 16 MiB advertised window is credit, not proven eager allocation, but permits that much inbound flight/buffering per channel. | Public `libssh2_session_init_ex` hooks session alloc/free/realloc. OpenSSL allocations are outside those hooks. | E-SCALE records resident/high-water bytes, allocation counts, and per-channel slope |
| Cancellation and lifecycle | No Swift task cancellation API; adapter must close child/session on its event loop and await close futures. | No cancellation token; nonblocking calls return EAGAIN and teardown must close/free while coordinating socket shutdown. Open cancellation issues exist. | E-CANCEL for opening/read/write/auth/rekey, 100 cycles, path loss, no stranded work |
| Memory/binary-size budget | Source product avoids a second C crypto stack, but physical extension footprint is unknown. | Static libssh2 + OpenSSL has larger expected text/data and duplicate-crypto risk; exact stripped size is unknown. | E-SIZE and E-SCALE; no inference may replace measurement |

## SwiftNIO SSH source findings

### Windowing and rekey

The decisive window code is
[`Sources/NIOSSH/Child Channels/SSHChannelMultiplexer.swift`](https://github.com/apple/swift-nio-ssh/blob/31cdc3c3391a10460dedf1170530cf651d2ca496/Sources/NIOSSH/Child%20Channels/SSHChannelMultiplexer.swift#L211):
new child channels receive `targetWindowSize: 1 << 24`. The internal
`ChildChannelWindowManager` replenishes credit as the available window falls to
half its target. No parameter on public
[`NIOSSHHandler.createChannel`](https://github.com/apple/swift-nio-ssh/blob/31cdc3c3391a10460dedf1170530cf651d2ca496/Sources/NIOSSH/NIOSSHHandler.swift#L274)
sets, reads, or suppresses that behavior.

Client rekey is
[`internal func _rekey()`](https://github.com/apple/swift-nio-ssh/blob/31cdc3c3391a10460dedf1170530cf651d2ca496/Sources/NIOSSH/NIOSSHHandler.swift#L511),
with a source comment that it is mostly useful for testing. The pinned source
does contain KEX state-machine support for reexchange and tests for initiated
rekeys, but there is no public trigger or automatic byte/time threshold. The
ReluxNIOSSH fork must expose narrowly scoped window and rekey controls rather
than replacing these gates with defaults.

### Host key, authentication, and channels

During client KEX, the state machine invokes the public
[`validateHostKey`](https://github.com/apple/swift-nio-ssh/blob/31cdc3c3391a10460dedf1170530cf651d2ca496/Sources/NIOSSH/Key%20Exchange/SSHKeyExchangeStateMachine.swift#L317)
delegate before user-authentication progression. `NIOSSHPublicKey` supports a
public OpenSSH serialization initializer that yields the algorithm and Base64
SSH wire key; decoding the second field supplies stable raw bytes for SHA-256
fingerprinting. The delegate must persist that evidence through the existing
`SSHHostKeyEvidence` contract and reject a mismatch before credentials are sent.

Public child-channel types include session and direct-tcpip. Public child events
include `ExecRequest`; child writes provide stdin and `close(mode: .output)`
provides EOF/half-close. The adapter still needs to prove remote half-closure and
exit-status ordering under backpressure.

### Algorithms

The pinned defaults advertise:

- KEX: `curve25519-sha256`, `curve25519-sha256@libssh.org`, and
  `ecdh-sha2-nistp256/384/521`.
- Host/user keys: `ssh-ed25519` and ECDSA P-256/384/521.
- Encryption: `aes256-gcm@openssh.com` and `aes128-gcm@openssh.com`; integrity
  is integrated into AEAD rather than selected through a separate MAC.

This intersects the [current OpenSSH defaults](https://man.openbsd.org/OpenBSD-current/man5/ssh_config.5),
but the upstream
[`README`](https://github.com/apple/swift-nio-ssh/blob/31cdc3c3391a10460dedf1170530cf651d2ca496/README.md)
explicitly describes a modern-algorithm, building-block library rather than a
production-ready client. RSA host/user keys, DH KEX, AES-CTR, and old MAC modes
are absent. That is a compatibility boundary, not a reason to weaken host-key or
cipher policy.

## libssh2 source findings

### Windowing and direct-tcpip

[`include/libssh2.h`](https://github.com/libssh2/libssh2/blob/a34302491c164d53c900fec9b3cbb050ecebe719/include/libssh2.h#L787)
defines the default channel window as 2 MiB and publicly exposes
`libssh2_channel_open_ex`, `libssh2_channel_window_read_ex`, and
`libssh2_channel_receive_window_adjust2`. The generic open API accepts initial
window and packet size. Source comments place receive-window maintenance on the
caller, which permits a bounded-credit policy.

The convenience
[`libssh2_channel_direct_tcpip_ex`](https://github.com/libssh2/libssh2/blob/a34302491c164d53c900fec9b3cbb050ecebe719/src/channel.c#L407)
calls the internal open path with the 2 MiB default. A custom size therefore
requires generic `libssh2_channel_open_ex` with channel type `direct-tcpip` and
the RFC 4254 target/originator payload. E-WINDOW must prove that construction
against OpenSSH before the public API is considered sufficient.

### Rekey, concurrency, and cancellation

Inbound `SSH_MSG_KEXINIT` is recognized in
[`src/packet.c`](https://github.com/libssh2/libssh2/blob/a34302491c164d53c900fec9b3cbb050ecebe719/src/packet.c#L1336)
and calls internal `ssh2_kex_exchange(session, 1, …)`. The symbol is declared in
the private header and is not exported from `include/libssh2.h`. No public local
rekey call or automatic byte/time threshold was found. This is a confirmed API
absence, not merely undocumented behavior.

Channel IDs and channel lookup in
[`src/channel.c`](https://github.com/libssh2/libssh2/blob/a34302491c164d53c900fec9b3cbb050ecebe719/src/channel.c#L54)
walk the session channel list. The source has no small fixed channel ceiling,
but O(n) lookup/open behavior makes the 500–1,000 target an empirical CPU and
memory gate.

The nonblocking contract is EAGAIN plus socket block-direction polling. Session
operations mutate shared state and have no internal synchronization; one
serialized executor per session is required. `libssh2_session_init_ex` can route
libssh2 allocations through accounting hooks, but OpenSSL's internal allocations
remain separate. Cancellation has no token/API and must coordinate channel EOF,
close/free, socket shutdown, and session teardown without re-entering a session.

### Algorithms with the pinned backend

OpenSSL 3.5.7 enables Ed25519, ECDSA, RSA-SHA2, AES-GCM, AES-CTR, and the current
ML-KEM implementations used by the selected libssh2 commit. At this source the
default KEX list starts with `mlkem768x25519-sha256`,
`mlkem768nistp256-sha256`, and `mlkem1024nistp384-sha384` when available, then
Curve25519, ECDH, and DH variants. The default host-key list covers Ed25519,
ECDSA, and RSA-SHA2, including supported OpenSSH certificate variants. Ciphers
include ChaCha20-Poly1305, AES-GCM, AES-CTR, and optional legacy modes.

The pinned build disables RSA-SHA1 and AES-CBC. The adapter must use method
preferences to exclude SHA-1/group1 KEX and HMAC-SHA1 while retaining the
documented modern intersection. Wider source support is not permission for a
silent downgrade.

## Security baseline as of 2026-07-20

### Swift candidate

- SwiftNIO SSH [GHSA-998x-vgvp-xwpc / CVE-2026-43798](https://github.com/apple/swift-nio-ssh/security/advisories/GHSA-998x-vgvp-xwpc)
  is a critical pre-authentication ECDSA signature parsing issue affecting
  versions through 0.14.0. The selected 0.14.1 commit is the patched release.
- Swift Crypto [GHSA-8q93-f6xh-4f6f / CVE-2026-43823](https://github.com/apple/swift-crypto/security/advisories/GHSA-8q93-f6xh-4f6f)
  affects 3.2.0 through 4.5.0; selected 4.5.1 is patched. Its older X-Wing
  [GHSA-9m44-rr2w-ppp7](https://github.com/apple/swift-crypto/security/advisories/GHSA-9m44-rr2w-ppp7)
  is also fixed by 4.5.1.
- SwiftNIO [GHSA-r3rc-9hpw-54v9 / CVE-2026-43671](https://github.com/apple/swift-nio/security/advisories/GHSA-r3rc-9hpw-54v9)
  and [GHSA-qcc5-f287-vgmq / CVE-2026-43678](https://github.com/apple/swift-nio/security/advisories/GHSA-qcc5-f287-vgmq)
  are fixed by selected 2.101.3. The latter is a WebSocket path, not an SSH path,
  but it remains part of the dependency baseline.
- Swift ASN.1 [GHSA-w8xv-rwgf-4fwh / CVE-2025-0343](https://github.com/apple/swift-asn1/security/advisories/GHSA-w8xv-rwgf-4fwh)
  is fixed well before selected 1.7.1. No GitHub repository advisory was
  published for the selected Atomics, Collections, or System repositories at
  the audit time.

### C candidate

libssh2 `1.11.1` is not a clean current baseline. The selected commit contains
all of the following exact fixes, verified as ancestors of the pin:

| Advisory | Fix commit contained by `a343024` |
|---|---|
| CVE-2026-7598 | [`256d04b60d80bf1190e96b0ad1e91b2174d744b1`](https://github.com/libssh2/libssh2/commit/256d04b60d80bf1190e96b0ad1e91b2174d744b1) |
| CVE-2026-58051 | [`a9758da45a52bc8c630ec9493804d0c6ea30b24a`](https://github.com/libssh2/libssh2/commit/a9758da45a52bc8c630ec9493804d0c6ea30b24a) |
| CVE-2026-58050 | [`34497525929b9a47f03dfb81887ac896202b7e12`](https://github.com/libssh2/libssh2/commit/34497525929b9a47f03dfb81887ac896202b7e12) |
| CVE-2026-55200 | [`97acf3dfda80c91c3a8c9f2372546301d4a1a7a8`](https://github.com/libssh2/libssh2/commit/97acf3dfda80c91c3a8c9f2372546301d4a1a7a8) |
| CVE-2026-55199 | [`17626857d20b3c9a1addfa45979dadcee1cd84a4`](https://github.com/libssh2/libssh2/commit/17626857d20b3c9a1addfa45979dadcee1cd84a4) |
| CVE-2025-15661 | [`2dae3024897e1898d389835151f4e9606227721d`](https://github.com/libssh2/libssh2/commit/2dae3024897e1898d389835151f4e9606227721d) |

The historical Terrapin issue, CVE-2023-48795, was addressed by strict KEX in
1.11.1 and that support is retained. Upstream
[#1925](https://github.com/libssh2/libssh2/issues/1925) tracks the missing
1.11.2 release. A newer open report,
[#2023](https://github.com/libssh2/libssh2/issues/2023), alleges AEAD packet
correctness and memory issues. A maintainer disputes the specific leak analysis
but acknowledges unresolved correctness investigation. This audit does not
treat the alleged leak as proven; E-LIB-AEAD must exercise ChaCha20-Poly1305 and
AES-GCM under ASan and packet-content checks.

OpenSSL 3.5.7 is the current 3.5 LTS patch baseline at the audit date and fixes
the issues listed for earlier 3.5 releases in the official
[OpenSSL 3.5 vulnerability index](https://openssl-library.org/news/vulnerabilities-3.5/).
The crypto baseline must be re-audited immediately before producing a signed
XCFramework.

## Maintenance and open-issue surface

SwiftNIO SSH had 14 commits in the 12 months ending 2026-07-20 and releases
0.11.0 (2025-06-26), 0.12.0 (2025-11-04), 0.13.0 (2026-04-07), 0.14.0
(2026-06-24), and 0.14.1 (2026-07-15). It is active, but remains a 0.x building
block. The audit found 24 open issues. Relevant open reports include #225
(certificate advertisement), #221 (unknown request parsing), #208/#207
(sendability), #86 (stuck client), and #65 (authentication result reporting).

libssh2 had 679 commits in the same 12-month window and a latest audited commit
dated 2026-07-19, but no release after 1.11.1 (2024-10-16). It is active while
release cadence lags security work. The audit found 27 open issues. Relevant
reports include #2023 (AEAD), #1925 (release), #1810 (keepalive timing), #1672
(write stuck), #1491 (OpenSSL decrypt crash), #1490 (maximum transmission),
#1370 (KEX failure), #1218 (cannot end long exec early), #1188 (macOS channel
close deadlock), #792 (window adjustment), and #671 (nonblocking exec).

Issue counts and statuses are volatile; downstream tests should cite the issue
IDs rather than assume continued openness.

## Apple integration and binary risk

SwiftNIO SSH follows the reviewable SwiftPM source path required by ADR-019 and
shares Swift Crypto/NIO dependencies already expected by the design. Its main
integration risks are fork ownership, event-loop correctness, 0.x upstream API
movement, and hidden runtime allocation—not native packaging.

libssh2 follows the static XCFramework path required by ADR-019. The XCFramework
must contain no dylibs, no absolute SDK/library paths, no unsupported slices,
and no forbidden extension APIs; must use the project deployment targets; and
must provide deterministic source provenance plus the BSD and Apache notices.
Static OpenSSL increases code size, native-C attack surface, rebuild burden, and
the possibility of two crypto stacks in the extension. These are risks, not
measurements. E-SIZE must record per-slice archive size, linked contribution,
stripped extension delta, symbols, and notices before selection.

## Named dependent experiments

No unknown in this audit is converted into an assumption:

| Experiment | Owner / consumer | Pass evidence |
|---|---|---|
| E-NIO-APPLE | TASK-260715-1af33i / NIOSSH adapter lane | iOS device, simulator, and macOS builds with extension-only APIs; no forbidden symbols; physical extension launch |
| E-LIB-APPLE | TASK-260715-1ozsb6 / libssh2 adapter lane | Reproducible four-slice static libssh2+OpenSSL XCFramework, hashes, symbol/dylib/min-OS audit, SwiftPM consumer link |
| E-HOSTAUTH | conformance contract TASK-260715-2ny6z4 | Raw key captured before credential callback; SHA-256 evidence stored; changed key fails before auth; Ed25519/ECDSA/RSA-SHA2 fixture results recorded |
| E-CHANNELS | both adapters | Direct-tcpip and exec/stdio full-duplex, independent close/backpressure, simultaneous relay traffic, exec upload checksum |
| E-WINDOW | NIOSSH fork TASK-260715-nzdzv3 + both adapters | Initial 32 KiB, 64 KiB, and capped bulk windows observable on wire; credit withheld when consumer stalls; no unbounded buffering |
| E-REKEY | conformance/functional/rekey tasks | Public adapter trigger with byte/time policy; client- and server-initiated rekey during at least 5 GiB transfer; channels remain live; negotiated keys change; no plaintext loss/duplication |
| E-SCALE | both adapters | 100/250/500/1,000 channels; base RSS, peak RSS, per-channel slope, allocator counts, CPU/open latency, close latency, and file descriptors reported against the extension budget |
| E-CANCEL | both adapters | Cancellation in DNS/connect/KEX/auth/open/read/write/rekey plus path loss; 100 connect/cancel cycles; bounded timeout; no leaked tasks, channels, sessions, or sockets |
| E-ALGO | both adapters | Negotiated KEX/host-key/cipher/MAC recorded against current OpenSSH defaults, product server fixture, RSA-SHA2 fallback, and named older fixtures; unsupported combinations fail explicitly without SHA-1/CBC downgrade |
| E-LIB-AEAD | libssh2 adapter | AES-GCM and ChaCha20-Poly1305 multi-channel packet-content tests under ASan/UBSan; upstream #2023 disposition recorded |
| E-SIZE | both adapter artifacts | Stripped physical extension delta and link-map contribution, not repository/archive size; libssh2 and OpenSSL reported separately |
| E-SUPPLYCHAIN | selection task TASK-260715-1gjxer | Re-audit candidate pins and advisories; prefer a signed 1.11.2+ libssh2 release if it contains every fix and passes identical tests; no silent movement from `a343024` |

## Gate-preserving conclusion

The source audit establishes implementable channel and host-key paths for both
candidates, but neither has an acceptable public client-rekey surface at its
pin. SwiftNIO SSH additionally requires forked per-channel window control;
libssh2 requires a custom generic direct-tcpip open, a secure method allowlist,
and a reproducible extension-safe native package. Scale, rekey, cancellation,
memory, binary size, and physical Apple behavior remain experiments for both.

ADR-014 therefore remains open. Engine selection belongs to
TASK-260715-1gjxer only after the same M0 gates and physical evidence are applied
to both candidates.

## Inspected source paths

SwiftNIO SSH `31cdc3c3391a10460dedf1170530cf651d2ca496`:

- `Package.swift`, `Package.resolved`, `LICENSE.txt`, `README.md`, `SECURITY.md`
- `Sources/NIOSSH/Child Channels/SSHChannelMultiplexer.swift`
- `Sources/NIOSSH/Child Channels/ChildChannelWindowManager.swift`
- `Sources/NIOSSH/Child Channels/SSHChannelType.swift`
- `Sources/NIOSSH/Child Channels/ChildChannelUserEvents.swift`
- `Sources/NIOSSH/NIOSSHHandler.swift`
- `Sources/NIOSSH/Key Exchange/SSHKeyExchangeStateMachine.swift`
- `Sources/NIOSSH/Keys And Signatures/ClientServerAuthenticationDelegate.swift`
- `Sources/NIOSSH/Keys And Signatures/NIOSSHPublicKey.swift`
- `Sources/NIOSSH/TransportProtection/AESGCM.swift`,
  `Sources/NIOSSH/TransportProtection/SSHTransportProtection.swift`, and
  `Sources/NIOSSH/SSHMessages.swift`
- rekey, channel, key-exchange, and user-authentication tests under `Tests/NIOSSHTests`

libssh2 `a34302491c164d53c900fec9b3cbb050ecebe719`:

- `CMakeLists.txt`, `COPYING`, `include/libssh2.h`
- `src/channel.c`, `src/channel.h`, `src/packet.c`, `src/kex.c`
- `src/session.c`, `src/hostkey.c`, `src/userauth.c`, `src/transport.c`
- `src/crypto_config.h`, `src/openssl.c`, `src/openssl.h`, `src/libssh2_priv.h`
- channel, KEX, crypto, and nonblocking tests under `tests`

OpenSSL `openssl-3.5.7`:

- `VERSION.dat`, `LICENSE.txt`, `ACKNOWLEDGEMENTS.md`, `Configure`
- provider/build configuration and release vulnerability material linked above

## Project evidence

- [SSH transport gates](../.spec/ssh-transport.md)
- [Validation matrix](../.spec/validation.md)
- [Architecture decisions ADR-005, ADR-006, ADR-014, ADR-019](../.spec/decisions.md)
- [SSH transport contracts](../Sources/ReluxTunnelCore/SSHContracts.swift)
