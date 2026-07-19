# TASK-260715-uopycx — pinned HEV/lwIP baseline audit

Audit date: 2026-07-20  
Board task: `TASK-260715-uopycx` — Pin and audit the HEV and lwIP baseline  
Consumers: `TASK-260715-p89bdj` — packet bridge contract; `TASK-260715-1vv52g` — HEV integration

## Context

This audit establishes the exact unmodified upstream graph for the M0 packet
bridge spike and verifies the Apple build, external descriptor contract, Darwin
packet family word, UDP-in-TCP framing, low-memory configuration, lifecycle,
allocator behavior, licenses, and known upstream patches from primary source.

The preliminary project research inspected tunnel commit `1d334516…`. Six tunnel
commits landed after that candidate and before this audit. The selected baseline
is therefore upstream `main` as observed and built on 2026-07-20:
`ad7600497931205105b08367bd1b450048157e40`. This is an exact commit, not a
floating branch or release tag.

## Highlights / key takeaways

- **Baseline:** unmodified `hev-socks5-tunnel` `ad760049…`, core `c2345190…`,
  task system `b1afa0e2…`, HEV lwIP fork `2a11c14c…`, and yaml `efa36117…`.
  Exact tree and deterministic `git archive` hashes are in the companion
  dependency manifest.
- **Apple build verified:** upstream `./build-apple.sh` passed unchanged with
  Xcode 26.5 / Apple clang 21.0.0 and produced the declared iOS, iOS Simulator,
  macOS, tvOS, and tvOS Simulator slices.
- **Descriptor ownership:** a nonnegative external `tun_fd` is made nonblocking,
  retained by HEV while its blocking main function runs, and not closed by HEV.
  The caller owns descriptor lifetime and closes it only after the HEV main call
  has returned.
- **Darwin framing:** HEV unconditionally consumes four bytes before every
  inbound IP packet. On outbound it emits `htonl(AF_INET)` for IP version 4 and
  `htonl(AF_INET6)` for every other version. HEV does not validate the inbound
  family value; the bridge must validate family, length, and IP version itself.
- **UDP-in-TCP:** `socks5.udp: tcp` selects proprietary command `0x05`. Each
  relay frame is a two-byte network-order **payload length**, a one-byte header
  length, SOCKS `ATYP + address + port`, then payload. The implementation is
  more precise than the README's ambiguous “total length” wording.
- **Low-memory anomaly:** the documented `task-stack-size: 24576` example is
  silently raised to **35,480 bytes** when the omitted default
  `udp-copy-buffer-nums: 10` remains in effect. This audit does not choose new
  constants; M0 must measure and explicitly verify the effective parsed values.
- **Lifecycle:** the public main API is blocking and should run on one dedicated
  native thread. The tunnel uses process-global static state and is not a safe
  concurrent multi-instance API. `hev_socks5_tunnel_quit()` is asynchronous
  signaling; the owner must join the main call before closing the external fd.
