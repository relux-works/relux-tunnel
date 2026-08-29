# Packet plane specification

## Boundary

The packet plane converts `NEPacketTunnelFlow` packet batches into the file
descriptor contract expected by HEV/lwIP and exposes HEV's SOCKS requests to the
SSH adapter. It MUST use public Apple APIs and documented Darwin socket APIs.

The design MUST NOT discover or reopen the system utun descriptor, scan file
descriptors, or use `com.apple.net.utun_control` from the App Store extension.

## Packet bridge

Create a nonblocking `AF_UNIX/SOCK_DGRAM` socket pair:

- endpoint A is owned by the Swift `PacketFlowBridge`;
- endpoint B is passed to the HEV integration layer as its packet descriptor;
- packet boundaries are preserved by datagram semantics;
- both `SO_SNDBUF` and `SO_RCVBUF` are raised and the effective values are read
  back because Darwin may clamp requested sizes.

For packets read from `NEPacketTunnelFlow`, the bridge prepends the four-byte
Darwin address-family header expected by the HEV Apple descriptor path:

- network-byte-order `AF_INET` for IPv4;
- network-byte-order `AF_INET6` for IPv6.

The reverse path validates and strips the header, derives the protocol family,
and batches packets into `writePackets(_:withProtocols:)`. Invalid families and
undersized frames are dropped and counted.

### Backpressure contract

- `EAGAIN`, `EWOULDBLOCK`, and `ENOBUFS` mean a packet was dropped at a bounded
  queue. The bridge increments a reason-specific counter and does not retry or
  create an unbounded side buffer.
- `EMSGSIZE` is a configuration or MTU error. It fails the current packet-plane
  start and records the attempted datagram size and effective socket limit.
- Other persistent socket errors fail the provider with a privacy-safe error.
- Read loops have explicit batch and time budgets so they cannot starve SSH or
  lifecycle work on the extension process.

## HEV/lwIP integration

Use upstream `hev-socks5-tunnel` and its bundled lwIP as the initial TCP/IP
stack. HEV, `hev-socks5-core`, and `hev-task-system` are MIT; bundled lwIP uses
its BSD-style license. Binary distribution MUST include all required notices.

The initial low-memory configuration is a measurement baseline, not a permanent
constant:

```yaml
tunnel:
  mtu: 1500
socks5:
  udp: tcp
misc:
  task-stack-size: 24576
  tcp-buffer-size: 4096
  udp-copy-buffer-nums: 2
  max-session-count: 500
```

The M0 bridge requests 32768-byte send and receive buffers on both socket-pair
endpoints and reads back every effective value. Each pump yields after 64 work
items or 5 ms, whichever comes first. MTU 4096 and requested buffers through
262144 bytes remain injectable measured candidates; 4096-byte socket buffers
are fault-injection only. The complete evidence and revalidation boundary are
recorded in the task-scoped
[`TASK-260715-2jatnd` decision](../docs/TASK-260715-2jatnd_m0-bridge-hev-decision-adr.md).

`socks5.udp: tcp` is fixed before adapter work starts. The internal SOCKS
endpoint is process-local and MUST reject connections that do not originate
from the owned bridge/adapter path.

## Fork policy

Start with unmodified upstream HEV and the socket-pair bridge. A fork is allowed
only if Instruments identifies the bridge copies or syscall rate as a material
bottleneck and a callback ingress provides a measured improvement. Any fork MUST
remain minimal, track an upstream commit, retain notices, and have a documented
rebase strategy.

## MTU and batching

The M0 physical macOS matrix benchmarked MTUs 1500, 4096, and 8500. MTU 1500 is
selected. MTU 4096 remains injectable only after end-to-end path proof. MTU
8500 is rejected as the default because constrained-buffer rows produced
`EMSGSIZE` sender refusals and loopback did not establish external path or
fragmentation safety. Physical-iPhone evidence remains deferred by ADR-024.

Batch sizes are adaptive within fixed memory ceilings. The bridge MUST expose
packets, bytes, batches, queue-full drops, malformed frames, and maximum observed
datagram size.

## Memory budget

The provisional steady-state target for the full extension is 25–30 MiB on the
baseline physical iPhone. This is an engineering target, not an Apple contract.
The provider samples `os_proc_available_memory()` as advisory data and does not
cache it.

Pressure behavior is ordered:

1. Soft watermark: stop opening optional lanes, close idle channels, cap new
   channel windows, and shrink caches.
2. Pressure watermark: withhold SSH window adjustments, reduce HEV session/cache
   limits, and refuse new nonessential flows with fast errors.
3. Critical watermark: release the old transport before a controlled reconnect;
   if recovery is impossible, stop with an explicit error rather than relying on
   jetsam.

SSH advertised window credit is not assumed to be eagerly allocated memory, but
buffering permitted by windows is included in the worst-case budget. Channel
counts, HEV sessions, socket buffers, DNS cache, relay buffers, and reconnect
overlap MUST appear in memory tests.