- **Known unresolved risk:** upstream issue
  [#315](https://github.com/heiher/hev-socks5-tunnel/issues/315) reports a rare
  teardown-time lwIP `pbuf_free` abort on Android 2.15.0. It is not reproduced or
  resolved upstream; repeated Apple stop tests remain mandatory.
- **Fork policy:** the M0 default is this unmodified graph. A fork is not
  justified by source preference. It requires Instruments evidence, a measured
  callback benefit, conformance/lifecycle tests, a minimal patch inventory, full
  notices, and an upstream-rebase plan.

## 1. Exact dependency graph and provenance

| Component | Exact revision | Relationship | License |
| --- | --- | --- | --- |
| [hev-socks5-tunnel](https://github.com/heiher/hev-socks5-tunnel/tree/ad7600497931205105b08367bd1b450048157e40) | `ad7600497931205105b08367bd1b450048157e40` (`2.16.0-1-gad76004`) | Root | MIT |
| [hev-socks5-core](https://github.com/heiher/hev-socks5-core/tree/c234519072ff5b928b90b304da9a666bcb440455) | `c234519072ff5b928b90b304da9a666bcb440455` (`1.6.3-2-gc234519`) | Git submodule at `src/core`; sources compile into the tunnel archive | MIT |
| [hev-task-system](https://github.com/heiher/hev-task-system/tree/b1afa0e21fb4ed5a69560e78e54baf0efdebe171) | `b1afa0e21fb4ed5a69560e78e54baf0efdebe171` (`5.10.2`) | Git submodule; static archive merged into Apple archive | MIT |
| [HEV lwIP fork](https://github.com/heiher/lwip/tree/2a11c14c7a32887af25a034e82ef18b0b12076ac) | `2a11c14c7a32887af25a034e82ef18b0b12076ac` (`2.2.1.7`) | Git submodule; static archive merged into Apple archive | lwIP BSD-style 3-clause license |
| [HEV yaml fork](https://github.com/heiher/yaml/tree/efa36117a8646d26d12b58e05bac472d7854a70d) | `efa36117a8646d26d12b58e05bac472d7854a70d` (`0.2.5.2`) | Git submodule; static archive merged into Apple archive | MIT |
| Wintun bundle | Root tree `8c9b8c3d…` at `third-part/wintun` | Vendored Windows-only DLL/header/license; not shipped in Apple XCFramework | Wintun prebuilt binary license; out of Apple binary notice set |

The root [`.gitmodules`](https://github.com/heiher/hev-socks5-tunnel/blob/ad7600497931205105b08367bd1b450048157e40/.gitmodules)
is primary evidence for the four submodules. yaml is included because it is a
direct linked dependency even though the task headline names only HEV/core/task
system/lwIP. Wintun is recorded because it is vendored provenance, but the
Apple build's platform branches produce no-symbol Windows objects and do not
merge `wintun.dll`.

The machine-readable manifest is:
`.research/260720_task-260715-uopycx-dependency-manifest.json`.

## 2. Apple build verification

The upstream [README](https://github.com/heiher/hev-socks5-tunnel/blob/ad7600497931205105b08367bd1b450048157e40/README.md#L53-L60)
instructs a recursive clone followed by `./build-apple.sh`. The pinned
[`build-apple.sh`](https://github.com/heiher/hev-socks5-tunnel/blob/ad7600497931205105b08367bd1b450048157e40/build-apple.sh)
does the following:

1. Invokes `make static` for each SDK/architecture with `xcrun ... clang`.
2. Passes `-arch`, the SDK-specific minimum-version flag, and
   `-Wl,-Bsymbolic-functions` at link time.
3. Adds `-DENABLE_LIBRARY` through the root Makefile static target.
4. Combines the tunnel/core, lwIP, yaml, and task-system static archives with
   `libtool`.
5. Lipo-merges simulator/macOS pairs and creates
   `HevSocks5Tunnel.xcframework` with `hev-main.h` and `module.modulemap`.

### Verified matrix

| Platform | Minimum encoded by script | Architectures | Audit result |
| --- | ---: | --- | --- |
| iOS device | 15.0 | arm64 | Pass |
| iOS Simulator | 15.0 | arm64, x86_64 | Pass |
| macOS | 10.14 | arm64, x86_64 | Pass |
| tvOS device | 17.0 | arm64 | Pass |
| tvOS Simulator | 17.0 | arm64, x86_64 | Pass |

Audit environment: macOS 26.5 (25F71), Xcode 26.5 (17F42), Apple clang
21.0.0. The task-scoped build log SHA-256 is
`e6c19feb40f6ae9eff62e6f5ee26032cf364c9bbd7a47d2206a8b58685a31403`.

### Build and embedding risks

- The script deletes `apple_xcframework/` and `HevSocks5Tunnel.xcframework`
  before building. Run it only in a disposable, clean, exactly pinned checkout.
- It builds every cross-platform translation unit. `libtool` reports many
  “has no symbols” warnings for inactive platform/source branches; the command
  still succeeds. Treat new compiler errors or materially different warnings as
  drift.
- It emits tvOS slices even though Relux M0 needs iOS/macOS. It emits no Mac
  Catalyst slice. This is not a blocker for the current declared targets.
- The public module exposes only `hev-main.h`. Allocator internals and session
  internals are linked but are not part of the supported Swift module surface.
- Static archive hashes are toolchain-build evidence, not the dependency lock.
  Commit/tree/archive hashes in the manifest are authoritative.
- The script does not sign a product and does not integrate an Xcode target.
  Provider and harness embedding, linker settings, resource/notices placement,
  and signing remain integration responsibilities.

## 3. External descriptor and Darwin packet contract

The public [`hev-main.h`](https://github.com/heiher/hev-socks5-tunnel/blob/ad7600497931205105b08367bd1b450048157e40/src/hev-main.h#L19-L70)
accepts `tun_fd` and states that the main call blocks until quit or error.

For a nonnegative external fd,
[`tunnel_init`](https://github.com/heiher/hev-socks5-tunnel/blob/ad7600497931205105b08367bd1b450048157e40/src/hev-socks5-tunnel.c#L357-L374):

- calls `ioctl(fd, FIONBIO, 1)`;
- stores the same descriptor; and
- skips opening/configuring a platform TUN interface.

[`tunnel_fini`](https://github.com/heiher/hev-socks5-tunnel/blob/ad7600497931205105b08367bd1b450048157e40/src/hev-socks5-tunnel.c#L424-L440)
closes the fd only when `tun_fd_local` says HEV opened it. Therefore:

- the bridge passes endpoint B of the public `AF_UNIX/SOCK_DGRAM` pair;
- endpoint B must remain open for the entire blocking HEV main call;
- HEV is allowed to change its nonblocking flag; and
- the bridge closes endpoint B only after shutdown has been signaled and the
  main call has returned.

The Apple descriptor implementation is
[`src/hev-tunnel-macos.h`](https://github.com/heiher/hev-socks5-tunnel/blob/ad7600497931205105b08367bd1b450048157e40/src/hev-tunnel-macos.h#L15-L74):

- ingress uses one `readv` into a four-byte `uint32_t` plus one pbuf;
- it rejects only reads of four bytes or fewer, subtracts four, and sends the
  payload to lwIP;
- it does **not** inspect or validate the ingress family value;
- egress uses one `writev`, prepends `htonl(AF_INET)` when the first packet
  nibble is 4, and otherwise prepends `htonl(AF_INET6)`.

This directly confirms the four-byte network-order Darwin family word required
by `.spec/packet-plane.md`. It also makes validation ownership explicit:

| Direction | Bridge responsibility | HEV behavior |
| --- | --- | --- |
| PacketFlow → HEV | Validate IP version; prepend exactly four bytes: network-order `AF_INET` or `AF_INET6`; preserve one packet per datagram | Strips four bytes without checking the value |
| HEV → PacketFlow | Require at least 5 bytes; validate family is exactly v4/v6; validate family matches IP version; strip four bytes; preserve packet boundary | Chooses v4 only for version nibble 4; otherwise labels v6 |

`tunnel.mtu` defaults to 8500. With an external descriptor HEV does not set an
OS interface MTU; the value sizes the ingress pbuf read. The Apple provider must
set its Network Extension MTU separately, while the HEV config and socket
datagram capacity must remain consistent.

## 4. IPv4/IPv6, TCP, and UDP support

The upstream feature list declares dual-stack IPv4/IPv6, TCP redirection, and
UDP-in-UDP/UDP-in-TCP. Source confirms:

- lwIP `LWIP_IPV6=1`, `LWIP_TCP=1`, and `LWIP_UDP=1` in
  [`lwipopts.h`](https://github.com/heiher/lwip/blob/2a11c14c7a32887af25a034e82ef18b0b12076ac/src/ports/include/lwipopts.h);
- the HEV netif installs IPv4 and IPv6 output callbacks and creates any-address
  TCP and UDP PCBs in
  [`hev-socks5-tunnel.c`](https://github.com/heiher/hev-socks5-tunnel/blob/ad7600497931205105b08367bd1b450048157e40/src/hev-socks5-tunnel.c#L90-L110);
- TCP sessions use SOCKS5 CONNECT; UDP-in-TCP sessions use command `0x05`.

The selected baseline also contains optional local ICMP echo replies, disabled
by default. M0 should keep `tunnel.icmp: off` unless a separate product decision
and tests authorize it; ICMP is not part of this task's tuning selection.

## 5. UDP-in-TCP wire contract

The pinned core
[`README`](https://github.com/heiher/hev-socks5-core/blob/c234519072ff5b928b90b304da9a666bcb440455/README.md#L160-L191)
documents proprietary UDP-in-TCP over the primary SOCKS5 TCP stream. The source
contract is:

### Request

```text
VER=0x05 | CMD=0x05 | RSV=0x00 | ATYP | DST.ADDR | DST.PORT
```

`HEV_SOCKS5_REQ_CMD_FWD_UDP = 5` is defined in
[`hev-socks5-proto.h`](https://github.com/heiher/hev-socks5-core/blob/c234519072ff5b928b90b304da9a666bcb440455/src/hev-socks5-proto.h#L48-L53)
and selected for `HEV_SOCKS5_TYPE_UDP_IN_TCP` in
[`hev-socks5-client.c`](https://github.com/heiher/hev-socks5-core/blob/c234519072ff5b928b90b304da9a666bcb440455/src/hev-socks5-client.c#L87-L115).

### Relay frame

```text
MSGLEN:u16be | HDRLEN:u8 | ATYP:u8 | DST.ADDR | DST.PORT:u16be | DATA
```

Source-backed semantics from
[`hev-socks5-udp.c`](https://github.com/heiher/hev-socks5-core/blob/c234519072ff5b928b90b304da9a666bcb440455/src/hev-socks5-udp.c#L56-L100):

- `MSGLEN` is set to `htons(payload_length)`. Despite the README phrase “total
  length,” the implementation treats it as DATA length only.
- `HDRLEN = 3 + encoded_address_length`, so it counts from the first MSGLEN byte
  through the end of DST.PORT.
- Encoded address length includes ATYP and port: 7 bytes for IPv4, 19 for IPv6,
  and `4 + domain_length` for names.
- Consequently HDRLEN is 10 for IPv4, 22 for IPv6, and
  `7 + domain_length` for a domain.
- ATYP/address/port follow SOCKS5: IPv4 `0x01`, domain `0x03`, IPv6 `0x04`.

TCP is a byte stream: the consumer must buffer partial/coalesced reads, parse
the fixed three-byte prefix, bound HDRLEN/MSGLEN before allocation, then consume
exactly the encoded address and payload. No outer datagram boundary exists.

## 6. Configuration and effective low-memory behavior

### Audited keys

| YAML key | Source default | M0 requested starting value | Verified behavior |
| --- | ---: | ---: | --- |
| `tunnel.mtu` | 8500 | 8500 hypothesis | Parsed as unsigned; sizes external-fd ingress pbuf. It sets interface MTU only when HEV opens the TUN itself. |
| `socks5.udp` | UDP-in-TCP internally if omitted; sample config says `udp` | `tcp` fixed by ADR-004 | Parser sets `udp_in_udp=1` only for case-insensitive exact `udp`; `tcp` leaves it zero and selects command `0x05`. Unknown strings also fall through to TCP, so integration must validate configuration before HEV. |
| `misc.task-stack-size` | 86,016 | 24,576 measurement candidate | Parser enforces an effective minimum described below. |
| `misc.tcp-buffer-size` | 65,536 | 4,096 measurement candidate | Clamped to lwIP `TCP_SND_BUF = 8 × 8191 = 65,528`; 4,096 is unchanged. Used for the per-TCP-session ring buffer. |
| `misc.udp-copy-buffer-nums` | 10 | not selected by current spec | Each unit is 1,500 bytes on the UDP session task stack; participates in minimum stack calculation. |
| `misc.udp-recv-buffer-size` | 524,288 | not selected by current spec | Applied to the SOCKS5 core UDP receive socket buffer. |
| `misc.max-session-count` | 0 (unlimited) | 1,200 measurement candidate | On insertion, count `>= limit` triggers termination of the least-recently-active session. Teardown is asynchronous, so it is not an instantaneous hard allocation cap. |

The defaults and key parsing are in
[`hev-config.c`](https://github.com/heiher/hev-socks5-tunnel/blob/ad7600497931205105b08367bd1b450048157e40/src/hev-config.c#L20-L49)
and its
[`misc` parser](https://github.com/heiher/hev-socks5-tunnel/blob/ad7600497931205105b08367bd1b450048157e40/src/hev-config.c#L330-L395).
The documented defaults and low-memory example are in the pinned
[`README`](https://github.com/heiher/hev-socks5-tunnel/blob/ad7600497931205105b08367bd1b450048157e40/README.md#L138-L162)
and
[`low-memory section`](https://github.com/heiher/hev-socks5-tunnel/blob/ad7600497931205105b08367bd1b450048157e40/README.md#L228-L242).

### Effective task-stack anomaly

After parsing, source computes:

```text
effective_tcp_buffer = min(requested_tcp_buffer, TCP_SND_BUF)
effective_task_stack = max(
    requested_task_stack,
    20480 + max(effective_tcp_buffer, 1500 * udp_copy_buffer_nums)
)
```

With the README/M0 values `task-stack-size=24576`, `tcp-buffer-size=4096`, and
the omitted default `udp-copy-buffer-nums=10`, the effective minimum is:

```text
20480 + max(4096, 1500 * 10) = 35480 bytes
```

Therefore the nominal 24,576 value is not the effective per-session task stack.
The unmerged upstream
[#299](https://github.com/heiher/hev-socks5-tunnel/pull/299) proposed moving
the UDP VLA off the task stack and explicitly describes overflow risk, but the
patch was closed without merge and is **not** in this baseline.

This task does not select final values. The bridge/integration tests must assert
the complete explicit YAML, exercise TCP and UDP sessions, and measure actual
resident/virtual memory before ADR-015 or any tuning decision.

## 7. Threading, global state, allocator, and shutdown

### Threading model

`hev_socks5_tunnel_main[_from_str]` initializes the task system, calls
`lwip_init`, creates HEV tasks, and runs the cooperative scheduler on the calling
native thread. The task-system
[`README`](https://github.com/heiher/hev-task-system/blob/b1afa0e21fb4ed5a69560e78e54baf0efdebe171/README.md#L5-L26)
states that tasks/coroutines share process resources and have private stacks.
Provider integration should dedicate one native thread to the blocking HEV call;
do not run it on a Swift cooperative executor thread.

Hostname resolution lazily starts a task-system “aide” pthread. Its
[`hev-task-aide.c`](https://github.com/heiher/hev-task-system/blob/b1afa0e21fb4ed5a69560e78e54baf0efdebe171/src/kern/aide/hev-task-aide.c#L21-L69)
has process-global reactor/thread state and no finalizer. Numeric SOCKS addresses
bypass it; hostnames may leave that helper thread alive for the process lifetime.
The harness must account for this when defining a repeat-cycle thread baseline.

### Process-global/single-instance constraints

Tunnel state (`run`, `tun_fd`, counters, lwIP PCBs, task pointers, session list)
is file-static in
[`hev-socks5-tunnel.c`](https://github.com/heiher/hev-socks5-tunnel/blob/ad7600497931205105b08367bd1b450048157e40/src/hev-socks5-tunnel.c#L42-L61).
Configuration is also file-static, and `hev_config_fini()` is empty. Consequences:

- no concurrent HEV tunnel instances in one process;
- serialize start/stop and wait for the prior main call to return;
- provide a complete configuration on every generation because omitted fields
  can retain values parsed by a previous in-process run;
- lifecycle tests must include successful restart and failed-start recovery;
- initialization sets process-wide `SIGPIPE` to `SIG_IGN` and does not restore
  the prior disposition.

The public wrapper's early error paths return immediately after logger,
task-system, or tunnel initialization failures. Not every partial initialization
path visibly runs the same complete finalization sequence. This is a harness risk
and must be covered with injected/real failure loops before provider acceptance.

### Allocator hooks

lwIP's pinned options set `MEM_CUSTOM_ALLOCATOR=1` and map allocations to
`hev_malloc`/`hev_calloc`/`hev_free`. hev-task-system exposes a
`HevMemoryAllocator` vtable and thread-local default allocator. However:

- `hev_task_system_init()` installs its sliced allocator when
  `ENABLE_MEMALLOC_SLICE=1` (the pinned default);
- the XCFramework public module contains only `hev-main.h`, not allocator APIs;
- there is no tunnel-level public callback to observe allocation or install a
  custom allocator around initialization.

Thus allocator replacement is technically present inside the dependency but is
not a supported HEV tunnel integration hook in this baseline. Instruments,
malloc stack logging, task/session counters, and process memory measurements are
the no-fork observability path.

### Shutdown contract

[`hev_socks5_tunnel_quit`](https://github.com/heiher/hev-socks5-tunnel/blob/ad7600497931205105b08367bd1b450048157e40/src/hev-main.c#L116-L120)
writes to an internal event socket. The event task clears `run`, terminates
sessions, and joins lwIP I/O/timer tasks. The main function then finalizes tunnel,
loggers, config, and task system before returning.

Required owner sequence:

1. Mark the provider generation stopping; stop new bridge writes.
2. Call `hev_socks5_tunnel_quit()` only for a generation whose main call was
   actually launched.
3. Keep both packet socketpair descriptors valid while quit drains.
4. Join/wait for the blocking HEV main call to return.
5. Close the caller-owned HEV endpoint and bridge endpoint.
6. Assert tasks, descriptors, sessions, and memory return to the measured
   baseline before starting another generation.

`quit()` waits in 100 ms polls for its event descriptor if initialization is
still racing. Calling it when no main call will ever initialize can wait
indefinitely, so the wrapper needs an explicit launched/running generation state.

## 8. Upstream issue and patch inventory

Snapshot: GitHub issues/pulls and upstream commit graph inspected 2026-07-20.

| Item | Baseline status | Relevance / disposition |
| --- | --- | --- |
| [Issue #315](https://github.com/heiher/hev-socks5-tunnel/issues/315): teardown `pbuf_free` SIGABRT | Open, no reproducer/fix | Treat as lifecycle risk. Stress stop/timeout/active-flow races on Apple and preserve symbolicated failures. No local patch without reproduction. |
| [PR #286](https://github.com/heiher/hev-socks5-tunnel/pull/286): macOS stop infinite loop | Merged as `1571d8f…`; included | Signed/unsigned read/write comparisons fixed before this baseline. Retain regression tests for disconnect + stop. |
| [Issue #298](https://github.com/heiher/hev-socks5-tunnel/issues/298): macOS UDP behavior | Closed; UDP-in-TCP confirmed working after correcting server port; standard UDP fix included as `ad7843c…` | Supports ADR-004 target. Still run exact local adapter framing tests. |
| [PR #299](https://github.com/heiher/hev-socks5-tunnel/pull/299): move UDP VLA off task stack | Closed, unmerged | Explains effective stack risk. Do not cherry-pick by default; measure explicit config and overflow boundaries first. |
| [Issues #109](https://github.com/heiher/hev-socks5-tunnel/issues/109), [#174](https://github.com/heiher/hev-socks5-tunnel/issues/174), [#189](https://github.com/heiher/hev-socks5-tunnel/issues/189), [#203](https://github.com/heiher/hev-socks5-tunnel/issues/203) | Closed after low-memory guidance and max-session support | Primary historical evidence that iOS extension memory is a real gate, not proof that 1,200/4,096/24,576 fit Relux. |
| [Issue #297](https://github.com/heiher/hev-socks5-tunnel/issues/297): Unix-domain upstream SOCKS socket | Closed without tunnel support | `socks5.address` remains IP/name + TCP port. Do not assume an AF_UNIX upstream SOCKS listener; packet-plane AF_UNIX datagrams are a separate external-tun descriptor contract. |
| [Issue #301](https://github.com/heiher/hev-socks5-tunnel/issues/301): connection-owner hook | Open | No supported owner-admission callback. Process-private SOCKS admission remains an adapter concern. |

Changes from preliminary `1d334516…` to the selected baseline add optional ICMP
reply behavior, update lwIP/core, and remove a redundant TCP receive-queue check.
There were no later commits beyond `ad760049…` at audit time.

## 9. Callback ingress/egress fork feasibility

A minimal callback fork is technically feasible because packet I/O is localized:

- ingress: `lwip_io_task_entry` → `hev_tunnel_read` → `netif.input`;
- egress: lwIP netif callback → `netif_output_handler` → `hev_tunnel_write`.

The smallest plausible patch would inject C-level packet read/write operations
at that boundary while preserving HEV's scheduler thread, pbuf ownership, return
codes, shutdown wakeup, and IPv4/IPv6 classification. Calling arbitrary Swift
closures from lwIP/task contexts would expand lifetime and concurrency risk and
is not the default design.

Feasibility is not justification. A fork proposal must attach all of:

1. Instruments evidence that socketpair copies or syscalls are a material share
   of CPU/energy/latency or cause the memory gate to fail.
2. An apples-to-apples physical iPhone and macOS benchmark of unmodified fd path
   versus callback prototype, including IPv4/IPv6, TCP/UDP, MTU matrix,
   backpressure, repeated stop, and memory.
3. A material, reproducible improvement large enough to outweigh fork cost.
4. Exact patch series against `ad760049…`, dependency graph, changed-file and
   ABI inventory, upstream issue/PR link, and rebase cadence/owner.
5. Packet/framing conformance, fuzz/negative validation, allocator/pbuf lifetime,
   race, leak, and 100+ lifecycle-cycle evidence.
6. Updated source hashes, SBOM, MIT/lwIP notices, modification disclosure, and
   binary reproducibility evidence.

Until that evidence exists, the baseline is the unmodified XCFramework plus the
public `AF_UNIX/SOCK_DGRAM` packet bridge.

## 10. Notice audit

Pinned license files confirm:

- tunnel, core, task system, and yaml: MIT, identical `Copyright (c) 2022 hev`
  notice and permission text;
- lwIP: copyright 2001–2002 Swedish Institute of Computer Science, with source
  retention, binary-material reproduction, and no-endorsement clauses;
- no standalone NOTICE file exists in those component roots.

The sample binary-distribution notice file is:
`.research/260720_task-260715-uopycx-third-party-notices.txt`.

It aggregates the identical HEV MIT texts while naming each component/revision,
then reproduces the pinned lwIP license separately. Release packaging must map
this notice to the actual SBOM and ensure it remains readable offline. Wintun is
explicitly excluded from the Apple sample because its DLL is not shipped; any
future Windows artifact needs a separate license review.

## 11. Fact-check record and gaps

### Verification performed

- Recursive clone and checkout of the exact root commit.
- `git submodule status --recursive` matched the four gitlinks.
- Commit, tree, tag-describe, and deterministic `git archive` SHA-256 captured
  for every git component.
- Source code inspected for every contract claim; pinned GitHub links above
  point to the exact revisions.
- Full upstream Apple build executed twice during candidate/current comparison;
  selected `ad760049…` build passed.
- `Info.plist`, `file`, and `lipo -info` verified produced platform/architecture
  slices.
- License files compared and complete sample distribution text generated.
- GitHub issue and pull-request APIs plus local upstream history checked for
  lifecycle, Apple, memory, UDP, and post-candidate patches.

### Explicit gaps (do not infer success)

- This audit compiles but does not embed the XCFramework into the Relux provider
  or harness target; that is owned by HEV integration work.
- No physical iPhone packet, memory, MTU, throughput, or lifecycle evidence was
  produced; M0 measurement tasks own those gates.
- Issue #315 remains unresolved and platform-specific reproduction is absent.
- Upstream does not expose parsed effective configuration values through the
  public API. Integration tests must infer/observe behavior or add wrapper-side
  validation without modifying upstream.
- The public API does not promise thread safety, reentrancy, multiple instances,
  custom allocator installation, or a callback packet interface.
- No production numeric tuning decision is made here.

## Recommendation

Adopt the exact graph in the manifest as the M0 unmodified upstream baseline.
The bridge contract must own Darwin header validation and external descriptor
lifetime. The integration must supply a complete validated YAML every start,
pin UDP-in-TCP, serialize one HEV generation, join on stop, and test the actual
effective memory behavior—including the UDP stack-minimum anomaly—before any
numeric selection or fork proposal.

## Companion artifacts

- `.research/260720_task-260715-uopycx-dependency-manifest.json`
- `.research/260720_task-260715-uopycx-third-party-notices.txt`
- Task-scoped selected-baseline Apple build log attached on the board

## Primary references

- [Pinned tunnel tree](https://github.com/heiher/hev-socks5-tunnel/tree/ad7600497931205105b08367bd1b450048157e40)
- [Pinned core tree](https://github.com/heiher/hev-socks5-core/tree/c234519072ff5b928b90b304da9a666bcb440455)
- [Pinned task-system tree](https://github.com/heiher/hev-task-system/tree/b1afa0e21fb4ed5a69560e78e54baf0efdebe171)
- [Pinned lwIP fork](https://github.com/heiher/lwip/tree/2a11c14c7a32887af25a034e82ef18b0b12076ac)
- [Pinned yaml fork](https://github.com/heiher/yaml/tree/efa36117a8646d26d12b58e05bac472d7854a70d)
- [Tunnel issue tracker](https://github.com/heiher/hev-socks5-tunnel/issues)
- `.spec/packet-plane.md`, ADR-002, ADR-003, and ADR-004
